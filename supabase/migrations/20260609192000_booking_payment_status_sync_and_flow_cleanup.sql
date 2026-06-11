begin;

create or replace function public.sync_booking_payment_status(p_booking_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking record;
  v_paid numeric(10,3) := 0;
  v_latest_status text := null;
  v_next_status text := 'unpaid';
begin
  if p_booking_id is null then
    return;
  end if;

  select id, deposit_required_amount
  into v_booking
  from public.bookings
  where id = p_booking_id
  limit 1;

  if v_booking.id is null then
    return;
  end if;

  select
    coalesce(sum(amount) filter (where status = 'succeeded'), 0)::numeric(10,3),
    (
      array_agg(status order by created_at desc, updated_at desc, id desc)
    )[1]
  into v_paid, v_latest_status
  from public.payments
  where booking_id = p_booking_id
    and purpose = 'deposit';

  if coalesce(v_booking.deposit_required_amount, 0) <= 0 then
    v_next_status := 'unpaid';
  elsif v_paid >= coalesce(v_booking.deposit_required_amount, 0) then
    v_next_status := 'paid';
  elsif coalesce(v_latest_status, '') = 'failed' then
    v_next_status := 'failed';
  elsif v_latest_status is not null then
    v_next_status := 'pending';
  else
    v_next_status := 'pending';
  end if;

  update public.bookings
  set payment_status = v_next_status,
      updated_at = now()
  where id = p_booking_id
    and payment_status is distinct from v_next_status;
end;
$$;

create or replace function public.payments_sync_booking_payment_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.sync_booking_payment_status(coalesce(new.booking_id, old.booking_id));
  return coalesce(new, old);
end;
$$;

drop trigger if exists payments_sync_booking_payment_status on public.payments;
create trigger payments_sync_booking_payment_status
after insert or update of status, amount, purpose, booking_id or delete on public.payments
for each row execute function public.payments_sync_booking_payment_status();

do $$
declare
  r record;
begin
  for r in
    select id from public.bookings
  loop
    perform public.sync_booking_payment_status(r.id);
  end loop;
end
$$;

create or replace function public.confirm_booking(booking_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_booking public.bookings%rowtype;
  v_paid numeric(10,3);
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  select * into v_booking
  from public.bookings b
  where b.id = booking_id
  limit 1;

  if v_booking.id is null then
    raise exception using message = 'BOOKING_NOT_FOUND';
  end if;

  if not (
    exists (select 1 from public.barbers br where br.id = v_booking.barber_id and br.profile_id = v_user)
    or exists (select 1 from public.barbershops s where s.id = v_booking.shop_id and s.owner_profile_id = v_user)
    or public.is_admin()
  ) then
    raise exception using message = 'FORBIDDEN';
  end if;

  if v_booking.status not in ('pending', 'rescheduled') then
    raise exception using message = 'BOOKING_NOT_CONFIRMABLE';
  end if;

  if v_booking.deposit_required_amount is not null and v_booking.deposit_required_amount > 0 then
    select coalesce(sum(p.amount) filter (where p.status = 'succeeded'), 0)::numeric(10,3)
    into v_paid
    from public.payments p
    where p.booking_id = v_booking.id
      and p.purpose = 'deposit';

    if v_paid < v_booking.deposit_required_amount then
      raise exception using message = 'DEPOSIT_REQUIRED';
    end if;
  end if;

  update public.bookings
  set status = 'confirmed',
      updated_at = now()
  where id = v_booking.id
  returning * into v_booking;

  perform public.sync_booking_payment_status(v_booking.id);

  select * into v_booking
  from public.bookings
  where id = booking_id
  limit 1;

  return v_booking;
end;
$$;

create or replace function public.mark_payment_succeeded(payment_id uuid)
returns public.payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_payment public.payments%rowtype;
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  select * into v_payment
  from public.payments p
  where p.id = payment_id
  limit 1;

  if v_payment.id is null then
    raise exception using message = 'PAYMENT_NOT_FOUND';
  end if;

  if not (
    public.is_admin()
    or (v_payment.payee_type = 'barber' and public.is_barber_owner(v_payment.payee_id))
    or (v_payment.payee_type = 'shop' and public.is_shop_owner(v_payment.payee_id))
  ) then
    raise exception using message = 'FORBIDDEN';
  end if;

  if v_payment.status = 'succeeded' then
    perform public.sync_booking_payment_status(v_payment.booking_id);
    return v_payment;
  end if;

  update public.payments
  set status = 'succeeded',
      authorized_at = coalesce(authorized_at, now()),
      captured_at = coalesce(captured_at, now()),
      updated_at = now()
  where id = v_payment.id
  returning * into v_payment;

  perform public.sync_booking_payment_status(v_payment.booking_id);

  return v_payment;
end;
$$;

do $$
begin
  if to_regprocedure('public.confirm_booking(uuid)') is not null then
    revoke all on function public.confirm_booking(uuid) from public;
  end if;
  if to_regprocedure('public.confirm_booking(uuid)') is not null
     and exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.confirm_booking(uuid) to authenticated;
  end if;

  if to_regprocedure('public.mark_payment_succeeded(uuid)') is not null then
    revoke all on function public.mark_payment_succeeded(uuid) from public;
  end if;
  if to_regprocedure('public.mark_payment_succeeded(uuid)') is not null
     and exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.mark_payment_succeeded(uuid) to authenticated;
  end if;
end;
$$;

commit;

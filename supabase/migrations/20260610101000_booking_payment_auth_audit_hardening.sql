begin;

create or replace function public.booking_actor_has_staff_access(
  p_actor_id uuid,
  p_shop_id uuid,
  p_branch_id uuid,
  p_barber_id uuid default null
)
returns boolean
language sql
security definer
set search_path = public
set row_security = off
as $$
  select coalesce(
    p_actor_id is not null
    and (
      public.is_admin()
      or (p_barber_id is not null and exists (
        select 1
        from public.barbers br
        where br.id = p_barber_id
          and br.profile_id = p_actor_id
      ))
      or exists (
        select 1
        from public.barbershops s
        where s.id = p_shop_id
          and s.owner_profile_id = p_actor_id
      )
      or exists (
        select 1
        from public.shop_memberships sm
        where sm.profile_id = p_actor_id
          and sm.shop_id = p_shop_id
          and sm.membership_role in ('owner', 'barber', 'receptionist')
          and (
            sm.membership_role = 'owner'
            or p_branch_id is null
            or sm.branch_id = p_branch_id
          )
      )
    ),
    false
  );
$$;

create or replace function public.sync_booking_payment_status(p_booking_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking record;
  v_paid numeric(10,3) := 0;
  v_refunded numeric(10,3) := 0;
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
    coalesce(sum(p.amount) filter (where p.status = 'succeeded'), 0)::numeric(10,3),
    (
      array_agg(p.status order by p.created_at desc, p.updated_at desc, p.id desc)
    )[1]
  into v_paid, v_latest_status
  from public.payments p
  where p.booking_id = p_booking_id
    and p.purpose = 'deposit';

  select
    coalesce(sum(r.amount) filter (where r.status = 'succeeded'), 0)::numeric(10,3)
  into v_refunded
  from public.refunds r
  join public.payments p on p.id = r.payment_id
  where p.booking_id = p_booking_id
    and p.purpose = 'deposit';

  if coalesce(v_booking.deposit_required_amount, 0) <= 0 then
    v_next_status := 'unpaid';
  elsif (coalesce(v_latest_status, '') = 'refunded' and v_paid > 0)
     or (v_paid > 0 and v_refunded >= least(v_paid, coalesce(v_booking.deposit_required_amount, 0))) then
    v_next_status := 'refunded';
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

create or replace function public.refunds_sync_booking_payment_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.sync_booking_payment_status((
    select p.booking_id
    from public.payments p
    where p.id = coalesce(new.payment_id, old.payment_id)
    limit 1
  ));
  return coalesce(new, old);
end;
$$;

drop trigger if exists refunds_sync_booking_payment_status on public.refunds;
create trigger refunds_sync_booking_payment_status
after insert or update of status, amount, payment_id or delete on public.refunds
for each row execute function public.refunds_sync_booking_payment_status();

create or replace function public.cancel_booking(booking_id uuid, reason text default null)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_booking public.bookings%rowtype;
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
    v_booking.customer_profile_id = v_user
    or public.booking_actor_has_staff_access(v_user, v_booking.shop_id, v_booking.branch_id, v_booking.barber_id)
  ) then
    raise exception using message = 'FORBIDDEN';
  end if;

  if v_booking.status in ('cancelled', 'completed', 'no_show') then
    return v_booking;
  end if;

  if v_booking.start_at <= now() then
    raise exception using message = 'TOO_LATE_TO_CANCEL';
  end if;

  update public.bookings
  set status = 'cancelled',
      cancelled_at = now(),
      cancelled_by_profile_id = v_user,
      cancel_reason = nullif(trim(reason), ''),
      updated_at = now()
  where id = booking_id
  returning * into v_booking;

  return v_booking;
end;
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

  if not public.booking_actor_has_staff_access(v_user, v_booking.shop_id, v_booking.branch_id, v_booking.barber_id) then
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

create or replace function public.reschedule_booking(booking_id uuid, new_start_at timestamptz)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_booking public.bookings%rowtype;
  v_offer record;
  v_end_at timestamptz;
  v_buffer int := 0;
  v_offer_id uuid;
  v_discount_amount numeric(10,3);
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
    v_booking.customer_profile_id = v_user
    or public.booking_actor_has_staff_access(v_user, v_booking.shop_id, v_booking.branch_id, v_booking.barber_id)
  ) then
    raise exception using message = 'FORBIDDEN';
  end if;

  if v_booking.status in ('cancelled', 'completed', 'in_progress', 'no_show') then
    raise exception using message = 'BOOKING_NOT_RESCHEDULABLE';
  end if;

  if v_booking.start_at <= now() or new_start_at <= now() then
    raise exception using message = 'TOO_LATE_TO_RESCHEDULE';
  end if;

  if v_booking.duration_minutes is null or v_booking.duration_minutes <= 0 then
    raise exception using message = 'INVALID_DURATION';
  end if;

  select coalesce(b.buffer_minutes, 0)
  into v_buffer
  from public.barbers br
  left join public.barbershops b on b.id = br.shop_id
  where br.id = v_booking.barber_id;

  v_end_at := new_start_at + make_interval(mins => v_booking.duration_minutes);

  if exists (
    select 1
    from public.barber_time_off t
    where t.barber_id = v_booking.barber_id
      and tstzrange(t.starts_at, t.ends_at, '[)') && tstzrange(new_start_at, v_end_at, '[)')
  ) then
    raise exception using message = 'BARBER_TIME_OFF';
  end if;

  if exists (
    select 1
    from public.bookings b
    where b.barber_id = v_booking.barber_id
      and b.id <> v_booking.id
      and b.status in ('pending', 'confirmed', 'rescheduled', 'in_progress')
      and tstzrange(b.start_at, b.end_at + make_interval(mins => v_buffer), '[)') && tstzrange(new_start_at, v_end_at, '[)')
  ) then
    raise exception using message = 'BOOKING_OVERLAP';
  end if;

  v_offer_id := v_booking.offer_id;
  v_discount_amount := coalesce(v_booking.discount_amount, 0)::numeric(10,3);

  if v_offer_id is not null then
    select id, shop_id, barber_id, active, is_active, status, valid_from, valid_to
    into v_offer
    from public.offers o
    where o.id = v_offer_id
    limit 1;

    if v_offer.id is null
      or coalesce(v_offer.active, true) is not true
      or coalesce(v_offer.is_active, true) is not true
      or v_offer.status <> 'approved'
      or (v_offer.valid_from is not null and v_offer.valid_from > new_start_at)
      or (v_offer.valid_to is not null and v_offer.valid_to < new_start_at)
      or (v_offer.barber_id is not null and v_offer.barber_id <> v_booking.barber_id)
      or (v_offer.shop_id is not null and v_offer.shop_id <> v_booking.shop_id) then
      v_offer_id := null;
      v_discount_amount := 0;
    end if;
  end if;

  update public.bookings
  set start_at = new_start_at,
      end_at = v_end_at,
      offer_id = v_offer_id,
      discount_amount = v_discount_amount,
      total_price = greatest(coalesce(v_booking.price_bhd, v_booking.total_price, 0)::numeric(10,3) - v_discount_amount, 0)::numeric(10,3),
      rescheduled_at = now(),
      rescheduled_by_profile_id = v_user,
      updated_at = now()
  where id = booking_id
  returning * into v_booking;

  return v_booking;
end;
$$;

create or replace function public.start_booking(booking_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_booking public.bookings%rowtype;
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

  if not public.booking_actor_has_staff_access(v_user, v_booking.shop_id, v_booking.branch_id, v_booking.barber_id) then
    raise exception using message = 'FORBIDDEN';
  end if;

  if v_booking.status not in ('confirmed', 'rescheduled') then
    raise exception using message = 'BOOKING_NOT_STARTABLE';
  end if;

  update public.bookings
  set status = 'in_progress',
      updated_at = now()
  where id = v_booking.id
  returning * into v_booking;

  return v_booking;
end;
$$;

create or replace function public.complete_booking(booking_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_booking public.bookings%rowtype;
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

  if not public.booking_actor_has_staff_access(v_user, v_booking.shop_id, v_booking.branch_id, v_booking.barber_id) then
    raise exception using message = 'FORBIDDEN';
  end if;

  if v_booking.status not in ('confirmed', 'rescheduled', 'in_progress') then
    raise exception using message = 'BOOKING_NOT_COMPLETABLE';
  end if;

  update public.bookings
  set status = 'completed',
      updated_at = now()
  where id = v_booking.id
  returning * into v_booking;

  return v_booking;
end;
$$;

create or replace function public.mark_booking_no_show(booking_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_booking public.bookings%rowtype;
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

  if not public.booking_actor_has_staff_access(v_user, v_booking.shop_id, v_booking.branch_id, v_booking.barber_id) then
    raise exception using message = 'FORBIDDEN';
  end if;

  if v_booking.status not in ('confirmed', 'rescheduled', 'in_progress') then
    raise exception using message = 'BOOKING_NOT_NO_SHOW';
  end if;

  update public.bookings
  set status = 'no_show',
      updated_at = now()
  where id = v_booking.id
  returning * into v_booking;

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
  v_booking public.bookings%rowtype;
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

  if v_payment.booking_id is not null then
    select * into v_booking
    from public.bookings b
    where b.id = v_payment.booking_id
    limit 1;
  end if;

  if not (
    public.is_admin()
    or (v_payment.booking_id is not null and public.booking_actor_has_staff_access(v_user, v_booking.shop_id, v_booking.branch_id, v_booking.barber_id))
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

create or replace function public.admin_booking_integrity_scan(p_limit int default 50)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  out jsonb;
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;

  out := jsonb_build_object(
    'generated_at', now(),
    'bookings_missing_branch', (
      select jsonb_agg(jsonb_build_object('booking_id', x.id, 'shop_id', x.shop_id, 'barber_id', x.barber_id, 'status', x.status))
      from (
        select b.id, b.shop_id, b.barber_id, b.status
        from public.bookings b
        where b.shop_id is not null
          and b.branch_id is null
        order by b.created_at desc
        limit p_limit
      ) x
    ),
    'booking_status_timestamp_mismatches', (
      select jsonb_agg(
        jsonb_build_object(
          'booking_id', x.id,
          'status', x.status,
          'started_at', x.started_at,
          'completed_at', x.completed_at,
          'cancelled_at', x.cancelled_at,
          'no_show_at', x.no_show_at,
          'rescheduled_at', x.rescheduled_at
        )
      )
      from (
        select b.id, b.status, b.started_at, b.completed_at, b.cancelled_at, b.no_show_at, b.rescheduled_at
        from public.bookings b
        where (b.status = 'cancelled' and b.cancelled_at is null)
           or (b.status = 'in_progress' and b.started_at is null)
           or (b.status = 'completed' and b.completed_at is null)
           or (b.status = 'no_show' and b.no_show_at is null)
           or (b.status = 'rescheduled' and b.rescheduled_at is null)
        order by b.updated_at desc nulls last, b.created_at desc
        limit p_limit
      ) x
    ),
    'booking_payment_state_mismatches', (
      select jsonb_agg(
        jsonb_build_object(
          'booking_id', x.id,
          'deposit_required_amount', x.deposit_required_amount,
          'payment_status', x.payment_status,
          'expected_payment_status', x.expected_payment_status,
          'paid_amount', x.paid_amount,
          'refunded_amount', x.refunded_amount,
          'latest_payment_status', x.latest_payment_status
        )
      )
      from (
        select
          b.id,
          b.deposit_required_amount,
          b.payment_status,
          p.paid_amount,
          p.refunded_amount,
          p.latest_payment_status,
          case
            when coalesce(b.deposit_required_amount, 0) <= 0 then 'unpaid'
            when (coalesce(p.latest_payment_status, '') = 'refunded' and p.paid_amount > 0)
              or (p.paid_amount > 0 and p.refunded_amount >= least(p.paid_amount, coalesce(b.deposit_required_amount, 0))) then 'refunded'
            when p.paid_amount >= coalesce(b.deposit_required_amount, 0) then 'paid'
            when coalesce(p.latest_payment_status, '') = 'failed' then 'failed'
            when p.latest_payment_status is not null then 'pending'
            else 'pending'
          end as expected_payment_status
        from public.bookings b
        cross join lateral (
          select
            coalesce(sum(pay.amount) filter (where pay.status = 'succeeded'), 0)::numeric(10,3) as paid_amount,
            coalesce(sum(ref.amount) filter (where ref.status = 'succeeded'), 0)::numeric(10,3) as refunded_amount,
            (
              array_agg(pay.status order by pay.created_at desc, pay.updated_at desc, pay.id desc)
            )[1] as latest_payment_status
          from public.payments pay
          left join public.refunds ref on ref.payment_id = pay.id
          where pay.booking_id = b.id
            and pay.purpose = 'deposit'
        ) p
        where b.payment_status is distinct from
          case
            when coalesce(b.deposit_required_amount, 0) <= 0 then 'unpaid'
            when (coalesce(p.latest_payment_status, '') = 'refunded' and p.paid_amount > 0)
              or (p.paid_amount > 0 and p.refunded_amount >= least(p.paid_amount, coalesce(b.deposit_required_amount, 0))) then 'refunded'
            when p.paid_amount >= coalesce(b.deposit_required_amount, 0) then 'paid'
            when coalesce(p.latest_payment_status, '') = 'failed' then 'failed'
            when p.latest_payment_status is not null then 'pending'
            else 'pending'
          end
        order by b.updated_at desc nulls last, b.created_at desc
        limit p_limit
      ) x
    )
  );

  return coalesce(out, '{}'::jsonb);
end;
$$;

do $$
begin
  if to_regprocedure('public.cancel_booking(uuid, text)') is not null then
    revoke all on function public.cancel_booking(uuid, text) from public;
    grant execute on function public.cancel_booking(uuid, text) to authenticated;
  end if;

  if to_regprocedure('public.confirm_booking(uuid)') is not null then
    revoke all on function public.confirm_booking(uuid) from public;
    grant execute on function public.confirm_booking(uuid) to authenticated;
  end if;

  if to_regprocedure('public.mark_payment_succeeded(uuid)') is not null then
    revoke all on function public.mark_payment_succeeded(uuid) from public;
    grant execute on function public.mark_payment_succeeded(uuid) to authenticated;
  end if;
end;
$$;

commit;

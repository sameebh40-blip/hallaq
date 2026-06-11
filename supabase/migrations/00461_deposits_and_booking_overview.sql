begin;

alter table public.services add column if not exists deposit_type text;
alter table public.services add column if not exists deposit_value numeric(10,3);
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'services_deposit_type_chk'
      and conrelid = 'public.services'::regclass
  ) then
    alter table public.services
      add constraint services_deposit_type_chk
      check (deposit_type is null or deposit_type in ('fixed','percent')) not valid;
  end if;
end
$$;

alter table public.bookings add column if not exists deposit_required_amount numeric(10,3) not null default 0;

alter table public.payments add column if not exists purpose text not null default 'service';
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'payments_purpose_chk'
      and conrelid = 'public.payments'::regclass
  ) then
    alter table public.payments
      add constraint payments_purpose_chk
      check (purpose in ('deposit','service')) not valid;
  end if;
end
$$;

create index if not exists payments_booking_purpose_idx on public.payments (booking_id, purpose, status);

create or replace function public.create_booking(
  service_id uuid,
  start_at timestamptz,
  barber_id uuid,
  shop_id uuid default null,
  notes text default null
)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_barber_shop_id uuid;
  v_service record;
  v_shop_id uuid;
  v_duration int;
  v_price numeric(10,3);
  v_end_at timestamptz;
  v_buffer int := 0;
  v_booking public.bookings%rowtype;
  v_deposit_type text;
  v_deposit_value numeric(10,3);
  v_deposit_required numeric(10,3) := 0;
  v_payee_type text;
  v_payee_id uuid;
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  if barber_id is null then
    raise exception using message = 'INVALID_BARBER';
  end if;

  select b.shop_id
  into v_barber_shop_id
  from public.barbers b
  where b.id = $3;

  if v_barber_shop_id is null and shop_id is not null then
    raise exception using message = 'INVALID_SHOP';
  end if;

  v_shop_id := coalesce(shop_id, v_barber_shop_id);

  select
    s.id,
    s.shop_id,
    s.barber_id,
    s.is_active,
    s.deleted_at,
    s.price_bhd,
    s.duration_minutes,
    s.price,
    s.duration_min,
    s.deposit_type,
    s.deposit_value
  into v_service
  from public.services s
  where s.id = $1
  limit 1;

  if v_service.id is null then
    raise exception using message = 'SERVICE_NOT_FOUND';
  end if;

  if v_service.deleted_at is not null or v_service.is_active is not true then
    raise exception using message = 'SERVICE_INACTIVE';
  end if;

  if v_service.barber_id is not null and v_service.barber_id <> $3 then
    raise exception using message = 'SERVICE_NOT_FOR_BARBER';
  end if;

  if v_service.shop_id is not null then
    v_shop_id := coalesce(v_shop_id, v_service.shop_id);
    if v_shop_id <> v_service.shop_id then
      raise exception using message = 'SERVICE_NOT_FOR_SHOP';
    end if;
    if v_barber_shop_id is distinct from v_service.shop_id then
      raise exception using message = 'BARBER_NOT_IN_SHOP';
    end if;
  end if;

  v_duration := coalesce(v_service.duration_minutes, v_service.duration_min, 30);
  if v_duration <= 0 then
    raise exception using message = 'INVALID_DURATION';
  end if;

  v_price := coalesce(v_service.price_bhd, v_service.price, 0)::numeric(10,3);
  v_end_at := $2 + make_interval(mins => v_duration);

  select coalesce(br.buffer_minutes, s.buffer_minutes, 0)
  into v_buffer
  from public.barbers br
  left join public.barbershops s on s.id = br.shop_id
  where br.id = $3;

  if exists (
    select 1
    from public.barber_time_off t
    where t.barber_id = $3
      and tstzrange(t.starts_at, t.ends_at, '[)') && tstzrange($2, v_end_at, '[)')
  ) then
    raise exception using message = 'BARBER_TIME_OFF';
  end if;

  if exists (
    select 1
    from public.bookings b
    where b.barber_id = $3
      and b.status in ('pending','confirmed')
      and tstzrange(b.start_at, b.end_at + make_interval(mins => v_buffer), '[)') && tstzrange($2, v_end_at, '[)')
  ) then
    raise exception using message = 'BOOKING_OVERLAP';
  end if;

  v_deposit_type := nullif(trim(coalesce(v_service.deposit_type, '')), '');
  v_deposit_value := coalesce(v_service.deposit_value, 0)::numeric(10,3);
  if v_deposit_type is not null and v_deposit_value > 0 then
    if v_deposit_type = 'fixed' then
      v_deposit_required := v_deposit_value;
    elsif v_deposit_type = 'percent' then
      v_deposit_required := round((v_price * v_deposit_value / 100.0)::numeric, 3);
    end if;
  end if;
  if v_deposit_required < 0 then v_deposit_required := 0; end if;
  if v_deposit_required > v_price then v_deposit_required := v_price; end if;

  insert into public.bookings (
    customer_profile_id,
    shop_id,
    barber_id,
    service_id,
    start_at,
    end_at,
    status,
    notes,
    total_price,
    currency,
    price_bhd,
    duration_minutes,
    deposit_required_amount
  )
  values (
    v_user,
    v_shop_id,
    $3,
    $1,
    $2,
    v_end_at,
    'pending',
    $5,
    v_price,
    'BHD',
    v_price,
    v_duration,
    v_deposit_required
  )
  returning * into v_booking;

  v_payee_type := case when v_shop_id is not null then 'shop' else 'barber' end;
  v_payee_id := coalesce(v_shop_id, $3);

  if v_deposit_required > 0 then
    insert into public.payments (
      booking_id,
      payer_profile_id,
      payee_type,
      payee_id,
      amount,
      currency,
      provider,
      status,
      purpose
    )
    values (
      v_booking.id,
      v_user,
      v_payee_type,
      v_payee_id,
      v_deposit_required,
      'BHD',
      'manual',
      'pending',
      'deposit'
    );
  end if;

  return v_booking;
end;
$$;

do $$
begin
  if to_regprocedure('public.create_booking(uuid, timestamptz, uuid, uuid, text)') is not null then
    revoke all on function public.create_booking(uuid, timestamptz, uuid, uuid, text) from public;
  end if;

  if to_regprocedure('public.create_booking(uuid, timestamptz, uuid, uuid, text)') is not null
     and exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.create_booking(uuid, timestamptz, uuid, uuid, text) to authenticated;
  end if;
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

  if not (
    exists (select 1 from public.barbers br where br.id = v_booking.barber_id and br.profile_id = v_user)
    or exists (select 1 from public.barbershops s where s.id = v_booking.shop_id and s.owner_profile_id = v_user)
    or public.is_admin()
  ) then
    raise exception using message = 'FORBIDDEN';
  end if;

  if v_booking.status in ('cancelled','completed') then
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

  return v_booking;
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
    return v_payment;
  end if;

  update public.payments
  set status = 'succeeded',
      authorized_at = coalesce(authorized_at, now()),
      captured_at = coalesce(captured_at, now()),
      updated_at = now()
  where id = v_payment.id
  returning * into v_payment;

  return v_payment;
end;
$$;

do $$
begin
  if to_regprocedure('public.mark_payment_succeeded(uuid)') is not null then
    revoke all on function public.mark_payment_succeeded(uuid) from public;
  end if;

  if to_regprocedure('public.mark_payment_succeeded(uuid)') is not null
     and exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.mark_payment_succeeded(uuid) to authenticated;
  end if;
end;
$$;

create or replace view public.booking_overview as
select
  b.*,
  s.name_en as service_name_en,
  s.name_ar as service_name_ar,
  br.display_name as barber_name,
  sh.name as shop_name,
  p.full_name as customer_name,
  p.email as customer_email
from public.bookings b
left join public.services s on s.id = b.service_id
left join public.barbers br on br.id = b.barber_id
left join public.barbershops sh on sh.id = b.shop_id
left join public.profiles p on p.id = b.customer_profile_id;

commit;

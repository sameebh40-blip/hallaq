begin;

alter table public.bookings add column if not exists source_post_id uuid references public.posts (id) on delete set null;

create index if not exists bookings_source_post_id_idx on public.bookings (source_post_id);

create or replace function public.create_booking(
  service_id uuid,
  start_at timestamptz,
  barber_id uuid,
  shop_id uuid default null,
  notes text default null,
  payment_method text default 'cash',
  source_post_id uuid default null
)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  p_service_id uuid := service_id;
  p_start_at timestamptz := start_at;
  p_barber_id uuid := barber_id;
  p_shop_id uuid := shop_id;
  p_notes text := notes;
  p_payment_method text := payment_method;
  p_source_post_id uuid := source_post_id;

  v_user uuid;
  v_barber_shop_id uuid;
  v_service record;
  v_shop_id uuid;
  v_branch_id uuid;
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
  v_payment_method text;
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  if p_barber_id is null then
    raise exception using message = 'INVALID_BARBER';
  end if;

  select b.shop_id
  into v_barber_shop_id
  from public.barbers b
  where b.id = p_barber_id;

  if v_barber_shop_id is null and p_shop_id is not null then
    raise exception using message = 'INVALID_SHOP';
  end if;

  v_shop_id := coalesce(p_shop_id, v_barber_shop_id);
  if v_shop_id is not null then
    v_branch_id := public.ensure_shop_default_branch(v_shop_id);
  end if;

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
  where s.id = p_service_id
  limit 1;

  if v_service.id is null then
    raise exception using message = 'SERVICE_NOT_FOUND';
  end if;

  if v_service.deleted_at is not null or v_service.is_active is not true then
    raise exception using message = 'SERVICE_INACTIVE';
  end if;

  if v_service.barber_id is not null and v_service.barber_id <> p_barber_id then
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
    v_branch_id := public.ensure_shop_default_branch(v_shop_id);
  end if;

  v_duration := coalesce(v_service.duration_minutes, v_service.duration_min, 30);
  if v_duration <= 0 then
    raise exception using message = 'INVALID_DURATION';
  end if;

  v_price := coalesce(v_service.price_bhd, v_service.price, 0)::numeric(10,3);
  v_end_at := p_start_at + make_interval(mins => v_duration);

  select coalesce(br.buffer_minutes, s.buffer_minutes, 0)
  into v_buffer
  from public.barbers br
  left join public.barbershops s on s.id = br.shop_id
  where br.id = p_barber_id;

  if exists (
    select 1
    from public.barber_time_off t
    where t.barber_id = p_barber_id
      and tstzrange(t.starts_at, t.ends_at, '[)') && tstzrange(p_start_at, v_end_at, '[)')
  ) then
    raise exception using message = 'BARBER_TIME_OFF';
  end if;

  if exists (
    select 1
    from public.bookings b
    where b.barber_id = p_barber_id
      and b.status in ('pending','confirmed','in_progress','rescheduled')
      and tstzrange(b.start_at, b.end_at + make_interval(mins => v_buffer), '[)') && tstzrange(p_start_at, v_end_at, '[)')
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

  v_payment_method := lower(trim(coalesce(p_payment_method, '')));
  if v_payment_method not in ('cash','benefitpay','card') then
    v_payment_method := 'cash';
  end if;

  insert into public.bookings (
    customer_profile_id,
    shop_id,
    branch_id,
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
    deposit_required_amount,
    payment_method,
    source_post_id
  )
  values (
    v_user,
    v_shop_id,
    v_branch_id,
    p_barber_id,
    p_service_id,
    p_start_at,
    v_end_at,
    'pending',
    p_notes,
    v_price,
    'BHD',
    v_price,
    v_duration,
    v_deposit_required,
    v_payment_method,
    p_source_post_id
  )
  returning * into v_booking;

  v_payee_type := case when v_shop_id is not null then 'shop' else 'barber' end;
  v_payee_id := coalesce(v_shop_id, p_barber_id);

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
  if to_regprocedure('public.create_booking(uuid, timestamptz, uuid, uuid, text, text, uuid)') is not null then
    revoke all on function public.create_booking(uuid, timestamptz, uuid, uuid, text, text, uuid) from public;
  end if;

  if to_regprocedure('public.create_booking(uuid, timestamptz, uuid, uuid, text, text, uuid)') is not null
     and exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.create_booking(uuid, timestamptz, uuid, uuid, text, text, uuid) to authenticated;
  end if;
end;
$$;

create or replace function public.create_booking_with_hold(
  service_id uuid,
  start_at timestamptz,
  barber_id uuid,
  hold_id uuid,
  shop_id uuid default null,
  notes text default null,
  payment_method text default 'cash',
  source_post_id uuid default null
)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_hold public.booking_slot_holds%rowtype;
  v_booking public.bookings%rowtype;
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  select *
  into v_hold
  from public.booking_slot_holds h
  where h.id = $4
    and h.profile_id = v_user
    and h.consumed_at is null
    and h.expires_at > now()
  for update;

  if v_hold.id is null then
    raise exception using message = 'HOLD_NOT_FOUND';
  end if;

  if v_hold.service_id is distinct from $1 or v_hold.barber_id is distinct from $3 or v_hold.start_at is distinct from $2 then
    raise exception using message = 'HOLD_MISMATCH';
  end if;

  v_booking := public.create_booking($1, $2, $3, $5, $6, $7, $8);

  update public.booking_slot_holds
  set consumed_at = now()
  where id = v_hold.id;

  return v_booking;
end;
$$;

do $$
begin
  if to_regprocedure('public.create_booking_with_hold(uuid, timestamptz, uuid, uuid, uuid, text, text, uuid)') is not null then
    revoke all on function public.create_booking_with_hold(uuid, timestamptz, uuid, uuid, uuid, text, text, uuid) from public;
  end if;

  if to_regprocedure('public.create_booking_with_hold(uuid, timestamptz, uuid, uuid, uuid, text, text, uuid)') is not null
     and exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.create_booking_with_hold(uuid, timestamptz, uuid, uuid, uuid, text, text, uuid) to authenticated;
  end if;
end;
$$;

commit;


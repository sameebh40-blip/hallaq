begin;

create or replace function public.create_booking(
  service_id uuid,
  start_at timestamptz,
  barber_id uuid,
  shop_id uuid default null,
  notes text default null,
  payment_method text default 'cash'
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

  if barber_id is null then
    raise exception using message = 'INVALID_BARBER';
  end if;

  select b.shop_id
  into v_barber_shop_id
  from public.barbers b
  where b.id = barber_id;

  if v_barber_shop_id is null and shop_id is not null then
    raise exception using message = 'INVALID_SHOP';
  end if;

  v_shop_id := coalesce(shop_id, v_barber_shop_id);
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
  where s.id = service_id
  limit 1;

  if v_service.id is null then
    raise exception using message = 'SERVICE_NOT_FOUND';
  end if;

  if v_service.deleted_at is not null or v_service.is_active is not true then
    raise exception using message = 'SERVICE_INACTIVE';
  end if;

  if v_service.barber_id is not null and v_service.barber_id <> barber_id then
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
  v_end_at := start_at + make_interval(mins => v_duration);

  select coalesce(br.buffer_minutes, s.buffer_minutes, 0)
  into v_buffer
  from public.barbers br
  left join public.barbershops s on s.id = br.shop_id
  where br.id = barber_id;

  if exists (
    select 1
    from public.barber_time_off t
    where t.barber_id = barber_id
      and tstzrange(t.starts_at, t.ends_at, '[)') && tstzrange(start_at, v_end_at, '[)')
  ) then
    raise exception using message = 'BARBER_TIME_OFF';
  end if;

  if exists (
    select 1
    from public.bookings b
    where b.barber_id = barber_id
      and b.status in ('pending','confirmed')
      and tstzrange(b.start_at, b.end_at + make_interval(mins => v_buffer), '[)') && tstzrange(start_at, v_end_at, '[)')
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

  v_payment_method := lower(trim(coalesce(payment_method, '')));
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
    payment_method
  )
  values (
    v_user,
    v_shop_id,
    v_branch_id,
    barber_id,
    service_id,
    start_at,
    v_end_at,
    'pending',
    notes,
    v_price,
    'BHD',
    v_price,
    v_duration,
    v_deposit_required,
    v_payment_method
  )
  returning * into v_booking;

  v_payee_type := case when v_shop_id is not null then 'shop' else 'barber' end;
  v_payee_id := coalesce(v_shop_id, barber_id);

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

commit;


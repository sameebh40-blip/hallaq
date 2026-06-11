begin;

create or replace function public.hold_booking_slot(
  service_id uuid,
  start_at timestamptz,
  barber_id uuid,
  shop_id uuid default null,
  hold_minutes int default 5
)
returns table (hold_id uuid, expires_at timestamptz)
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_user uuid;
  v_service record;
  v_barber record;
  v_shop record;
  v_existing_hold public.booking_slot_holds%rowtype;
  v_duration int;
  v_end_at timestamptz;
  v_shop_id uuid;
  v_barber_shop_id uuid;
  v_expires timestamptz;
  v_buffer int := 0;
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  if hold_minutes is null or hold_minutes < 1 or hold_minutes > 30 then
    hold_minutes := 5;
  end if;

  select b.id, b.shop_id, b.deleted_at, b.is_active, b.status
  into v_barber
  from public.barbers b
  where b.id = $3
  limit 1;

  if v_barber.id is null then
    raise exception using message = 'INVALID_BARBER';
  end if;
  if v_barber.deleted_at is not null or v_barber.is_active is not true or v_barber.status <> 'approved' then
    raise exception using message = 'BARBER_INACTIVE';
  end if;

  v_barber_shop_id := v_barber.shop_id;
  v_shop_id := coalesce($4, v_barber_shop_id);

  if v_shop_id is not null then
    select s.id, s.deleted_at, s.is_active, s.status
    into v_shop
    from public.barbershops s
    where s.id = v_shop_id
    limit 1;

    if v_shop.id is null then
      raise exception using message = 'INVALID_SHOP';
    end if;
    if v_shop.deleted_at is not null or v_shop.is_active is not true or v_shop.status <> 'approved' then
      raise exception using message = 'SHOP_INACTIVE';
    end if;
  end if;

  select
    s.id,
    s.shop_id,
    s.barber_id,
    s.is_active,
    s.status,
    s.deleted_at,
    s.duration_minutes,
    s.duration_min
  into v_service
  from public.services s
  where s.id = $1
  limit 1;

  if v_service.id is null then
    raise exception using message = 'SERVICE_NOT_FOUND';
  end if;

  if v_service.deleted_at is not null or v_service.is_active is not true or v_service.status <> 'approved' then
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

  if to_regprocedure('public.service_allows_barber(uuid, uuid)') is not null
     and not public.service_allows_barber($1, $3) then
    raise exception using message = 'SERVICE_NOT_FOR_BARBER';
  end if;

  v_duration := coalesce(v_service.duration_minutes, v_service.duration_min, 30);
  if v_duration <= 0 then
    raise exception using message = 'INVALID_DURATION';
  end if;

  v_end_at := $2 + make_interval(mins => v_duration);

  select coalesce(br.buffer_minutes, s.buffer_minutes, 0)
  into v_buffer
  from public.barbers br
  left join public.barbershops s on s.id = br.shop_id
  where br.id = $3;

  delete from public.booking_slot_holds h
  where h.consumed_at is null and h.expires_at <= now();

  select h.*
  into v_existing_hold
  from public.booking_slot_holds h
  where h.profile_id = v_user
    and h.barber_id = $3
    and h.service_id = $1
    and h.shop_id is not distinct from v_shop_id
    and h.start_at = $2
    and h.end_at = v_end_at
    and h.consumed_at is null
    and h.expires_at > now()
  order by h.created_at desc
  limit 1
  for update;

  v_expires := now() + make_interval(mins => hold_minutes);

  if v_existing_hold.id is not null then
    update public.booking_slot_holds h
    set expires_at = greatest(h.expires_at, v_expires)
    where h.id = v_existing_hold.id
    returning h.id, h.expires_at into hold_id, expires_at;

    return next;
    return;
  end if;

  delete from public.booking_slot_holds h
  where h.profile_id = v_user
    and h.barber_id = $3
    and h.consumed_at is null
    and h.expires_at > now()
    and tstzrange(h.start_at, h.end_at, '[)') && tstzrange($2, v_end_at, '[)');

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
      and b.status in ('pending', 'confirmed', 'in_progress', 'rescheduled')
      and tstzrange(b.start_at, b.end_at + make_interval(mins => v_buffer), '[)') && tstzrange($2, v_end_at, '[)')
  ) then
    raise exception using message = 'BOOKING_OVERLAP';
  end if;

  if exists (
    select 1
    from public.booking_slot_holds h
    where h.barber_id = $3
      and h.profile_id <> v_user
      and h.consumed_at is null
      and h.expires_at > now()
      and tstzrange(h.start_at, h.end_at, '[)') && tstzrange($2, v_end_at, '[)')
  ) then
    raise exception using message = 'SLOT_HELD';
  end if;

  insert into public.booking_slot_holds as h (
    profile_id,
    barber_id,
    shop_id,
    service_id,
    start_at,
    end_at,
    expires_at
  )
  values (
    v_user,
    $3,
    v_shop_id,
    $1,
    $2,
    v_end_at,
    v_expires
  )
  returning h.id, h.expires_at into hold_id, expires_at;

  return next;
  return;
end;
$$;

revoke all on function public.hold_booking_slot(uuid, timestamptz, uuid, uuid, int) from public;
grant execute on function public.hold_booking_slot(uuid, timestamptz, uuid, uuid, int) to authenticated;

create or replace function public.create_booking(
  service_id uuid,
  start_at timestamptz,
  barber_id uuid,
  shop_id uuid default null,
  notes text default null,
  payment_method text default 'cash',
  source_post_id uuid default null,
  source text default 'unknown',
  reel_id uuid default null,
  offer_id uuid default null,
  discount_amount numeric(10,3) default 0
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
  p_source text := source;
  p_reel_id uuid := reel_id;
  p_offer_id uuid := offer_id;
  p_discount_amount numeric(10,3) := coalesce(discount_amount, 0)::numeric(10,3);
  v_user uuid;
  v_barber_shop_id uuid;
  v_service record;
  v_barber record;
  v_shop record;
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
  v_post record;
  v_offer record;
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  if p_barber_id is null then
    raise exception using message = 'INVALID_BARBER';
  end if;

  p_source_post_id := coalesce(p_source_post_id, p_reel_id);
  p_reel_id := coalesce(p_reel_id, p_source_post_id);

  select b.id, b.shop_id, b.deleted_at, b.is_active, b.status
  into v_barber
  from public.barbers b
  where b.id = p_barber_id
  limit 1;

  if v_barber.id is null then
    raise exception using message = 'INVALID_BARBER';
  end if;
  if v_barber.deleted_at is not null or v_barber.is_active is not true or v_barber.status <> 'approved' then
    raise exception using message = 'BARBER_INACTIVE';
  end if;

  v_barber_shop_id := v_barber.shop_id;

  if v_barber_shop_id is null and p_shop_id is not null then
    raise exception using message = 'INVALID_SHOP';
  end if;

  v_shop_id := coalesce(p_shop_id, v_barber_shop_id);
  if v_shop_id is not null then
    select s.id, s.deleted_at, s.is_active, s.status
    into v_shop
    from public.barbershops s
    where s.id = v_shop_id
    limit 1;
    if v_shop.id is null then
      raise exception using message = 'INVALID_SHOP';
    end if;
    if v_shop.deleted_at is not null or v_shop.is_active is not true or v_shop.status <> 'approved' then
      raise exception using message = 'SHOP_INACTIVE';
    end if;
    v_branch_id := public.ensure_shop_default_branch(v_shop_id);
  end if;

  select
    s.id,
    s.shop_id,
    s.barber_id,
    s.is_active,
    s.status,
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

  if v_service.deleted_at is not null or v_service.is_active is not true or v_service.status <> 'approved' then
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

  if to_regprocedure('public.service_allows_barber(uuid, uuid)') is not null
     and not public.service_allows_barber(p_service_id, p_barber_id) then
    raise exception using message = 'SERVICE_NOT_FOR_BARBER';
  end if;

  if p_source_post_id is not null then
    select p.id, p.deleted_at, p.is_active, p.status
    into v_post
    from public.posts p
    where p.id = p_source_post_id
    limit 1;

    if v_post.id is null then
      raise exception using message = 'INVALID_SOURCE_POST';
    end if;
    if v_post.deleted_at is not null or v_post.is_active is not true or v_post.status <> 'approved' then
      raise exception using message = 'SOURCE_POST_INACTIVE';
    end if;
  end if;

  if p_offer_id is not null then
    select o.id, o.shop_id, o.barber_id, o.active, o.is_active, o.status, o.valid_from, o.valid_to
    into v_offer
    from public.offers o
    where o.id = p_offer_id
    limit 1;

    if v_offer.id is null then
      raise exception using message = 'INVALID_OFFER';
    end if;
    if coalesce(v_offer.active, true) is not true
      or coalesce(v_offer.is_active, true) is not true
      or v_offer.status <> 'approved'
      or (v_offer.valid_from is not null and v_offer.valid_from > now())
      or (v_offer.valid_to is not null and v_offer.valid_to < now()) then
      raise exception using message = 'OFFER_INACTIVE';
    end if;
    if v_offer.barber_id is not null and v_offer.barber_id <> p_barber_id then
      raise exception using message = 'OFFER_NOT_FOR_BARBER';
    end if;
    if v_offer.shop_id is not null and v_shop_id is not null and v_offer.shop_id <> v_shop_id then
      raise exception using message = 'OFFER_NOT_FOR_SHOP';
    end if;
  end if;

  v_duration := coalesce(v_service.duration_minutes, v_service.duration_min, 30);
  if v_duration <= 0 then
    raise exception using message = 'INVALID_DURATION';
  end if;

  v_price := coalesce(v_service.price_bhd, v_service.price, 0)::numeric(10,3);
  if p_discount_amount < 0 then
    raise exception using message = 'INVALID_DISCOUNT';
  end if;
  if p_discount_amount > v_price then
    p_discount_amount := v_price;
  end if;
  v_end_at := p_start_at + make_interval(mins => v_duration);

  select coalesce(br.buffer_minutes, s.buffer_minutes, 0)
  into v_buffer
  from public.barbers br
  left join public.barbershops s on s.id = br.shop_id
  where br.id = p_barber_id;

  if exists (
    select 1
    from public.booking_slot_holds h
    where h.barber_id = p_barber_id
      and h.profile_id <> v_user
      and h.consumed_at is null
      and h.expires_at > now()
      and tstzrange(h.start_at, h.end_at, '[)') && tstzrange(p_start_at, v_end_at, '[)')
  ) then
    raise exception using message = 'SLOT_HELD';
  end if;

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
      and b.status in ('pending', 'confirmed', 'in_progress', 'rescheduled')
      and tstzrange(b.start_at, b.end_at + make_interval(mins => v_buffer), '[)') && tstzrange(p_start_at, v_end_at, '[)')
  ) then
    raise exception using message = 'BOOKING_OVERLAP';
  end if;

  v_payment_method := lower(trim(coalesce(p_payment_method, '')));
  if v_payment_method not in ('cash', 'card', 'benefitpay', 'apple_pay', 'stc_pay') then
    v_payment_method := 'cash';
  end if;

  if v_payment_method <> 'cash' then
    raise exception using message = 'PAYMENT_METHOD_NOT_SUPPORTED';
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
    payment_status,
    discount_amount,
    source,
    source_post_id,
    reel_id,
    offer_id
  )
  values (
    v_user,
    v_shop_id,
    v_branch_id,
    p_barber_id,
    p_service_id,
    p_start_at,
    v_end_at,
    'confirmed',
    p_notes,
    greatest(v_price - p_discount_amount, 0)::numeric(10,3),
    'BHD',
    v_price,
    v_duration,
    v_deposit_required,
    v_payment_method,
    case when v_deposit_required > 0 then 'pending' else 'unpaid' end,
    p_discount_amount,
    coalesce(nullif(trim(coalesce(p_source, '')), ''), 'unknown'),
    p_source_post_id,
    p_reel_id,
    p_offer_id
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

revoke all on function public.create_booking(uuid, timestamptz, uuid, uuid, text, text, uuid, text, uuid, uuid, numeric) from public;
grant execute on function public.create_booking(uuid, timestamptz, uuid, uuid, text, text, uuid, text, uuid, uuid, numeric) to authenticated;

commit;

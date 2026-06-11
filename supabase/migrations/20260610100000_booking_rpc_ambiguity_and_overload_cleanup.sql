begin;

drop function if exists public.create_booking(uuid, timestamptz, uuid, uuid, text);
drop function if exists public.create_booking(uuid, timestamptz, uuid, uuid, text, text, uuid);
drop function if exists public.create_booking_with_hold(uuid, timestamptz, uuid, uuid, uuid, text);
drop function if exists public.create_booking_with_hold(uuid, timestamptz, uuid, uuid, uuid, text, text, uuid);

create or replace function public.get_available_times(
  barber uuid,
  day date,
  duration_minutes int,
  slot_minutes int default 15
)
returns table (start_at timestamptz)
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  weekday0 int;
  w record;
  start_local timestamp;
  end_local timestamp;
  candidate_local timestamp;
  candidate_start timestamptz;
  candidate_end timestamptz;
  step interval;
  dur interval := make_interval(mins => greatest(duration_minutes, 1));
  v_requested_slot int := slot_minutes;
  v_slot int := slot_minutes;
  v_buffer int := 0;
  v_shop uuid;
  v_has_custom_hours boolean := false;
begin
  if duration_minutes is null or duration_minutes <= 0 then
    return;
  end if;

  select
    br.shop_id,
    coalesce(br.slot_minutes, s.slot_minutes, v_requested_slot),
    coalesce(br.buffer_minutes, s.buffer_minutes, 0)
  into v_shop, v_slot, v_buffer
  from public.barbers br
  left join public.barbershops s on s.id = br.shop_id
  where br.id = barber;

  if v_slot is null or v_slot <= 0 then
    v_slot := greatest(v_requested_slot, 15);
  end if;

  step := make_interval(mins => v_slot);
  weekday0 := extract(dow from day)::int;

  select (
    exists (
      select 1
      from public.barber_working_hours wh
      where wh.barber_id = barber
        and wh.enabled = true
        and wh.weekday = weekday0
    )
    or exists (
      select 1
      from public.shop_working_hours swh
      where v_shop is not null
        and swh.shop_id = v_shop
        and swh.enabled = true
        and swh.weekday = weekday0
    )
  )
  into v_has_custom_hours;

  for w in (
    select wh.start_time, wh.end_time
    from public.barber_working_hours wh
    where wh.barber_id = barber
      and wh.enabled = true
      and wh.weekday = weekday0

    union all

    select swh.start_time, swh.end_time
    from public.shop_working_hours swh
    where v_shop is not null
      and swh.shop_id = v_shop
      and swh.enabled = true
      and swh.weekday = weekday0
      and not exists (
        select 1
        from public.barber_working_hours wh
        where wh.barber_id = barber
          and wh.enabled = true
          and wh.weekday = weekday0
      )

    union all

    select time '00:00:00' as start_time, time '23:59:59' as end_time
    where not v_has_custom_hours

    order by start_time asc
  )
  loop
    start_local := day::timestamp + w.start_time;
    end_local := day::timestamp + w.end_time;
    if end_local <= start_local then
      end_local := end_local + interval '1 day';
    end if;

    candidate_local := start_local;

    while candidate_local + dur <= end_local loop
      candidate_start := candidate_local at time zone 'Asia/Bahrain';
      candidate_end := (candidate_local + dur) at time zone 'Asia/Bahrain';

      if candidate_start >= now()
        and not exists (
          select 1
          from public.barber_time_off t
          where t.barber_id = barber
            and tstzrange(t.starts_at, t.ends_at, '[)') && tstzrange(candidate_start, candidate_end, '[)')
        )
        and not exists (
          select 1
          from public.bookings b
          where b.barber_id = barber
            and b.status in ('pending', 'confirmed', 'in_progress', 'rescheduled')
            and tstzrange(b.start_at, b.end_at + make_interval(mins => v_buffer), '[)')
              && tstzrange(candidate_start, candidate_end, '[)')
        )
        and not exists (
          select 1
          from public.booking_slot_holds h
          where h.barber_id = barber
            and h.consumed_at is null
            and h.expires_at > now()
            and tstzrange(h.start_at, h.end_at, '[)') && tstzrange(candidate_start, candidate_end, '[)')
        )
      then
        start_at := candidate_start;
        return next;
      end if;

      candidate_local := candidate_local + step;
    end loop;
  end loop;
end;
$$;

revoke all on function public.get_available_times(uuid, date, int, int) from public;
grant execute on function public.get_available_times(uuid, date, int, int) to anon, authenticated;

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
      and b.status in ('pending','confirmed','in_progress')
      and tstzrange(b.start_at, b.end_at + make_interval(mins => v_buffer), '[)') && tstzrange(p_start_at, v_end_at, '[)')
  ) then
    raise exception using message = 'BOOKING_OVERLAP';
  end if;

  v_payment_method := lower(trim(coalesce(p_payment_method, '')));
  if v_payment_method not in ('cash','card','benefitpay','apple_pay','stc_pay') then
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

create or replace function public.create_booking_with_hold(
  service_id uuid,
  start_at timestamptz,
  barber_id uuid,
  hold_id uuid,
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

  v_booking := public.create_booking($1, $2, $3, $5, $6, $7, $8, $9, $10, $11, $12);

  update public.booking_slot_holds
  set consumed_at = now()
  where id = v_hold.id;

  return v_booking;
end;
$$;

revoke all on function public.create_booking_with_hold(uuid, timestamptz, uuid, uuid, uuid, text, text, uuid, text, uuid, uuid, numeric) from public;
grant execute on function public.create_booking_with_hold(uuid, timestamptz, uuid, uuid, uuid, text, text, uuid, text, uuid, uuid, numeric) to authenticated;

commit;

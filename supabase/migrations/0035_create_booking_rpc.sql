begin;

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

  select
    s.id,
    s.shop_id,
    s.barber_id,
    s.is_active,
    s.deleted_at,
    s.price_bhd,
    s.duration_minutes,
    s.price,
    s.duration_min
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
    duration_minutes
  )
  values (
    v_user,
    v_shop_id,
    barber_id,
    service_id,
    start_at,
    v_end_at,
    'pending',
    notes,
    v_price,
    'BHD',
    v_price,
    v_duration
  )
  returning * into v_booking;

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

commit;

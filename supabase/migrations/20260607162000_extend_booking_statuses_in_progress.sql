begin;

alter table public.bookings drop constraint if exists bookings_status_check;

alter table public.bookings
add constraint bookings_status_check
check (status in ('pending','confirmed','in_progress','rescheduled','no_show','cancelled','completed'));

alter table public.bookings drop constraint if exists bookings_no_overlap_per_barber;

alter table public.bookings
add constraint bookings_no_overlap_per_barber
exclude using gist (
  barber_id with =,
  tstzrange(start_at, end_at, '[)') with &&
)
where (barber_id is not null and status in ('pending','confirmed','in_progress','rescheduled'));

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
as $$
declare
  v_user uuid;
  v_service record;
  v_duration int;
  v_end_at timestamptz;
  v_shop_id uuid;
  v_barber_shop_id uuid;
  v_expires timestamptz;
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  if hold_minutes is null or hold_minutes < 1 or hold_minutes > 30 then
    hold_minutes := 5;
  end if;

  select b.shop_id into v_barber_shop_id from public.barbers b where b.id = $3;
  v_shop_id := coalesce(shop_id, v_barber_shop_id);

  select
    s.id,
    s.shop_id,
    s.barber_id,
    s.is_active,
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

  v_end_at := $2 + make_interval(mins => v_duration);

  delete from public.booking_slot_holds h
  where h.consumed_at is null and h.expires_at <= now();

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
      and b.status in ('pending','confirmed','in_progress','rescheduled')
      and tstzrange(b.start_at, b.end_at, '[)') && tstzrange($2, v_end_at, '[)')
  ) then
    raise exception using message = 'BOOKING_OVERLAP';
  end if;

  if exists (
    select 1
    from public.booking_slot_holds h
    where h.barber_id = $3
      and h.consumed_at is null
      and h.expires_at > now()
      and tstzrange(h.start_at, h.end_at, '[)') && tstzrange($2, v_end_at, '[)')
  ) then
    raise exception using message = 'SLOT_HELD';
  end if;

  v_expires := now() + make_interval(mins => hold_minutes);

  insert into public.booking_slot_holds (
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
  returning id, expires_at into hold_id, expires_at;

  return;
end;
$$;

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
as $$
declare
  v_start timestamptz;
  v_end timestamptz;
  v_day_start timestamptz;
  v_day_end timestamptz;
begin
  v_day_start := day::timestamptz;
  v_day_end := (day + 1)::timestamptz;

  for v_start in
    select gs
    from generate_series(v_day_start, v_day_end - make_interval(mins => duration_minutes), make_interval(mins => slot_minutes)) gs
  loop
    v_end := v_start + make_interval(mins => duration_minutes);

    if exists (
      select 1
      from public.barber_time_off t
      where t.barber_id = barber
        and tstzrange(t.starts_at, t.ends_at, '[)') && tstzrange(v_start, v_end, '[)')
    ) then
      continue;
    end if;

    if exists (
      select 1
      from public.bookings b
      where b.barber_id = barber
        and b.status in ('pending','confirmed','in_progress','rescheduled')
        and tstzrange(b.start_at, b.end_at, '[)') && tstzrange(v_start, v_end, '[)')
    ) then
      continue;
    end if;

    if exists (
      select 1
      from public.booking_slot_holds h
      where h.barber_id = barber
        and h.consumed_at is null
        and h.expires_at > now()
        and tstzrange(h.start_at, h.end_at, '[)') && tstzrange(v_start, v_end, '[)')
    ) then
      continue;
    end if;

    start_at := v_start;
    return next;
  end loop;
end;
$$;

commit;


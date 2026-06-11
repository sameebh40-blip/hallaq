begin;

create or replace function public.get_available_times_for_booking_move(
  barber uuid,
  day date,
  duration_minutes int,
  exclude_booking_id uuid,
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

      if not exists (
        select 1
        from public.barber_time_off t
        where t.barber_id = barber
          and tstzrange(t.starts_at, t.ends_at, '[)') && tstzrange(candidate_start, candidate_end, '[)')
      )
      and not exists (
        select 1
        from public.bookings b
        where b.barber_id = barber
          and b.id is distinct from exclude_booking_id
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

revoke all on function public.get_available_times_for_booking_move(uuid, date, int, uuid, int) from public;
grant execute on function public.get_available_times_for_booking_move(uuid, date, int, uuid, int) to anon, authenticated;

create or replace function public.reassign_booking(
  booking_id uuid,
  new_barber_id uuid,
  new_start_at timestamptz
)
returns public.bookings
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_user uuid;
  v_booking public.bookings%rowtype;
  v_service record;
  v_buffer int := 0;
  v_end_at timestamptz;
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

  if new_barber_id is null then
    raise exception using message = 'INVALID_BARBER';
  end if;

  if new_start_at is null then
    raise exception using message = 'INVALID_START_AT';
  end if;

  if not public.booking_actor_has_staff_access(v_user, v_booking.shop_id, v_booking.branch_id, v_booking.barber_id) then
    raise exception using message = 'FORBIDDEN';
  end if;

  if v_booking.status in ('cancelled', 'completed', 'in_progress', 'no_show') then
    raise exception using message = 'BOOKING_NOT_REASSIGNABLE';
  end if;

  if v_booking.start_at <= now() or new_start_at <= now() then
    raise exception using message = 'TOO_LATE_TO_REASSIGN';
  end if;

  if not exists (
    select 1
    from public.barbers br
    where br.id = new_barber_id
      and br.shop_id = v_booking.shop_id
      and br.deleted_at is null
      and br.is_active is true
  ) then
    raise exception using message = 'BARBER_NOT_IN_SHOP';
  end if;

  select id, shop_id, barber_id
  into v_service
  from public.services s
  where s.id = v_booking.service_id
    and s.deleted_at is null
    and s.is_active is true
  limit 1;

  if v_service.id is null then
    raise exception using message = 'SERVICE_NOT_FOUND';
  end if;

  if not exists (
    select 1
    from public.barber_services_effective bse
    where bse.id = v_booking.service_id
      and bse.barber_ref = new_barber_id
  ) then
    raise exception using message = 'SERVICE_NOT_FOR_BARBER';
  end if;

  select coalesce(s.buffer_minutes, 0)
  into v_buffer
  from public.barbershops s
  where s.id = v_booking.shop_id
  limit 1;

  v_end_at := new_start_at + make_interval(mins => coalesce(v_booking.duration_minutes, 30));

  if exists (
    select 1
    from public.barber_time_off t
    where t.barber_id = new_barber_id
      and tstzrange(t.starts_at, t.ends_at, '[)') && tstzrange(new_start_at, v_end_at, '[)')
  ) then
    raise exception using message = 'BARBER_TIME_OFF';
  end if;

  if exists (
    select 1
    from public.bookings b
    where b.barber_id = new_barber_id
      and b.id <> v_booking.id
      and b.status in ('pending', 'confirmed', 'rescheduled', 'in_progress')
      and tstzrange(b.start_at, b.end_at + make_interval(mins => v_buffer), '[)') && tstzrange(new_start_at, v_end_at, '[)')
  ) then
    raise exception using message = 'BOOKING_OVERLAP';
  end if;

  perform set_config('hallaq.allow_booking_reassign', '1', true);

  update public.bookings
  set barber_id = new_barber_id,
      start_at = new_start_at,
      end_at = v_end_at,
      rescheduled_at = now(),
      rescheduled_by_profile_id = v_user,
      status = case when v_booking.status in ('confirmed', 'rescheduled') then 'rescheduled' else v_booking.status end,
      updated_at = now()
  where id = v_booking.id
  returning * into v_booking;

  return v_booking;
end;
$$;

revoke all on function public.reassign_booking(uuid, uuid, timestamptz) from public;
grant execute on function public.reassign_booking(uuid, uuid, timestamptz) to authenticated;

commit;


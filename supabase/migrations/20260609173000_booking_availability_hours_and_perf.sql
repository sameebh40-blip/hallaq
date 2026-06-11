begin;

create extension if not exists btree_gist;

create index if not exists booking_slot_holds_barber_active_range_gist
on public.booking_slot_holds
using gist (barber_id, tstzrange(start_at, end_at, '[)'))
where consumed_at is null;

create index if not exists booking_slot_holds_active_expires_idx
on public.booking_slot_holds (expires_at)
where consumed_at is null;

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

do $$
begin
  if to_regclass('public.availability_cache_days') is not null then
    delete from public.availability_cache_days;
  end if;
end;
$$;

commit;

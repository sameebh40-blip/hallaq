begin;

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

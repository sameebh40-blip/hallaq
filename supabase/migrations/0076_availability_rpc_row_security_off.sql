begin;

create or replace function public.get_available_times(
  barber uuid,
  day date,
  duration_minutes int,
  slot_minutes int default 30
)
returns table(start_at timestamptz)
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
  v_slot int := slot_minutes;
  v_buffer int := 0;
begin
  if duration_minutes is null or duration_minutes <= 0 then
    return;
  end if;

  select
    coalesce(br.slot_minutes, s.slot_minutes, slot_minutes),
    coalesce(br.buffer_minutes, s.buffer_minutes, 0)
  into v_slot, v_buffer
  from public.barbers br
  left join public.barbershops s on s.id = br.shop_id
  where br.id = barber;

  if v_slot is null or v_slot <= 0 then
    v_slot := 30;
  end if;

  step := make_interval(mins => v_slot);
  weekday0 := extract(dow from day)::int;

  for w in
    select start_time, end_time
    from public.barber_working_hours
    where barber_id = barber
      and enabled = true
      and weekday = weekday0
    order by start_time asc
  loop
    start_local := (day::timestamp + w.start_time);
    end_local := (day::timestamp + w.end_time);
    candidate_local := start_local;

    while candidate_local + dur <= end_local loop
      candidate_start := (candidate_local at time zone 'Asia/Bahrain');
      candidate_end := (candidate_local + dur at time zone 'Asia/Bahrain');

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
            and (
              b.status = 'confirmed'
              or (b.status = 'pending' and b.created_at > now() - interval '10 minutes')
            )
            and tstzrange(b.start_at, b.end_at + make_interval(mins => v_buffer), '[)') && tstzrange(candidate_start, candidate_end, '[)')
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

create or replace function public.get_available_days(
  barber uuid,
  month date,
  duration_minutes int,
  slot_minutes int default 30
)
returns table(day date, has_slots boolean)
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  month0 date;
  last_day date;
  today0 date;
  d date;
begin
  if duration_minutes is null or duration_minutes <= 0 then
    return;
  end if;

  month0 := date_trunc('month', month)::date;
  last_day := (date_trunc('month', month0) + interval '1 month - 1 day')::date;
  today0 := (now() at time zone 'Asia/Bahrain')::date;

  d := greatest(month0, today0);
  while d <= last_day loop
    day := d;
    has_slots := exists (
      select 1
      from public.get_available_times(barber, d, duration_minutes, slot_minutes)
      limit 1
    );
    return next;
    d := d + 1;
  end loop;
end;
$$;

revoke all on function public.get_available_days(uuid, date, int, int) from public;
grant execute on function public.get_available_days(uuid, date, int, int) to anon, authenticated;

commit;


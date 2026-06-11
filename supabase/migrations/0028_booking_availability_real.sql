begin;

create extension if not exists btree_gist;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'bookings_no_overlap_per_barber'
      and conrelid = 'public.bookings'::regclass
  ) then
    alter table public.bookings
    add constraint bookings_no_overlap_per_barber
    exclude using gist (
      barber_id with =,
      tstzrange(start_at, end_at, '[)') with &&
    )
    where (barber_id is not null and status in ('pending','confirmed'));
  end if;
end $$;

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
as $$
declare
  weekday0 int;
  work_window record;
  start_local timestamp;
  end_local timestamp;
  candidate_local timestamp;
  candidate_start timestamptz;
  candidate_end timestamptz;
  step interval := make_interval(mins => slot_minutes);
  dur interval := make_interval(mins => greatest(duration_minutes, 1));
begin
  if duration_minutes is null or duration_minutes <= 0 then
    return;
  end if;

  weekday0 := extract(dow from day)::int;

  for work_window in
    select start_time, end_time
    from public.barber_working_hours
    where barber_id = barber
      and enabled = true
      and weekday = weekday0
    order by start_time asc
  loop
    start_local := (day::timestamp + work_window.start_time);
    end_local := (day::timestamp + work_window.end_time);
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
            and b.status in ('pending','confirmed')
            and tstzrange(b.start_at, b.end_at, '[)') && tstzrange(candidate_start, candidate_end, '[)')
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

do $$
begin
  if to_regprocedure('public.get_available_times(uuid, date, int, int)') is not null then
    if exists (select 1 from pg_roles where rolname = 'anon') then
      grant execute on function public.get_available_times(uuid, date, int, int) to anon;
    end if;
    if exists (select 1 from pg_roles where rolname = 'authenticated') then
      grant execute on function public.get_available_times(uuid, date, int, int) to authenticated;
    end if;
  end if;
end;
$$;

commit;

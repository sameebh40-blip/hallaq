begin;

create index if not exists availability_cache_days_lookup_idx
on public.availability_cache_days (barber_id, duration_minutes, slot_minutes, day);

create table if not exists public.availability_cache_runs (
  id uuid primary key default gen_random_uuid(),
  run_type text not null check (run_type in ('warm_all','warm_barber','cleanup')),
  barber_id uuid references public.barbers (id) on delete set null,
  days_ahead int,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  ok boolean,
  rows_affected int,
  error_text text
);

alter table public.availability_cache_runs enable row level security;

drop policy if exists "availability_cache_runs_admin_read" on public.availability_cache_runs;
create policy "availability_cache_runs_admin_read"
on public.availability_cache_runs
for select
to authenticated
using (public.is_admin());

create or replace function public.cleanup_availability_cache_days(p_days_ahead int default 62)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  today0 date := (now() at time zone 'Asia/Bahrain')::date;
  end0 date := (today0 + make_interval(days => greatest(coalesce(p_days_ahead, 62), 0)))::date;
  v_rows int;
  v_run uuid;
begin
  insert into public.availability_cache_runs (run_type, days_ahead, ok)
  values ('cleanup', p_days_ahead, null)
  returning id into v_run;

  delete from public.availability_cache_days
  where day < today0 or day > end0;
  get diagnostics v_rows = row_count;

  update public.availability_cache_runs
  set finished_at = now(),
      ok = true,
      rows_affected = v_rows
  where id = v_run;
exception
  when others then
    update public.availability_cache_runs
    set finished_at = now(),
        ok = false,
        error_text = sqlerrm
    where id = v_run;
end;
$$;

create or replace function public.cleanup_availability_cache_days()
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  perform public.cleanup_availability_cache_days(62);
end;
$$;

create or replace function public.warm_availability_cache_for_barber(
  p_barber uuid,
  p_days_ahead int default 62,
  p_duration_minutes int[] default null,
  p_slot_minutes int default 30
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  today0 date := (now() at time zone 'Asia/Bahrain')::date;
  end0 date := (today0 + make_interval(days => greatest(coalesce(p_days_ahead, 62), 0)))::date;
  d date;
  dur int;
  durations int[];
  v_has boolean;
  v_rows int := 0;
  v_run uuid;
begin
  if p_barber is null then
    return;
  end if;

  insert into public.availability_cache_runs (run_type, barber_id, days_ahead, ok)
  values ('warm_barber', p_barber, p_days_ahead, null)
  returning id into v_run;

  durations := p_duration_minutes;
  if durations is null or array_length(durations, 1) is null then
    select array_agg(distinct coalesce(s.duration_minutes, s.duration_min, 30)::int order by coalesce(s.duration_minutes, s.duration_min, 30)::int)
    into durations
    from public.services s
    where s.deleted_at is null and s.is_active is true;
  end if;
  if durations is null or array_length(durations, 1) is null then
    durations := array[30];
  end if;

  for dur in select unnest(durations) loop
    if dur is null or dur <= 0 then
      continue;
    end if;
    d := today0;
    while d <= end0 loop
      v_has := exists (select 1 from public.get_available_times(p_barber, d, dur, p_slot_minutes) limit 1);
      insert into public.availability_cache_days (barber_id, day, duration_minutes, slot_minutes, has_slots, computed_at)
      values (p_barber, d, dur, p_slot_minutes, v_has, now())
      on conflict (barber_id, day, duration_minutes, slot_minutes)
      do update set has_slots = excluded.has_slots, computed_at = excluded.computed_at;
      v_rows := v_rows + 1;
      d := d + 1;
    end loop;
  end loop;

  update public.availability_cache_runs
  set finished_at = now(),
      ok = true,
      rows_affected = v_rows
  where id = v_run;
exception
  when others then
    update public.availability_cache_runs
    set finished_at = now(),
        ok = false,
        error_text = sqlerrm
    where id = v_run;
end;
$$;

create or replace function public.warm_availability_cache_all(
  p_days_ahead int default 62,
  p_max_barbers int default 400,
  p_slot_minutes int default 30
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  b record;
  i int := 0;
  v_run uuid;
begin
  insert into public.availability_cache_runs (run_type, days_ahead, ok)
  values ('warm_all', p_days_ahead, null)
  returning id into v_run;

  for b in
    select br.id
    from public.barbers br
    order by br.created_at desc
  loop
    i := i + 1;
    if p_max_barbers is not null and p_max_barbers > 0 and i > p_max_barbers then
      exit;
    end if;
    perform public.warm_availability_cache_for_barber(b.id, p_days_ahead, null, p_slot_minutes);
  end loop;

  update public.availability_cache_runs
  set finished_at = now(),
      ok = true,
      rows_affected = i
  where id = v_run;
exception
  when others then
    update public.availability_cache_runs
    set finished_at = now(),
        ok = false,
        error_text = sqlerrm
    where id = v_run;
end;
$$;

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

create or replace function public.availability_cache_on_service_duration_change()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  b uuid;
  dur int;
begin
  if tg_op = 'DELETE' then
    return null;
  end if;

  if new.barber_id is null then
    return null;
  end if;

  if tg_op = 'INSERT' then
    b := new.barber_id;
  else
    if coalesce(new.duration_minutes, new.duration_min, 30) is distinct from coalesce(old.duration_minutes, old.duration_min, 30) then
      b := new.barber_id;
    else
      return null;
    end if;
  end if;

  dur := coalesce(new.duration_minutes, new.duration_min, 30)::int;
  if dur <= 0 then dur := 30; end if;
  perform public.warm_availability_cache_for_barber(b, 62, array[dur], 30);
  return null;
end;
$$;

drop trigger if exists services_refresh_availability_cache on public.services;
create trigger services_refresh_availability_cache
after insert or update on public.services
for each row execute function public.availability_cache_on_service_duration_change();

commit;


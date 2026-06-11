begin;

create index if not exists availability_cache_days_barber_day_idx
on public.availability_cache_days (barber_id, day);

create index if not exists availability_cache_days_day_idx
on public.availability_cache_days (day);

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
begin
  if p_barber is null then
    return;
  end if;

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
      d := d + 1;
    end loop;
  end loop;
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
begin
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
end;
$$;

create or replace function public.cleanup_availability_cache_days()
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  today0 date := (now() at time zone 'Asia/Bahrain')::date;
begin
  delete from public.availability_cache_days
  where day < today0;
end;
$$;

do $do$
begin
  create extension if not exists pg_cron;
exception
  when insufficient_privilege then null;
  when undefined_file then null;
end;
$do$;

do $do$
begin
  perform cron.schedule(
    'availability_cache_warm_daily',
    '15 3 * * *',
    $cmd$select public.warm_availability_cache_all(62, 400, 30);$cmd$
  );
exception
  when undefined_function then null;
  when duplicate_object then null;
end;
$do$;

do $do$
begin
  perform cron.schedule(
    'availability_cache_cleanup_daily',
    '10 3 * * *',
    $cmd$select public.cleanup_availability_cache_days();$cmd$
  );
exception
  when undefined_function then null;
  when duplicate_object then null;
end;
$do$;

commit;

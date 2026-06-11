begin;

create table if not exists public.availability_cache_days (
  barber_id uuid not null references public.barbers (id) on delete cascade,
  day date not null,
  duration_minutes int not null,
  slot_minutes int not null default 30,
  has_slots boolean not null default false,
  computed_at timestamptz not null default now(),
  primary key (barber_id, day, duration_minutes, slot_minutes)
);

alter table public.availability_cache_days enable row level security;

drop policy if exists "availability_cache_days_read_public" on public.availability_cache_days;
create policy "availability_cache_days_read_public"
on public.availability_cache_days
for select
to anon, authenticated
using (true);

create or replace function public.refresh_availability_cache_day(
  p_barber uuid,
  p_day date
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  r record;
  v_has boolean;
begin
  for r in
    select duration_minutes, slot_minutes
    from public.availability_cache_days
    where barber_id = p_barber and day = p_day
  loop
    v_has := exists (
      select 1
      from public.get_available_times(p_barber, p_day, r.duration_minutes, r.slot_minutes)
      limit 1
    );

    update public.availability_cache_days
    set has_slots = v_has,
        computed_at = now()
    where barber_id = p_barber
      and day = p_day
      and duration_minutes = r.duration_minutes
      and slot_minutes = r.slot_minutes;
  end loop;
end;
$$;

create or replace function public.refresh_availability_cache_days_range(
  p_barber uuid,
  p_start_day date,
  p_end_day date,
  max_days int default 62
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  d date;
  i int := 0;
begin
  if p_start_day is null or p_end_day is null then
    return;
  end if;
  d := p_start_day;
  while d <= p_end_day loop
    i := i + 1;
    if max_days is not null and max_days > 0 and i > max_days then
      exit;
    end if;
    perform public.refresh_availability_cache_day(p_barber, d);
    d := d + 1;
  end loop;
end;
$$;

create or replace function public.availability_cache_on_booking_change()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  old_day date;
  new_day date;
  old_barber uuid;
  new_barber uuid;
begin
  if tg_op = 'INSERT' then
    new_barber := new.barber_id;
    if new_barber is null then return null; end if;
    new_day := (new.start_at at time zone 'Asia/Bahrain')::date;
    perform public.refresh_availability_cache_day(new_barber, new_day);
    return null;
  end if;

  if tg_op = 'DELETE' then
    old_barber := old.barber_id;
    if old_barber is null then return null; end if;
    old_day := (old.start_at at time zone 'Asia/Bahrain')::date;
    perform public.refresh_availability_cache_day(old_barber, old_day);
    return null;
  end if;

  old_barber := old.barber_id;
  new_barber := new.barber_id;
  if old_barber is not null then
    old_day := (old.start_at at time zone 'Asia/Bahrain')::date;
    perform public.refresh_availability_cache_day(old_barber, old_day);
  end if;
  if new_barber is not null then
    new_day := (new.start_at at time zone 'Asia/Bahrain')::date;
    if old_barber is distinct from new_barber or old_day is distinct from new_day then
      perform public.refresh_availability_cache_day(new_barber, new_day);
    end if;
  end if;
  return null;
end;
$$;

drop trigger if exists bookings_refresh_availability_cache on public.bookings;
create trigger bookings_refresh_availability_cache
after insert or update or delete on public.bookings
for each row execute function public.availability_cache_on_booking_change();

create or replace function public.availability_cache_on_time_off_change()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  b uuid;
  start_day date;
  end_day date;
begin
  if tg_op = 'DELETE' then
    b := old.barber_id;
    start_day := (old.starts_at at time zone 'Asia/Bahrain')::date;
    end_day := (old.ends_at at time zone 'Asia/Bahrain')::date;
  else
    b := new.barber_id;
    start_day := (new.starts_at at time zone 'Asia/Bahrain')::date;
    end_day := (new.ends_at at time zone 'Asia/Bahrain')::date;
  end if;

  if b is null then return null; end if;
  perform public.refresh_availability_cache_days_range(b, start_day, end_day);
  return null;
end;
$$;

drop trigger if exists barber_time_off_refresh_availability_cache on public.barber_time_off;
create trigger barber_time_off_refresh_availability_cache
after insert or update or delete on public.barber_time_off
for each row execute function public.availability_cache_on_time_off_change();

create or replace function public.availability_cache_on_working_hours_change()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  b uuid;
  today0 date;
  end0 date;
  d record;
begin
  if tg_op = 'DELETE' then
    b := old.barber_id;
  else
    b := new.barber_id;
  end if;
  if b is null then return null; end if;

  today0 := (now() at time zone 'Asia/Bahrain')::date;
  end0 := (today0 + interval '62 days')::date;

  for d in
    select distinct day
    from public.availability_cache_days
    where barber_id = b and day between today0 and end0
  loop
    perform public.refresh_availability_cache_day(b, d.day);
  end loop;

  return null;
end;
$$;

drop trigger if exists barber_working_hours_refresh_availability_cache on public.barber_working_hours;
create trigger barber_working_hours_refresh_availability_cache
after insert or update or delete on public.barber_working_hours
for each row execute function public.availability_cache_on_working_hours_change();

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
  cached boolean;
begin
  if duration_minutes is null or duration_minutes <= 0 then
    return;
  end if;

  month0 := date_trunc('month', month)::date;
  last_day := (date_trunc('month', month0) + interval '1 month - 1 day')::date;
  today0 := (now() at time zone 'Asia/Bahrain')::date;

  d := greatest(month0, today0);
  while d <= last_day loop
    select a.has_slots
    into cached
    from public.availability_cache_days a
    where a.barber_id = barber
      and a.day = d
      and a.duration_minutes = duration_minutes
      and a.slot_minutes = slot_minutes
    limit 1;

    if cached is null then
      cached := exists (
        select 1
        from public.get_available_times(barber, d, duration_minutes, slot_minutes)
        limit 1
      );

      insert into public.availability_cache_days (barber_id, day, duration_minutes, slot_minutes, has_slots, computed_at)
      values (barber, d, duration_minutes, slot_minutes, cached, now())
      on conflict (barber_id, day, duration_minutes, slot_minutes)
      do update set has_slots = excluded.has_slots, computed_at = excluded.computed_at;
    end if;

    day := d;
    has_slots := cached;
    return next;
    d := d + 1;
  end loop;
end;
$$;

revoke all on function public.get_available_days(uuid, date, int, int) from public;
grant execute on function public.get_available_days(uuid, date, int, int) to anon, authenticated;

alter table public.availability_cache_days replica identity full;
do $$
begin
  alter publication supabase_realtime add table public.availability_cache_days;
exception
  when duplicate_object then null;
  when undefined_object then null;
end;
$$;

commit;

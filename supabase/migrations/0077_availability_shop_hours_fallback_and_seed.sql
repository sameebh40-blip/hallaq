begin;

create or replace function public.seed_barber_working_hours_defaults(p_barber uuid)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_shop uuid;
begin
  if p_barber is null then
    return;
  end if;

  if exists (select 1 from public.barber_working_hours wh where wh.barber_id = p_barber) then
    return;
  end if;

  select b.shop_id into v_shop
  from public.barbers b
  where b.id = p_barber;

  if v_shop is not null and exists (select 1 from public.shop_working_hours s where s.shop_id = v_shop) then
    insert into public.barber_working_hours (barber_id, weekday, start_time, end_time, enabled)
    select p_barber, s.weekday, s.start_time, s.end_time, s.enabled
    from public.shop_working_hours s
    where s.shop_id = v_shop;
    return;
  end if;

  insert into public.barber_working_hours (barber_id, weekday, start_time, end_time, enabled)
  select p_barber, d.weekday, '10:00'::time, '22:00'::time, true
  from (select generate_series(0, 6) as weekday) d;
end;
$$;

create or replace function public.barbers_seed_working_hours_trg()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  perform public.seed_barber_working_hours_defaults(new.id);
  return new;
end;
$$;

drop trigger if exists barbers_seed_working_hours on public.barbers;
create trigger barbers_seed_working_hours
after insert on public.barbers
for each row execute function public.barbers_seed_working_hours_trg();

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
  v_shop uuid;
begin
  if duration_minutes is null or duration_minutes <= 0 then
    return;
  end if;

  select
    br.shop_id,
    coalesce(br.slot_minutes, s.slot_minutes, slot_minutes),
    coalesce(br.buffer_minutes, s.buffer_minutes, 0)
  into v_shop, v_slot, v_buffer
  from public.barbers br
  left join public.barbershops s on s.id = br.shop_id
  where br.id = barber;

  if v_slot is null or v_slot <= 0 then
    v_slot := 30;
  end if;

  step := make_interval(mins => v_slot);
  weekday0 := extract(dow from day)::int;

  for w in
    (
      select start_time, end_time
      from public.barber_working_hours
      where barber_id = barber
        and enabled = true
        and weekday = weekday0

      union all

      select s.start_time, s.end_time
      from public.shop_working_hours s
      where v_shop is not null
        and s.shop_id = v_shop
        and s.enabled = true
        and s.weekday = weekday0
        and not exists (
          select 1
          from public.barber_working_hours wh
          where wh.barber_id = barber
            and wh.enabled = true
            and wh.weekday = weekday0
        )
    )
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

commit;

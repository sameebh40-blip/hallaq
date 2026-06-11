begin;

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


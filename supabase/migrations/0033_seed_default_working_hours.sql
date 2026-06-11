begin;

insert into public.barber_working_hours (barber_id, weekday, start_time, end_time, enabled)
select b.id, d.weekday, '10:00'::time, '22:00'::time, true
from public.barbers b
cross join (select generate_series(0,6) as weekday) d
where not exists (
  select 1
  from public.barber_working_hours wh
  where wh.barber_id = b.id
);

commit;


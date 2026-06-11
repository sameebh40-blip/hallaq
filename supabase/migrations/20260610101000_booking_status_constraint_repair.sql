begin;

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'bookings_status_check'
      and conrelid = 'public.bookings'::regclass
  ) then
    alter table public.bookings drop constraint bookings_status_check;
  end if;

  alter table public.bookings
    add constraint bookings_status_check
    check (status in ('pending','confirmed','in_progress','rescheduled','no_show','cancelled','completed')) not valid;

  alter table public.bookings
    validate constraint bookings_status_check;
end $$;

commit;

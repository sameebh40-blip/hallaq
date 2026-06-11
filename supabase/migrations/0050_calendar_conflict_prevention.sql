begin;

create extension if not exists btree_gist;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'barber_time_off_ends_after_starts'
      and conrelid = 'public.barber_time_off'::regclass
  ) then
    alter table public.barber_time_off
    add constraint barber_time_off_ends_after_starts
    check (ends_at > starts_at);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'barber_time_off_no_overlap'
      and conrelid = 'public.barber_time_off'::regclass
  ) then
    alter table public.barber_time_off
    add constraint barber_time_off_no_overlap
    exclude using gist (
      barber_id with =,
      tstzrange(starts_at, ends_at, '[)') with &&
    );
  end if;
end $$;

create or replace function public.prevent_time_off_overlaps_bookings()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  if exists (
    select 1
    from public.bookings b
    where b.barber_id = new.barber_id
      and b.status in ('pending','confirmed')
      and tstzrange(b.start_at, b.end_at, '[)') && tstzrange(new.starts_at, new.ends_at, '[)')
  ) then
    raise exception 'Time off overlaps existing booking';
  end if;
  return new;
end;
$$;

drop trigger if exists barber_time_off_prevent_overlap_bookings on public.barber_time_off;
create trigger barber_time_off_prevent_overlap_bookings
before insert or update on public.barber_time_off
for each row execute function public.prevent_time_off_overlaps_bookings();

commit;

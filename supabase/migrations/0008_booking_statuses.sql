alter table public.bookings drop constraint if exists bookings_status_check;

update public.bookings set status = 'confirmed' where status = 'accepted';
update public.bookings set status = 'cancelled' where status = 'rejected';

alter table public.bookings alter column status set default 'pending';
alter table public.bookings
add constraint bookings_status_check
check (status in ('pending','confirmed','cancelled','completed'));


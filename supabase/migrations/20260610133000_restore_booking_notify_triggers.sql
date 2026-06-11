begin;

drop trigger if exists bookings_notify_created on public.bookings;
create trigger bookings_notify_created
after insert on public.bookings
for each row execute function public.on_booking_created_notify();

drop trigger if exists bookings_notify_updated on public.bookings;
create trigger bookings_notify_updated
after update on public.bookings
for each row execute function public.on_booking_updated_notify();

commit;

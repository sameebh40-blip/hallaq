begin;

drop trigger if exists bookings_notify_insert on public.bookings;
drop trigger if exists bookings_notify_status on public.bookings;

drop function if exists public.on_booking_inserted();
drop function if exists public.on_booking_status_changed();

commit;


begin;

drop policy if exists "bookings_insert_customer" on public.bookings;
create policy "bookings_insert_customer"
on public.bookings
for insert
to authenticated
with check (customer_profile_id = auth.uid());

drop policy if exists "bookings_read_participants" on public.bookings;
create policy "bookings_read_participants"
on public.bookings
for select
to authenticated
using (public.is_admin() or public.is_booking_participant(id));

commit;


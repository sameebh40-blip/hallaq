begin;

drop policy if exists "bookings_update_participants" on public.bookings;

create policy "bookings_update_staff"
on public.bookings
for update
to authenticated
using (
  exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid())
  or exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid())
  or public.is_admin()
)
with check (
  exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid())
  or exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid())
  or public.is_admin()
);

commit;


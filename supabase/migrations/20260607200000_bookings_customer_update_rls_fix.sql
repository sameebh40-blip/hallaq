begin;

drop policy if exists "bookings_update_participants" on public.bookings;

create policy "bookings_update_staff_participants"
on public.bookings
for update
to authenticated
using (
  public.is_admin()
  or exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid())
  or exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid())
  or (branch_id is not null and public.is_branch_staff(branch_id))
)
with check (
  public.is_admin()
  or exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid())
  or exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid())
  or (branch_id is not null and public.is_branch_staff(branch_id))
);

drop policy if exists "bookings_update_customer_limited" on public.bookings;

create policy "bookings_update_customer_limited"
on public.bookings
for update
to authenticated
using (customer_profile_id = auth.uid())
with check (
  customer_profile_id = auth.uid()
  and (
    status = 'cancelled'
    or (rescheduled_by_profile_id = auth.uid() and rescheduled_at is not null)
  )
);

commit;


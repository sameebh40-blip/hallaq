begin;

drop policy if exists "offers_read_active" on public.offers;
create policy "offers_read_active"
on public.offers
for select
to anon, authenticated
using (active = true);

drop policy if exists "offers_write_owner" on public.offers;
create policy "offers_write_owner"
on public.offers
for insert
to authenticated
with check (
  (shop_id is not null and public.is_shop_owner(shop_id))
  or (barber_id is not null and public.is_barber_owner(barber_id))
  or public.is_admin()
);

drop policy if exists "offers_update_owner" on public.offers;
create policy "offers_update_owner"
on public.offers
for update
to authenticated
using (
  (shop_id is not null and public.is_shop_owner(shop_id))
  or (barber_id is not null and public.is_barber_owner(barber_id))
  or public.is_admin()
)
with check (
  (shop_id is not null and public.is_shop_owner(shop_id))
  or (barber_id is not null and public.is_barber_owner(barber_id))
  or public.is_admin()
);

commit;


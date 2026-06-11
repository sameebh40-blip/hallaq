create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  );
$$;

create or replace function public.is_shop_owner(shop uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.barbershops s
    where s.id = shop and s.owner_profile_id = auth.uid()
  );
$$;

create or replace function public.is_barber_owner(barber uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.barbers b
    where b.id = barber and b.profile_id = auth.uid()
  );
$$;

create or replace function public.is_booking_participant(booking uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.bookings bk
    left join public.barbers b on b.id = bk.barber_id
    left join public.barbershops s on s.id = bk.shop_id
    where bk.id = booking
      and (
        bk.customer_profile_id = auth.uid()
        or (b.profile_id = auth.uid())
        or (s.owner_profile_id = auth.uid())
      )
  );
$$;

drop policy if exists "bookings_update_customer_cancel" on public.bookings;
create policy "bookings_update_customer_cancel"
on public.bookings
for update
to authenticated
using (customer_profile_id = auth.uid())
with check (customer_profile_id = auth.uid() and status = 'cancelled');

drop policy if exists "bookings_update_provider" on public.bookings;
create policy "bookings_update_provider"
on public.bookings
for update
to authenticated
using (
  exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid())
  or exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid())
)
with check (
  exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid())
  or exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid())
);

drop policy if exists "categories_public_read" on public.categories;
create policy "categories_public_read"
on public.categories
for select
to anon, authenticated
using (true);

drop policy if exists "categories_admin_write" on public.categories;
create policy "categories_admin_write"
on public.categories
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "advertisements_public_read_active" on public.advertisements;
create policy "advertisements_public_read_active"
on public.advertisements
for select
to anon, authenticated
using (active = true);

drop policy if exists "advertisements_admin_write" on public.advertisements;
create policy "advertisements_admin_write"
on public.advertisements
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "featured_listings_public_read" on public.featured_listings;
create policy "featured_listings_public_read"
on public.featured_listings
for select
to anon, authenticated
using (true);

drop policy if exists "featured_listings_admin_write" on public.featured_listings;
create policy "featured_listings_admin_write"
on public.featured_listings
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "reports_insert_authenticated" on public.reports;
create policy "reports_insert_authenticated"
on public.reports
for insert
to authenticated
with check (reporter_profile_id = auth.uid());

drop policy if exists "reports_admin_read" on public.reports;
create policy "reports_admin_read"
on public.reports
for select
to authenticated
using (public.is_admin());

drop policy if exists "reports_admin_update" on public.reports;
create policy "reports_admin_update"
on public.reports
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "offers_delete_owner" on public.offers;
create policy "offers_delete_owner"
on public.offers
for delete
to authenticated
using (
  (shop_id is not null and public.is_shop_owner(shop_id))
  or (barber_id is not null and public.is_barber_owner(barber_id))
);

drop policy if exists "offers_admin_all" on public.offers;
create policy "offers_admin_all"
on public.offers
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "haircut_history_delete_own" on public.haircut_history;
create policy "haircut_history_delete_own"
on public.haircut_history
for delete
to authenticated
using (profile_id = auth.uid());

drop policy if exists "reviews_admin_all" on public.reviews;
create policy "reviews_admin_all"
on public.reviews
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "barbers_admin_all" on public.barbers;
create policy "barbers_admin_all"
on public.barbers
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "shops_admin_all" on public.barbershops;
create policy "shops_admin_all"
on public.barbershops
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "bookings_admin_all" on public.bookings;
create policy "bookings_admin_all"
on public.bookings
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "reels_admin_all" on public.reels;
create policy "reels_admin_all"
on public.reels
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "notifications_admin_all" on public.notifications;
create policy "notifications_admin_all"
on public.notifications
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());


begin;

drop policy if exists "bookings_update_shop_owner" on public.bookings;
create policy "bookings_update_shop_owner"
on public.bookings
for update
to authenticated
using (exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid()))
with check (exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid()));

drop policy if exists "bookings_update_barber_owner" on public.bookings;
create policy "bookings_update_barber_owner"
on public.bookings
for update
to authenticated
using (exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid()))
with check (exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid()));

drop policy if exists "bookings_update_admin" on public.bookings;
create policy "bookings_update_admin"
on public.bookings
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "reels_write_shop_owner" on public.reels;
create policy "reels_write_shop_owner"
on public.reels
for insert
to authenticated
with check (
  shop_id is not null
  and exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid())
);

drop policy if exists "reels_update_shop_owner" on public.reels;
create policy "reels_update_shop_owner"
on public.reels
for update
to authenticated
using (
  shop_id is not null
  and exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid())
)
with check (
  shop_id is not null
  and exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid())
);

do $$
begin
  if to_regclass('storage.objects') is not null then
drop policy if exists "storage_admin_all" on storage.objects;
create policy "storage_admin_all"
on storage.objects
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "storage_shop_images_owner_insert" on storage.objects;
create policy "storage_shop_images_owner_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'shop-images'
  and split_part(name, '/', 1) = 'shops'
  and public.is_shop_owner(split_part(name, '/', 2)::uuid)
);

drop policy if exists "storage_shop_images_owner_update" on storage.objects;
create policy "storage_shop_images_owner_update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'shop-images'
  and split_part(name, '/', 1) = 'shops'
  and public.is_shop_owner(split_part(name, '/', 2)::uuid)
)
with check (
  bucket_id = 'shop-images'
  and split_part(name, '/', 1) = 'shops'
  and public.is_shop_owner(split_part(name, '/', 2)::uuid)
);

drop policy if exists "storage_shop_images_owner_delete" on storage.objects;
create policy "storage_shop_images_owner_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'shop-images'
  and split_part(name, '/', 1) = 'shops'
  and public.is_shop_owner(split_part(name, '/', 2)::uuid)
);

drop policy if exists "storage_post_media_owner_insert" on storage.objects;
create policy "storage_post_media_owner_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'post-media'
  and (
    (
      split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner(split_part(name, '/', 2)::uuid)
    )
    or
    (
      split_part(name, '/', 1) = 'barbers'
      and public.is_barber_owner(split_part(name, '/', 2)::uuid)
    )
  )
);

drop policy if exists "storage_post_media_owner_update" on storage.objects;
create policy "storage_post_media_owner_update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'post-media'
  and (
    (
      split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner(split_part(name, '/', 2)::uuid)
    )
    or
    (
      split_part(name, '/', 1) = 'barbers'
      and public.is_barber_owner(split_part(name, '/', 2)::uuid)
    )
  )
)
with check (
  bucket_id = 'post-media'
  and (
    (
      split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner(split_part(name, '/', 2)::uuid)
    )
    or
    (
      split_part(name, '/', 1) = 'barbers'
      and public.is_barber_owner(split_part(name, '/', 2)::uuid)
    )
  )
);

drop policy if exists "storage_post_media_owner_delete" on storage.objects;
create policy "storage_post_media_owner_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'post-media'
  and (
    (
      split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner(split_part(name, '/', 2)::uuid)
    )
    or
    (
      split_part(name, '/', 1) = 'barbers'
      and public.is_barber_owner(split_part(name, '/', 2)::uuid)
    )
  )
);

drop policy if exists "storage_barber_images_owner_insert" on storage.objects;
create policy "storage_barber_images_owner_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'barber-images'
  and split_part(name, '/', 1) = 'barbers'
  and (
    public.is_barber_owner(split_part(name, '/', 2)::uuid)
    or exists (
      select 1
      from public.barbers b
      join public.barbershops s on s.id = b.shop_id
      where b.id = split_part(name, '/', 2)::uuid and s.owner_profile_id = auth.uid()
    )
  )
);

drop policy if exists "storage_barber_images_owner_update" on storage.objects;
create policy "storage_barber_images_owner_update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'barber-images'
  and split_part(name, '/', 1) = 'barbers'
  and (
    public.is_barber_owner(split_part(name, '/', 2)::uuid)
    or exists (
      select 1
      from public.barbers b
      join public.barbershops s on s.id = b.shop_id
      where b.id = split_part(name, '/', 2)::uuid and s.owner_profile_id = auth.uid()
    )
  )
)
with check (
  bucket_id = 'barber-images'
  and split_part(name, '/', 1) = 'barbers'
  and (
    public.is_barber_owner(split_part(name, '/', 2)::uuid)
    or exists (
      select 1
      from public.barbers b
      join public.barbershops s on s.id = b.shop_id
      where b.id = split_part(name, '/', 2)::uuid and s.owner_profile_id = auth.uid()
    )
  )
);

drop policy if exists "storage_barber_images_owner_delete" on storage.objects;
create policy "storage_barber_images_owner_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'barber-images'
  and split_part(name, '/', 1) = 'barbers'
  and (
    public.is_barber_owner(split_part(name, '/', 2)::uuid)
    or exists (
      select 1
      from public.barbers b
      join public.barbershops s on s.id = b.shop_id
      where b.id = split_part(name, '/', 2)::uuid and s.owner_profile_id = auth.uid()
    )
  )
);

drop policy if exists "storage_review_images_owner_insert" on storage.objects;
create policy "storage_review_images_owner_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'review-images'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists "storage_review_images_owner_update" on storage.objects;
create policy "storage_review_images_owner_update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'review-images'
  and split_part(name, '/', 1) = auth.uid()::text
)
with check (
  bucket_id = 'review-images'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists "storage_review_images_owner_delete" on storage.objects;
create policy "storage_review_images_owner_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'review-images'
  and split_part(name, '/', 1) = auth.uid()::text
);
  end if;
end;
$$;

commit;

begin;

do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values
      ('avatars', 'avatars', true),
      ('shop-images', 'shop-images', true),
      ('barber-images', 'barber-images', true),
      ('service-images', 'service-images', true),
      ('portfolio', 'portfolio', true),
      ('reels', 'reels', true),
      ('reels-media', 'reels-media', true),
      ('product-images', 'product-images', true),
      ('offer-images', 'offer-images', true),
      ('awards', 'awards', true)
    on conflict (id) do update
      set public = excluded.public;
  end if;

  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_public_read" on storage.objects;
    create policy "storage_public_read"
    on storage.objects
    for select
    to anon, authenticated
    using (
      bucket_id in (
        'avatars',
        'shop-images',
        'barber-images',
        'service-images',
        'portfolio',
        'reels',
        'reels-media',
        'product-images',
        'offer-images',
        'awards',
        'before-after',
        'review-photos',
        'haircut-history',
        'post-media',
        'review-images',
        'products',
        'ai-style'
      )
    );
  end if;
end $$;

alter table public.offers
  add column if not exists banner_thumbnail_url text,
  add column if not exists banner_thumbnail_path text;

alter table public.award_categories
  add column if not exists icon_url text,
  add column if not exists icon_path text,
  add column if not exists icon_thumbnail_url text,
  add column if not exists icon_thumbnail_path text;

alter table public.product_images
  add column if not exists thumbnail_url text,
  add column if not exists thumbnail_path text;

alter table public.product_variant_images
  add column if not exists thumbnail_url text,
  add column if not exists thumbnail_path text;

alter table public.service_images
  add column if not exists thumbnail_url text,
  add column if not exists thumbnail_path text;

alter table public.service_template_images
  add column if not exists thumbnail_url text,
  add column if not exists thumbnail_path text;

do $$
begin
  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_offer_images_barber_owner_insert" on storage.objects;
    create policy "storage_offer_images_barber_owner_insert"
    on storage.objects
    for insert
    to authenticated
    with check (
      bucket_id = 'offer-images'
      and split_part(name, '/', 1) = 'barbers'
      and public.is_barber_owner(split_part(name, '/', 2)::uuid)
    );

    drop policy if exists "storage_offer_images_barber_owner_update" on storage.objects;
    create policy "storage_offer_images_barber_owner_update"
    on storage.objects
    for update
    to authenticated
    using (
      bucket_id = 'offer-images'
      and split_part(name, '/', 1) = 'barbers'
      and public.is_barber_owner(split_part(name, '/', 2)::uuid)
    )
    with check (
      bucket_id = 'offer-images'
      and split_part(name, '/', 1) = 'barbers'
      and public.is_barber_owner(split_part(name, '/', 2)::uuid)
    );

    drop policy if exists "storage_offer_images_barber_owner_delete" on storage.objects;
    create policy "storage_offer_images_barber_owner_delete"
    on storage.objects
    for delete
    to authenticated
    using (
      bucket_id = 'offer-images'
      and split_part(name, '/', 1) = 'barbers'
      and public.is_barber_owner(split_part(name, '/', 2)::uuid)
    );

    drop policy if exists "storage_product_images_owner_insert" on storage.objects;
    create policy "storage_product_images_owner_insert"
    on storage.objects
    for insert
    to authenticated
    with check (
      bucket_id = 'product-images'
      and split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner(split_part(name, '/', 2)::uuid)
    );

    drop policy if exists "storage_product_images_owner_update" on storage.objects;
    create policy "storage_product_images_owner_update"
    on storage.objects
    for update
    to authenticated
    using (
      bucket_id = 'product-images'
      and split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner(split_part(name, '/', 2)::uuid)
    )
    with check (
      bucket_id = 'product-images'
      and split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner(split_part(name, '/', 2)::uuid)
    );

    drop policy if exists "storage_product_images_owner_delete" on storage.objects;
    create policy "storage_product_images_owner_delete"
    on storage.objects
    for delete
    to authenticated
    using (
      bucket_id = 'product-images'
      and split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner(split_part(name, '/', 2)::uuid)
    );

    drop policy if exists "storage_product_images_admin_all" on storage.objects;
    create policy "storage_product_images_admin_all"
    on storage.objects
    for all
    to authenticated
    using (bucket_id = 'product-images' and public.is_admin())
    with check (bucket_id = 'product-images' and public.is_admin());
  end if;
end $$;

commit;

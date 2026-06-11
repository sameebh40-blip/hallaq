begin;

insert into storage.buckets (id, name, public)
values
  ('shop-images', 'shop-images', true),
  ('product-images', 'product-images', true),
  ('service-images', 'service-images', true),
  ('reels', 'reels', true),
  ('portfolio', 'portfolio', true)
on conflict (id) do update set public = excluded.public;

do $$
begin
  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_public_read_shop_dashboard" on storage.objects;
    create policy "storage_public_read_shop_dashboard"
    on storage.objects
    for select
    to anon, authenticated
    using (bucket_id in ('shop-images','product-images','service-images','reels','portfolio'));

    drop policy if exists "storage_shop_images_shop_owner_write_0077" on storage.objects;
    create policy "storage_shop_images_shop_owner_write_0077"
    on storage.objects
    for all
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

    drop policy if exists "storage_product_images_shop_owner_write_0077" on storage.objects;
    create policy "storage_product_images_shop_owner_write_0077"
    on storage.objects
    for all
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

    drop policy if exists "storage_service_images_shop_owner_write_0077" on storage.objects;
    create policy "storage_service_images_shop_owner_write_0077"
    on storage.objects
    for all
    to authenticated
    using (
      bucket_id = 'service-images'
      and split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner(split_part(name, '/', 2)::uuid)
    )
    with check (
      bucket_id = 'service-images'
      and split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner(split_part(name, '/', 2)::uuid)
    );

    drop policy if exists "storage_portfolio_shop_owner_write_0077" on storage.objects;
    create policy "storage_portfolio_shop_owner_write_0077"
    on storage.objects
    for all
    to authenticated
    using (
      bucket_id = 'portfolio'
      and split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner(split_part(name, '/', 2)::uuid)
    )
    with check (
      bucket_id = 'portfolio'
      and split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner(split_part(name, '/', 2)::uuid)
    );

    drop policy if exists "storage_reels_shop_owner_write_0077" on storage.objects;
    create policy "storage_reels_shop_owner_write_0077"
    on storage.objects
    for all
    to authenticated
    using (
      bucket_id = 'reels'
      and (
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner(split_part(name, '/', 2)::uuid)
        )
        or
        (
          split_part(name, '/', 1) = 'barbers'
          and exists (
            select 1
            from public.barbers b
            join public.barbershops s on s.id = b.shop_id
            where b.id = split_part(name, '/', 2)::uuid
              and s.owner_profile_id = auth.uid()
          )
        )
      )
    )
    with check (
      bucket_id = 'reels'
      and (
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner(split_part(name, '/', 2)::uuid)
        )
        or
        (
          split_part(name, '/', 1) = 'barbers'
          and exists (
            select 1
            from public.barbers b
            join public.barbershops s on s.id = b.shop_id
            where b.id = split_part(name, '/', 2)::uuid
              and s.owner_profile_id = auth.uid()
          )
        )
      )
    );
  end if;
end;
$$;

commit;


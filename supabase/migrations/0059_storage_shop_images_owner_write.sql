begin;

do $$
begin
  if to_regclass('storage.objects') is not null then
    begin
      execute 'alter table storage.objects enable row level security';
    exception
      when insufficient_privilege then
        null;
    end;

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
  end if;
end;
$$;

commit;

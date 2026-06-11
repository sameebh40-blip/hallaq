begin;

do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values ('brand-assets', 'brand-assets', true)
    on conflict (id) do update set public = excluded.public;
  end if;

  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_brand_assets_public_read" on storage.objects;
    create policy "storage_brand_assets_public_read"
    on storage.objects
    for select
    to anon, authenticated
    using (bucket_id = 'brand-assets');

    drop policy if exists "storage_brand_assets_admin_insert" on storage.objects;
    create policy "storage_brand_assets_admin_insert"
    on storage.objects
    for insert
    to authenticated
    with check (bucket_id = 'brand-assets' and public.is_admin());

    drop policy if exists "storage_brand_assets_admin_update" on storage.objects;
    create policy "storage_brand_assets_admin_update"
    on storage.objects
    for update
    to authenticated
    using (bucket_id = 'brand-assets' and public.is_admin())
    with check (bucket_id = 'brand-assets' and public.is_admin());

    drop policy if exists "storage_brand_assets_admin_delete" on storage.objects;
    create policy "storage_brand_assets_admin_delete"
    on storage.objects
    for delete
    to authenticated
    using (bucket_id = 'brand-assets' and public.is_admin());
  end if;
end
$$;

commit;


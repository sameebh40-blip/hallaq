begin;

do $$
begin
  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_post_media_admin_delete" on storage.objects;
    create policy "storage_post_media_admin_delete"
    on storage.objects
    for delete
    to authenticated
    using (bucket_id = 'post-media' and public.is_admin());

    drop policy if exists "storage_shop_images_admin_delete" on storage.objects;
    create policy "storage_shop_images_admin_delete"
    on storage.objects
    for delete
    to authenticated
    using (bucket_id = 'shop-images' and public.is_admin());

    drop policy if exists "storage_barber_images_admin_delete" on storage.objects;
    create policy "storage_barber_images_admin_delete"
    on storage.objects
    for delete
    to authenticated
    using (bucket_id = 'barber-images' and public.is_admin());

    drop policy if exists "storage_review_images_admin_delete" on storage.objects;
    create policy "storage_review_images_admin_delete"
    on storage.objects
    for delete
    to authenticated
    using (bucket_id = 'review-images' and public.is_admin());
  end if;
end;
$$;

commit;

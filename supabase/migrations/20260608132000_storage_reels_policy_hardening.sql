begin;

do $$
begin
  if to_regclass('storage.buckets') is not null then
    update storage.buckets
    set public = false
    where id in ('reels','reels-media','post-media');
  end if;

  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_reels_public_read" on storage.objects;

    drop policy if exists "storage_public_read_shop_dashboard" on storage.objects;
    create policy "storage_public_read_shop_dashboard"
    on storage.objects
    for select
    to anon, authenticated
    using (bucket_id in ('shop-images','product-images','service-images','portfolio'));

    drop policy if exists "storage_public_read" on storage.objects;
    create policy "storage_public_read"
    on storage.objects
    for select
    to anon, authenticated
    using (bucket_id in ('avatars','portfolio','review-photos','haircut-history','service-images','shop-images','barber-images','review-images','products','product-images','ai-style','offer-images','before-after','awards'));

    drop policy if exists "storage_read_reels_approved" on storage.objects;
    create policy "storage_read_reels_approved"
    on storage.objects
    for select
    to anon, authenticated
    using (
      bucket_id in ('reels','reels-media','post-media')
      and exists (
        select 1
        from public.reels r
        where r.status = 'approved'
          and r.deleted_at is null
          and (
            r.media_path = name
            or r.thumbnail_path = name
            or r.media_url = name
            or r.thumbnail_url = name
            or r.image_url = name
            or r.video_url = name
            or r.media_url like '%' || name
            or r.thumbnail_url like '%' || name
            or r.image_url like '%' || name
            or r.video_url like '%' || name
          )
      )
    );

    drop policy if exists "storage_read_reels_owner_preview" on storage.objects;
    create policy "storage_read_reels_owner_preview"
    on storage.objects
    for select
    to authenticated
    using (
      bucket_id in ('reels','reels-media','post-media')
      and exists (
        select 1
        from public.reels r
        left join public.barbers b on b.id = r.barber_id
        left join public.barbershops s on s.id = r.shop_id
        where (
          r.media_path = name
          or r.thumbnail_path = name
          or r.media_url = name
          or r.thumbnail_url = name
          or r.image_url = name
          or r.video_url = name
          or r.media_url like '%' || name
          or r.thumbnail_url like '%' || name
          or r.image_url like '%' || name
          or r.video_url like '%' || name
        )
        and (
          public.is_admin()
          or (r.barber_id is not null and public.is_barber_owner(r.barber_id))
          or (
            r.barber_id is not null
            and b.shop_id is not null
            and public.is_shop_owner(b.shop_id)
          )
          or (r.shop_id is not null and public.is_shop_owner(r.shop_id))
        )
      )
    );
  end if;
end;
$$;

commit;

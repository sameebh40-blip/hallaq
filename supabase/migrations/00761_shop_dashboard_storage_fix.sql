begin;

do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values
      ('shop-images', 'shop-images', true),
      ('product-images', 'product-images', true),
      ('service-images', 'service-images', true),
      ('reels', 'reels', true),
      ('portfolio', 'portfolio', true)
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

commit;

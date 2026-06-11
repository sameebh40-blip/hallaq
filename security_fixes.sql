begin;

do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values
      ('avatars', 'avatars', true),
      ('profile-covers', 'profile-covers', true),
      ('barber-images', 'barber-images', true),
      ('shop-images', 'shop-images', true),
      ('portfolio', 'portfolio', true),
      ('reels', 'reels', true),
      ('reels-media', 'reels-media', true),
      ('post-media', 'post-media', true),
      ('review-images', 'review-images', true),
      ('review-photos', 'review-photos', true),
      ('service-images', 'service-images', true),
      ('products', 'products', true),
      ('product-images', 'product-images', true),
      ('offer-images', 'offer-images', true),
      ('before-after', 'before-after', true),
      ('haircut-history', 'haircut-history', true),
      ('ai-style', 'ai-style', true),
      ('awards', 'awards', true),
      ('style-library', 'style-library', true),
      ('claim-proofs', 'claim-proofs', false),
      ('backups', 'backups', false)
    on conflict (id) do update set public = excluded.public;
  end if;
end $$;

do $$
begin
  if to_regclass('storage.objects') is not null then
    begin
      execute 'alter table storage.objects enable row level security';
    exception when others then
      null;
    end;

    drop policy if exists "storage_public_read" on storage.objects;
    create policy "storage_public_read"
    on storage.objects
    for select
    to anon, authenticated
    using (
      bucket_id in (
        'avatars',
        'profile-covers',
        'barber-images',
        'shop-images',
        'portfolio',
        'reels',
        'reels-media',
        'post-media',
        'review-images',
        'review-photos',
        'service-images',
        'products',
        'product-images',
        'offer-images',
        'before-after',
        'haircut-history',
        'ai-style',
        'awards',
        'style-library'
      )
    );
  end if;
end $$;

commit;


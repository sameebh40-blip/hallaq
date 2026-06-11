do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values
      ('product-images', 'product-images', true)
    on conflict (id) do nothing;
  end if;

  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_public_read" on storage.objects;
    create policy "storage_public_read"
    on storage.objects
    for select
    to anon, authenticated
    using (bucket_id in ('avatars','portfolio','reels','reels-media','review-photos','haircut-history','service-images','shop-images','barber-images','post-media','review-images','products','product-images','ai-style','offer-images','before-after','awards'));
  end if;
end $$;


do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values
      ('avatars', 'avatars', true),
      ('profile-covers', 'profile-covers', true),
      ('reels', 'reels', true),
      ('barber-images', 'barber-images', true),
      ('shop-images', 'shop-images', true)
    on conflict (id) do update
      set public = excluded.public;
  end if;

  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_profile_covers_public_read" on storage.objects;
    create policy "storage_profile_covers_public_read"
    on storage.objects
    for select
    to anon, authenticated
    using (bucket_id = 'profile-covers');

    drop policy if exists "storage_profile_covers_write_own" on storage.objects;
    create policy "storage_profile_covers_write_own"
    on storage.objects
    for insert
    to authenticated
    with check (
      bucket_id = 'profile-covers'
      and split_part(name, '/', 1) = auth.uid()::text
    );

    drop policy if exists "storage_profile_covers_update_own" on storage.objects;
    create policy "storage_profile_covers_update_own"
    on storage.objects
    for update
    to authenticated
    using (
      bucket_id = 'profile-covers'
      and split_part(name, '/', 1) = auth.uid()::text
    )
    with check (
      bucket_id = 'profile-covers'
      and split_part(name, '/', 1) = auth.uid()::text
    );

    drop policy if exists "storage_profile_covers_delete_own" on storage.objects;
    create policy "storage_profile_covers_delete_own"
    on storage.objects
    for delete
    to authenticated
    using (
      bucket_id = 'profile-covers'
      and split_part(name, '/', 1) = auth.uid()::text
    );
  end if;
end $$;

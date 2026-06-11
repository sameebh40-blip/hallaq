begin;

do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values ('review-photos', 'review-photos', true)
    on conflict (id) do update set public = excluded.public;
  end if;

  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_review_photos_owner_insert" on storage.objects;
    create policy "storage_review_photos_owner_insert"
    on storage.objects
    for insert
    to authenticated
    with check (
      bucket_id = 'review-photos'
      and split_part(name, '/', 1) = auth.uid()::text
    );

    drop policy if exists "storage_review_photos_owner_update" on storage.objects;
    create policy "storage_review_photos_owner_update"
    on storage.objects
    for update
    to authenticated
    using (
      bucket_id = 'review-photos'
      and split_part(name, '/', 1) = auth.uid()::text
    )
    with check (
      bucket_id = 'review-photos'
      and split_part(name, '/', 1) = auth.uid()::text
    );

    drop policy if exists "storage_review_photos_owner_delete" on storage.objects;
    create policy "storage_review_photos_owner_delete"
    on storage.objects
    for delete
    to authenticated
    using (
      bucket_id = 'review-photos'
      and split_part(name, '/', 1) = auth.uid()::text
    );
  end if;
end;
$$;

commit;

do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values
      ('avatars', 'avatars', true),
      ('portfolio', 'portfolio', true),
      ('reels-media', 'reels-media', true),
      ('review-photos', 'review-photos', true),
      ('haircut-history', 'haircut-history', true)
    on conflict (id) do nothing;
  end if;
end;
$$;

do $$
begin
  if to_regclass('storage.objects') is not null then
    begin
      if exists (
        select 1
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'storage'
          and c.relname = 'objects'
          and c.relrowsecurity is not true
      ) then
        execute 'alter table storage.objects enable row level security';
      end if;
    exception
      when insufficient_privilege then
        null;
    end;
  end if;
end;
$$;

do $$
begin
  if to_regclass('storage.objects') is not null then

drop policy if exists "storage_public_read" on storage.objects;
create policy "storage_public_read"
on storage.objects
for select
to anon, authenticated
using (bucket_id in ('avatars','portfolio','reels-media','review-photos','haircut-history'));

drop policy if exists "storage_avatars_write_own" on storage.objects;
create policy "storage_avatars_write_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists "storage_avatars_update_own" on storage.objects;
create policy "storage_avatars_update_own"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'avatars'
  and split_part(name, '/', 1) = auth.uid()::text
)
with check (
  bucket_id = 'avatars'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists "storage_avatars_delete_own" on storage.objects;
create policy "storage_avatars_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'avatars'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists "storage_review_photos_write_own" on storage.objects;
create policy "storage_review_photos_write_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'review-photos'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists "storage_review_photos_update_own" on storage.objects;
create policy "storage_review_photos_update_own"
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

drop policy if exists "storage_review_photos_delete_own" on storage.objects;
create policy "storage_review_photos_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'review-photos'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists "storage_haircut_history_write_own" on storage.objects;
create policy "storage_haircut_history_write_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'haircut-history'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists "storage_haircut_history_update_own" on storage.objects;
create policy "storage_haircut_history_update_own"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'haircut-history'
  and split_part(name, '/', 1) = auth.uid()::text
)
with check (
  bucket_id = 'haircut-history'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists "storage_haircut_history_delete_own" on storage.objects;
create policy "storage_haircut_history_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'haircut-history'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists "storage_portfolio_write_owner" on storage.objects;
create policy "storage_portfolio_write_owner"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'portfolio'
  and (
    (
      split_part(name, '/', 1) = 'barbers'
      and public.is_barber_owner((split_part(name, '/', 2))::uuid)
    )
    or
    (
      split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner((split_part(name, '/', 2))::uuid)
    )
    or public.is_admin()
  )
);

drop policy if exists "storage_portfolio_update_owner" on storage.objects;
create policy "storage_portfolio_update_owner"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'portfolio'
  and (
    (
      split_part(name, '/', 1) = 'barbers'
      and public.is_barber_owner((split_part(name, '/', 2))::uuid)
    )
    or
    (
      split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner((split_part(name, '/', 2))::uuid)
    )
    or public.is_admin()
  )
)
with check (
  bucket_id = 'portfolio'
  and (
    (
      split_part(name, '/', 1) = 'barbers'
      and public.is_barber_owner((split_part(name, '/', 2))::uuid)
    )
    or
    (
      split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner((split_part(name, '/', 2))::uuid)
    )
    or public.is_admin()
  )
);

drop policy if exists "storage_portfolio_delete_owner" on storage.objects;
create policy "storage_portfolio_delete_owner"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'portfolio'
  and (
    (
      split_part(name, '/', 1) = 'barbers'
      and public.is_barber_owner((split_part(name, '/', 2))::uuid)
    )
    or
    (
      split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner((split_part(name, '/', 2))::uuid)
    )
    or public.is_admin()
  )
);

drop policy if exists "storage_reels_write_owner" on storage.objects;
create policy "storage_reels_write_owner"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'reels-media'
  and split_part(name, '/', 1) = 'barbers'
  and public.is_barber_owner((split_part(name, '/', 2))::uuid)
);

drop policy if exists "storage_reels_update_owner" on storage.objects;
create policy "storage_reels_update_owner"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'reels-media'
  and split_part(name, '/', 1) = 'barbers'
  and public.is_barber_owner((split_part(name, '/', 2))::uuid)
)
with check (
  bucket_id = 'reels-media'
  and split_part(name, '/', 1) = 'barbers'
  and public.is_barber_owner((split_part(name, '/', 2))::uuid)
);

drop policy if exists "storage_reels_delete_owner" on storage.objects;
create policy "storage_reels_delete_owner"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'reels-media'
  and split_part(name, '/', 1) = 'barbers'
  and public.is_barber_owner((split_part(name, '/', 2))::uuid)
);
  end if;
end;
$$;

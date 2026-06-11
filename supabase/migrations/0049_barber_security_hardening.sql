begin;

do $$
begin
  if to_regclass('storage.buckets') is not null then
    update storage.buckets
    set public = false
    where id in ('reels');
  end if;

  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_read_reels_approved" on storage.objects;
    create policy "storage_read_reels_approved"
    on storage.objects
    for select
    to anon, authenticated
    using (
      bucket_id in ('reels','reels-media')
      and exists (
        select 1
        from public.reels r
        where r.status = 'approved'
          and r.deleted_at is null
          and (r.media_path = name or r.thumbnail_path = name or r.media_url = name or r.thumbnail_url = name or r.image_url = name or r.video_url = name)
      )
    );

    drop policy if exists "storage_read_reels_owner_preview" on storage.objects;
    create policy "storage_read_reels_owner_preview"
    on storage.objects
    for select
    to authenticated
    using (
      bucket_id in ('reels','reels-media')
      and exists (
        select 1
        from public.reels r
        left join public.barbers b on b.id = r.barber_id
        left join public.barbershops s on s.id = r.shop_id
        where (r.media_path = name or r.thumbnail_path = name or r.media_url = name or r.thumbnail_url = name or r.image_url = name or r.video_url = name)
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

    drop policy if exists "storage_reels_media_owner_insert" on storage.objects;
    create policy "storage_reels_media_owner_insert"
    on storage.objects
    for insert
    to authenticated
    with check (
      bucket_id = 'reels-media'
      and (
        (split_part(name, '/', 1) = 'shops' and public.is_shop_owner(split_part(name, '/', 2)::uuid))
        or (split_part(name, '/', 1) = 'barbers' and public.is_barber_owner(split_part(name, '/', 2)::uuid))
      )
    );

    drop policy if exists "storage_reels_media_owner_update" on storage.objects;
    create policy "storage_reels_media_owner_update"
    on storage.objects
    for update
    to authenticated
    using (
      bucket_id = 'reels-media'
      and (
        (split_part(name, '/', 1) = 'shops' and public.is_shop_owner(split_part(name, '/', 2)::uuid))
        or (split_part(name, '/', 1) = 'barbers' and public.is_barber_owner(split_part(name, '/', 2)::uuid))
      )
    )
    with check (
      bucket_id = 'reels-media'
      and (
        (split_part(name, '/', 1) = 'shops' and public.is_shop_owner(split_part(name, '/', 2)::uuid))
        or (split_part(name, '/', 1) = 'barbers' and public.is_barber_owner(split_part(name, '/', 2)::uuid))
      )
    );

    drop policy if exists "storage_reels_media_owner_delete" on storage.objects;
    create policy "storage_reels_media_owner_delete"
    on storage.objects
    for delete
    to authenticated
    using (
      bucket_id = 'reels-media'
      and (
        (split_part(name, '/', 1) = 'shops' and public.is_shop_owner(split_part(name, '/', 2)::uuid))
        or (split_part(name, '/', 1) = 'barbers' and public.is_barber_owner(split_part(name, '/', 2)::uuid))
      )
    );
  end if;
end;
$$;

drop policy if exists "services_write_independent_barber" on public.services;
drop policy if exists "services_write_barber_owner" on public.services;
create policy "services_write_barber_owner"
on public.services
for all
to authenticated
using (
  barber_id is not null
  and public.is_barber_owner(barber_id)
  and exists (
    select 1
    from public.barbers b
    where b.id = barber_id
      and (shop_id is null or shop_id = b.shop_id)
  )
)
with check (
  barber_id is not null
  and public.is_barber_owner(barber_id)
  and exists (
    select 1
    from public.barbers b
    where b.id = barber_id
      and (shop_id is null or shop_id = b.shop_id)
  )
);

drop policy if exists "reels_write_owner_basic" on public.reels;
drop policy if exists "reels_write_shop_owner" on public.reels;
drop policy if exists "reels_update_shop_owner" on public.reels;
drop policy if exists "reels_insert_owner" on public.reels;
drop policy if exists "reels_update_owner" on public.reels;
drop policy if exists "reels_delete_owner" on public.reels;

create policy "reels_insert_owner"
on public.reels
for insert
to authenticated
with check (
  public.is_admin()
  or (barber_id is not null and public.is_barber_owner(barber_id))
  or (
    barber_id is not null
    and exists (
      select 1
      from public.barbers b
      join public.barbershops s on s.id = b.shop_id
      where b.id = barber_id and s.owner_profile_id = auth.uid()
    )
  )
  or (shop_id is not null and public.is_shop_owner(shop_id))
);

create policy "reels_update_owner"
on public.reels
for update
to authenticated
using (
  public.is_admin()
  or (barber_id is not null and public.is_barber_owner(barber_id))
  or (
    barber_id is not null
    and exists (
      select 1
      from public.barbers b
      join public.barbershops s on s.id = b.shop_id
      where b.id = barber_id and s.owner_profile_id = auth.uid()
    )
  )
  or (shop_id is not null and public.is_shop_owner(shop_id))
)
with check (
  public.is_admin()
  or (barber_id is not null and public.is_barber_owner(barber_id))
  or (
    barber_id is not null
    and exists (
      select 1
      from public.barbers b
      join public.barbershops s on s.id = b.shop_id
      where b.id = barber_id and s.owner_profile_id = auth.uid()
    )
  )
  or (shop_id is not null and public.is_shop_owner(shop_id))
);

create policy "reels_delete_owner"
on public.reels
for delete
to authenticated
using (
  public.is_admin()
  or (barber_id is not null and public.is_barber_owner(barber_id))
  or (
    barber_id is not null
    and exists (
      select 1
      from public.barbers b
      join public.barbershops s on s.id = b.shop_id
      where b.id = barber_id and s.owner_profile_id = auth.uid()
    )
  )
  or (shop_id is not null and public.is_shop_owner(shop_id))
);

create or replace function public.guard_review_update_columns()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if (new.customer_profile_id, new.target_type, new.target_id, new.shop_id, new.barber_id, new.rating, new.comment, new.image_url, new.image_path, new.status, new.is_verified)
     is distinct from
     (old.customer_profile_id, old.target_type, old.target_id, old.shop_id, old.barber_id, old.rating, old.comment, old.image_url, old.image_path, old.status, old.is_verified)
  then
    raise exception 'Review fields are immutable';
  end if;

  return new;
end;
$$;

drop trigger if exists reviews_guard_update_columns on public.reviews;
create trigger reviews_guard_update_columns
before update on public.reviews
for each row execute function public.guard_review_update_columns();

commit;

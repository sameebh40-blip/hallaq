begin;

alter table public.profiles add column if not exists avatar_path text;
alter table public.profiles add column if not exists cover_path text;

alter table public.barbers add column if not exists avatar_path text;
alter table public.barbers add column if not exists cover_path text;

alter table public.barbershops add column if not exists logo_path text;
alter table public.barbershops add column if not exists cover_path text;

alter table public.reels add column if not exists media_path text;
alter table public.reels add column if not exists thumbnail_path text;

alter table public.reviews add column if not exists image_path text;

alter table public.portfolio_items add column if not exists media_path text;
alter table public.portfolio_items add column if not exists thumbnail_path text;

alter table public.portfolio_items
add column if not exists status text not null default 'pending'
check (status in ('pending','approved','rejected'));

alter table public.portfolio_items add column if not exists approved_by uuid references public.profiles (id);
alter table public.portfolio_items add column if not exists approved_at timestamptz;
alter table public.portfolio_items add column if not exists rejected_by uuid references public.profiles (id);
alter table public.portfolio_items add column if not exists rejected_at timestamptz;
alter table public.portfolio_items add column if not exists rejection_reason text;

update public.portfolio_items
set status = 'approved'
where status = 'pending';

drop policy if exists "portfolio_items_public_read" on public.portfolio_items;
drop policy if exists "portfolio_items_public_read_approved" on public.portfolio_items;
create policy "portfolio_items_public_read_approved"
on public.portfolio_items
for select
to anon, authenticated
using (status = 'approved');

drop policy if exists "portfolio_items_read_owner_or_admin" on public.portfolio_items;
create policy "portfolio_items_read_owner_or_admin"
on public.portfolio_items
for select
to authenticated
using (
  public.is_admin()
  or (owner_type = 'barber' and public.is_barber_owner(owner_id))
  or (owner_type = 'shop' and public.is_shop_owner(owner_id))
  or (
    owner_type = 'barber'
    and exists (
      select 1
      from public.barbers b
      join public.barbershops s on s.id = b.shop_id
      where b.id = owner_id
        and s.owner_profile_id = auth.uid()
    )
  )
);

do $$
begin
  if to_regclass('storage.buckets') is not null then
    update storage.buckets
    set public = false
    where id in ('avatars','shop-images','barber-images','portfolio','reels-media','review-images','review-photos');
  end if;

  if to_regclass('storage.objects') is not null then
    begin
      execute 'alter table storage.objects enable row level security';
    exception
      when insufficient_privilege then
        null;
    end;

    drop policy if exists "storage_public_read" on storage.objects;
    drop policy if exists "storage_reels_public_read" on storage.objects;
    drop policy if exists "storage_public_read_shop_barber_review" on storage.objects;

    drop policy if exists "storage_read_avatars_profiles" on storage.objects;
    create policy "storage_read_avatars_profiles"
    on storage.objects
    for select
    to anon, authenticated
    using (
      bucket_id = 'avatars'
      and exists (
        select 1
        from public.profiles p
        where p.avatar_path = name or p.cover_path = name
      )
    );

    drop policy if exists "storage_read_barber_images" on storage.objects;
    create policy "storage_read_barber_images"
    on storage.objects
    for select
    to anon, authenticated
    using (
      bucket_id = 'barber-images'
      and exists (
        select 1
        from public.barbers b
        where b.avatar_path = name or b.cover_path = name
      )
    );

    drop policy if exists "storage_read_shop_images" on storage.objects;
    create policy "storage_read_shop_images"
    on storage.objects
    for select
    to anon, authenticated
    using (
      bucket_id = 'shop-images'
      and exists (
        select 1
        from public.barbershops s
        where s.logo_path = name or s.cover_path = name
      )
    );

    drop policy if exists "storage_read_reviews_published" on storage.objects;
    create policy "storage_read_reviews_published"
    on storage.objects
    for select
    to anon, authenticated
    using (
      bucket_id in ('review-images','review-photos')
      and exists (
        select 1
        from public.reviews r
        where r.status = 'published'
          and r.image_path = name
      )
    );

    drop policy if exists "storage_read_portfolio_approved" on storage.objects;
    create policy "storage_read_portfolio_approved"
    on storage.objects
    for select
    to anon, authenticated
    using (
      bucket_id = 'portfolio'
      and exists (
        select 1
        from public.portfolio_items p
        where p.status = 'approved'
          and (p.media_path = name or p.thumbnail_path = name)
      )
    );

    drop policy if exists "storage_read_portfolio_owner_preview" on storage.objects;
    create policy "storage_read_portfolio_owner_preview"
    on storage.objects
    for select
    to authenticated
    using (
      bucket_id = 'portfolio'
      and (
        public.is_admin()
        or (
          split_part(name, '/', 1) = 'barbers'
          and (
            public.is_barber_owner((split_part(name, '/', 2))::uuid)
            or exists (
              select 1
              from public.barbers b
              join public.barbershops s on s.id = b.shop_id
              where b.id = (split_part(name, '/', 2))::uuid
                and s.owner_profile_id = auth.uid()
            )
          )
        )
        or (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner((split_part(name, '/', 2))::uuid)
        )
      )
    );

    drop policy if exists "storage_read_reels_approved" on storage.objects;
    create policy "storage_read_reels_approved"
    on storage.objects
    for select
    to anon, authenticated
    using (
      bucket_id = 'reels-media'
      and exists (
        select 1
        from public.reels r
        where r.status = 'approved'
          and (r.media_path = name or r.thumbnail_path = name)
      )
    );

    drop policy if exists "storage_read_reels_owner_preview" on storage.objects;
    create policy "storage_read_reels_owner_preview"
    on storage.objects
    for select
    to authenticated
    using (
      bucket_id = 'reels-media'
      and exists (
        select 1
        from public.reels r
        where (r.media_path = name or r.thumbnail_path = name)
          and (
            public.is_admin()
            or (r.barber_id is not null and exists (select 1 from public.barbers b where b.id = r.barber_id and b.profile_id = auth.uid()))
            or (r.shop_id is not null and exists (select 1 from public.barbershops s where s.id = r.shop_id and s.owner_profile_id = auth.uid()))
          )
      )
    );
  end if;
end;
$$;

commit;

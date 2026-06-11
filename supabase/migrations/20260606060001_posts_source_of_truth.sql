begin;

drop view if exists public.post_likes;
drop view if exists public.post_saves;
drop view if exists public.post_comments;
drop view if exists public.posts;

alter table if exists public.reels rename to posts;

alter table public.posts add column if not exists is_active boolean not null default true;
alter table public.posts alter column is_active set default true;

alter table public.posts add column if not exists views_count int not null default 0;
alter table public.posts alter column views_count set default 0;

update public.posts
set owner_type = coalesce(
  owner_type,
  case
    when barber_id is not null then 'barber'
    when shop_id is not null then 'shop'
    else 'admin'
  end
)
where owner_type is null or btrim(owner_type) = '';

alter table public.posts alter column owner_type set not null;

drop policy if exists "reels_public_read" on public.posts;
create policy "posts_public_read"
on public.posts
for select
to anon, authenticated
using (
  public.is_admin()
  or (deleted_at is null and is_active = true and status = 'approved')
  or (barber_id is not null and exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid()))
  or (shop_id is not null and exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid()))
);

drop policy if exists "reels_insert_owner" on public.posts;
drop policy if exists "reels_update_owner" on public.posts;
drop policy if exists "reels_delete_owner" on public.posts;

create policy "posts_insert_owner"
on public.posts
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

create policy "posts_update_owner"
on public.posts
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

create policy "posts_delete_owner"
on public.posts
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

create or replace view public.reels
with (security_invoker = true) as
select *
from public.posts;

create or replace view public.post_likes
with (security_invoker = true) as
select *
from public.reel_likes;

create or replace view public.post_saves
with (security_invoker = true) as
select *
from public.reel_saves;

create or replace view public.post_comments
with (security_invoker = true) as
select *
from public.reel_comments;

commit;

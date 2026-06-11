begin;

alter table public.profiles add column if not exists email text;
alter table public.profiles
add column if not exists status text not null default 'active'
check (status in ('active','suspended'));

update public.profiles p
set email = u.email
from auth.users u
where u.id = p.id and p.email is null;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.email,
    'customer'
  )
  on conflict (id) do update
  set email = excluded.email;
  return new;
end;
$$;

create or replace function public.handle_user_updated()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles set email = new.email where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
after update of email on auth.users
for each row execute function public.handle_user_updated();

alter table public.barbershops
add column if not exists status text not null default 'pending'
check (status in ('pending','approved','suspended'));

update public.barbershops set status = 'approved' where is_verified = true and status = 'pending';

create index if not exists barbershops_status_created_idx on public.barbershops (status, created_at desc);
create index if not exists barbershops_featured_status_idx on public.barbershops (is_featured, status, created_at desc);

alter table public.barbers
add column if not exists status text not null default 'active'
check (status in ('active','suspended'));

create index if not exists barbers_status_created_idx on public.barbers (status, created_at desc);
create index if not exists barbers_verified_status_idx on public.barbers (is_verified, status, created_at desc);

alter table public.services add column if not exists category text;

alter table public.reviews
add column if not exists status text not null default 'published'
check (status in ('published','hidden'));

drop policy if exists "shops_public_read" on public.barbershops;
create policy "shops_public_read"
on public.barbershops
for select
to anon, authenticated
using (
  status = 'approved'
  or public.is_admin()
  or owner_profile_id = auth.uid()
);

drop policy if exists "barbers_public_read" on public.barbers;
create policy "barbers_public_read"
on public.barbers
for select
to anon, authenticated
using (
  public.is_admin()
  or profile_id = auth.uid()
  or (shop_id is not null and exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid()))
  or (status = 'active' and is_verified = true)
);

drop policy if exists "reels_public_read" on public.reels;
create policy "reels_public_read"
on public.reels
for select
to anon, authenticated
using (
  status = 'approved'
  or public.is_admin()
  or (barber_id is not null and exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid()))
  or (shop_id is not null and exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid()))
);

drop policy if exists "reviews_public_read" on public.reviews;
create policy "reviews_public_read"
on public.reviews
for select
to anon, authenticated
using (status = 'published' or public.is_admin());

drop view if exists public.shops;
create or replace view public.shops with (security_invoker = true) as
select
  id,
  owner_profile_id as owner_id,
  name,
  logo_url,
  cover_url,
  description,
  area,
  address,
  lat as latitude,
  lng as longitude,
  phone,
  whatsapp,
  instagram,
  opening_hours,
  status,
  is_verified,
  is_featured,
  created_at
from public.barbershops;

drop view if exists public.appointments;
create or replace view public.appointments with (security_invoker = true) as
select
  id,
  customer_profile_id as customer_id,
  shop_id,
  barber_id,
  service_id,
  (start_at at time zone 'Asia/Bahrain')::date as appointment_date,
  (start_at at time zone 'Asia/Bahrain')::time as appointment_time,
  status,
  notes,
  created_at
from public.bookings;

drop view if exists public.posts;
create or replace view public.posts with (security_invoker = true) as
select
  r.id,
  r.shop_id,
  r.barber_id,
  coalesce(b.profile_id, s.owner_profile_id) as created_by,
  coalesce(r.media_url, r.video_url, r.image_url) as media_url,
  r.media_type,
  r.thumbnail_url,
  r.caption,
  r.location,
  r.status,
  r.is_featured,
  r.likes_count,
  r.comments_count,
  r.saves_count,
  r.created_at
from public.reels r
left join public.barbers b on b.id = r.barber_id
left join public.barbershops s on s.id = r.shop_id;

create or replace view public.post_likes with (security_invoker = true) as
select
  id,
  reel_id as post_id,
  profile_id as user_id,
  created_at
from public.reel_likes;

create or replace view public.post_saves with (security_invoker = true) as
select
  id,
  reel_id as post_id,
  profile_id as user_id,
  created_at
from public.reel_saves;

create or replace view public.barber_response_time_minutes as
with created as (
  select
    b.id as booking_id,
    b.barber_id,
    min(a.created_at) as created_at
  from public.bookings b
  join public.booking_audit_trail a on a.booking_id = b.id
  where a.action = 'created'
  group by b.id, b.barber_id
),
responded as (
  select
    b.id as booking_id,
    b.barber_id,
    min(a.created_at) as responded_at
  from public.bookings b
  join public.booking_audit_trail a on a.booking_id = b.id
  join public.barbers br on br.id = b.barber_id
  where a.action = 'status_changed'
    and a.new_status in ('confirmed','cancelled')
    and a.actor_profile_id = br.profile_id
  group by b.id, b.barber_id
)
select
  c.barber_id,
  avg(extract(epoch from (r.responded_at - c.created_at)) / 60.0)::numeric(10,2) as avg_minutes
from created c
join responded r on r.booking_id = c.booking_id
group by c.barber_id;

do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values
      ('shop-images', 'shop-images', true),
      ('barber-images', 'barber-images', true),
      ('post-media', 'post-media', true),
      ('review-images', 'review-images', true)
    on conflict (id) do nothing;
  end if;

  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_public_read" on storage.objects;
    create policy "storage_public_read"
    on storage.objects
    for select
    to anon, authenticated
    using (bucket_id in ('avatars','portfolio','reels-media','review-photos','haircut-history','shop-images','barber-images','post-media','review-images'));
  end if;
end;
$$;

commit;

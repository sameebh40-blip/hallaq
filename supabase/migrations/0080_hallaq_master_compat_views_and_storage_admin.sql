begin;

alter table public.profiles
  add column if not exists selected_area text,
  add column if not exists last_latitude double precision,
  add column if not exists last_longitude double precision;

update public.profiles
set
  selected_area = coalesce(selected_area, area),
  last_latitude = coalesce(last_latitude, lat),
  last_longitude = coalesce(last_longitude, lng)
where true;

create index if not exists barbershops_area_idx on public.barbershops (area);

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
  google_maps_url,
  phone,
  whatsapp,
  instagram,
  opening_hours,
  status,
  is_verified,
  is_featured,
  created_at,
  logo_path,
  cover_path,
  home_service,
  updated_at,
  deleted_at
from public.barbershops
where deleted_at is null;

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
  created_at,
  start_at,
  end_at,
  price_bhd,
  updated_at
from public.bookings;

alter table public.reels add column if not exists created_by uuid references public.profiles (id) on delete set null;
alter table public.reels add column if not exists owner_type text check (owner_type in ('admin','shop','barber'));
alter table public.reels add column if not exists shares_count int not null default 0;
alter table public.reels add column if not exists media_path text;
alter table public.reels add column if not exists thumbnail_path text;
alter table public.reels add column if not exists deleted_at timestamptz;

update public.reels r
set
  owner_type = coalesce(
    r.owner_type,
    case
      when r.barber_id is not null then 'barber'
      when r.shop_id is not null then 'shop'
      else 'admin'
    end
  )
where r.owner_type is null;

update public.reels r
set created_by = coalesce(r.created_by, b.profile_id, r.approved_by)
from public.barbers b
where r.created_by is null
  and r.barber_id = b.id;

update public.reels r
set created_by = s.owner_profile_id
from public.barbers b
join public.barbershops s on s.id = b.shop_id
where r.created_by is null
  and r.barber_id = b.id
  and b.shop_id is not null;

update public.reels r
set created_by = coalesce(r.created_by, s.owner_profile_id, r.approved_by)
from public.barbershops s
where r.created_by is null
  and r.shop_id = s.id;

update public.reels
set created_by = approved_by
where created_by is null
  and approved_by is not null;

create or replace function public.reels_set_created_by()
returns trigger
language plpgsql
as $$
begin
  if new.created_by is null then
    new.created_by := auth.uid();
  end if;

  if new.owner_type is null then
    new.owner_type := case
      when new.barber_id is not null then 'barber'
      when new.shop_id is not null then 'shop'
      else 'admin'
    end;
  end if;

  return new;
end;
$$;

drop trigger if exists reels_set_created_by on public.reels;
create trigger reels_set_created_by
before insert on public.reels
for each row execute function public.reels_set_created_by();

create or replace view public.posts with (security_invoker = true) as
select
  r.id,
  r.created_by,
  r.owner_type,
  r.shop_id,
  r.barber_id,
  r.media_url,
  r.thumbnail_url,
  r.media_type,
  r.caption,
  r.hashtags,
  r.location,
  r.status,
  r.likes_count,
  r.comments_count,
  r.saves_count,
  r.shares_count,
  r.created_at,
  r.media_path,
  r.thumbnail_path,
  r.rejection_reason,
  r.deleted_at
from public.reels r;

create or replace view public.post_likes with (security_invoker = true) as
select
  id,
  reel_id as post_id,
  profile_id as user_id,
  created_at
from public.reel_likes;

create or replace view public.post_comments with (security_invoker = true) as
select
  id,
  reel_id as post_id,
  profile_id as user_id,
  text as comment,
  created_at
from public.reel_comments;

create or replace view public.post_saves with (security_invoker = true) as
select
  id,
  reel_id as post_id,
  profile_id as user_id,
  created_at
from public.reel_saves;

do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values
      ('avatars', 'avatars', true),
      ('profile-covers', 'profile-covers', true),
      ('shop-images', 'shop-images', true),
      ('barber-images', 'barber-images', true),
      ('service-images', 'service-images', true),
      ('products', 'products', true),
      ('product-images', 'product-images', true),
      ('portfolio', 'portfolio', true),
      ('reels', 'reels', true),
      ('reels-media', 'reels-media', true),
      ('post-media', 'post-media', true),
      ('offer-images', 'offer-images', true),
      ('awards', 'awards', true)
    on conflict (id) do update set public = excluded.public;
  end if;

  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_admin_all" on storage.objects;
    create policy "storage_admin_all"
    on storage.objects
    for all
    to authenticated
    using (public.is_admin())
    with check (public.is_admin());

    drop policy if exists "storage_public_read_hallaq_master" on storage.objects;
    create policy "storage_public_read_hallaq_master"
    on storage.objects
    for select
    to anon, authenticated
    using (
      bucket_id in (
        'avatars',
        'profile-covers',
        'shop-images',
        'barber-images',
        'service-images',
        'products',
        'product-images',
        'portfolio',
        'reels',
        'reels-media',
        'post-media',
        'offer-images',
        'awards'
      )
    );
  end if;
end;
$$;

commit;

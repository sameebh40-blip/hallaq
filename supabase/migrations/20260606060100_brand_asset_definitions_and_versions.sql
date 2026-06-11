begin;

create table if not exists public.brand_asset_definitions (
  asset_key text primary key,
  section text not null,
  label text not null,
  folder text not null,
  crop_ratio text not null default 'free',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.brand_asset_definitions enable row level security;

grant select on table public.brand_asset_definitions to anon, authenticated;

drop policy if exists "brand_asset_definitions_public_read" on public.brand_asset_definitions;
create policy "brand_asset_definitions_public_read"
on public.brand_asset_definitions
for select
to anon, authenticated
using (true);

drop policy if exists "brand_asset_definitions_admin_all" on public.brand_asset_definitions;
create policy "brand_asset_definitions_admin_all"
on public.brand_asset_definitions
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop trigger if exists brand_asset_definitions_set_updated_at on public.brand_asset_definitions;
create trigger brand_asset_definitions_set_updated_at
before update on public.brand_asset_definitions
for each row execute function public.set_updated_at();

create table if not exists public.asset_versions (
  id uuid primary key default gen_random_uuid(),
  asset_key text not null references public.brand_assets(asset_key) on delete cascade,
  asset_url text,
  bucket text,
  path text,
  version_number integer not null,
  created_by uuid,
  created_at timestamptz not null default now(),
  is_active boolean not null default false
);

create index if not exists asset_versions_asset_key_version_idx
on public.asset_versions (asset_key, version_number desc);

create unique index if not exists asset_versions_asset_key_version_unique
on public.asset_versions (asset_key, version_number);

alter table public.asset_versions enable row level security;

grant select on table public.asset_versions to authenticated;

drop policy if exists "asset_versions_admin_all" on public.asset_versions;
create policy "asset_versions_admin_all"
on public.asset_versions
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create or replace function public.brand_assets_record_version()
returns trigger
language plpgsql
as $$
declare
  next_version integer;
begin
  if tg_op = 'UPDATE' then
    if
      coalesce(new.asset_url, '') = coalesce(old.asset_url, '')
      and coalesce(new.bucket, '') = coalesce(old.bucket, '')
      and coalesce(new.path, '') = coalesce(old.path, '')
      and coalesce(new.is_active, true) = coalesce(old.is_active, true)
    then
      return new;
    end if;
  end if;

  select coalesce(max(v.version_number), 0) + 1
  into next_version
  from public.asset_versions v
  where v.asset_key = new.asset_key;

  update public.asset_versions
  set is_active = false
  where asset_key = new.asset_key
    and is_active = true;

  insert into public.asset_versions (
    asset_key,
    asset_url,
    bucket,
    path,
    version_number,
    created_by,
    created_at,
    is_active
  )
  values (
    new.asset_key,
    new.asset_url,
    new.bucket,
    new.path,
    next_version,
    new.updated_by,
    now(),
    true
  );

  return new;
end;
$$;

drop trigger if exists brand_assets_record_version_after_change on public.brand_assets;
create trigger brand_assets_record_version_after_change
after insert or update on public.brand_assets
for each row execute function public.brand_assets_record_version();

create or replace function public.restore_brand_asset_version(p_asset_key text, p_version_number integer, p_user_id uuid)
returns void
language plpgsql
as $$
declare
  v record;
begin
  select asset_url, bucket, path
  into v
  from public.asset_versions
  where asset_key = p_asset_key
    and version_number = p_version_number;

  if v is null then
    raise exception 'Asset version not found for % (version %)', p_asset_key, p_version_number;
  end if;

  update public.brand_assets
  set
    asset_url = v.asset_url,
    bucket = v.bucket,
    path = v.path,
    is_active = true,
    updated_by = p_user_id,
    updated_at = now()
  where asset_key = p_asset_key;
end;
$$;

insert into public.brand_asset_definitions (asset_key, section, label, folder, crop_ratio)
values
  ('app_logo', 'Logos', 'App Logo', 'logos', 'free'),
  ('app_logo_dark', 'Logos', 'App Logo Dark', 'logos', 'free'),
  ('app_logo_light', 'Logos', 'App Logo Light', 'logos', 'free'),
  ('splash_logo', 'Logos', 'Splash Logo', 'logos', 'free'),
  ('login_logo', 'Logos', 'Login Logo', 'logos', 'free'),

  ('default_profile_avatar', 'Default Profile Images', 'Default Profile Avatar', 'avatars', '1:1'),
  ('default_profile_cover', 'Default Profile Images', 'Default Profile Cover', 'banners', '16:9'),

  ('default_shop_logo', 'Default Shop Logos', 'Default Shop Logo', 'logos', '1:1'),
  ('default_shop_cover', 'Default Shop Covers', 'Default Shop Cover', 'shop-covers', '16:9'),

  ('default_barber_avatar', 'Default Barber Avatars', 'Default Barber Avatar', 'avatars', '1:1'),
  ('default_barber_cover', 'Default Barber Covers', 'Default Barber Cover', 'banners', '16:9'),

  ('default_service_image', 'Default Service Images', 'Default Service Image', 'service-images', '1:1'),
  ('default_product_image', 'Default Product Images', 'Default Product Image', 'product-images', '1:1'),
  ('default_reel_thumbnail', 'Default Reel Thumbnails', 'Default Reel Thumbnail', 'reel-thumbnails', '9:16'),

  ('default_login_background', 'Login Backgrounds', 'Default Login Background', 'banners', 'free'),
  ('default_home_hero_banner', 'Home Hero Banners', 'Default Home Hero Banner', 'banners', '3:1'),

  ('default_empty_state', 'Empty State Images', 'Default Empty State', 'empty-states', 'free'),
  ('default_error_state', 'Error State Images', 'Default Error State', 'errors', 'free'),
  ('default_notification_image', 'Notification Images', 'Default Notification Image', 'notifications', 'free'),

  ('default_gift_card_image', 'Gift Card Images', 'Default Gift Card Image', 'banners', 'free'),

  ('default_membership_banner', 'Membership Images', 'Default Membership Banner', 'membership', '16:9'),
  ('default_membership_banner_en', 'Membership Images', 'Membership Banner (English)', 'membership', '16:9'),
  ('default_membership_banner_ar', 'Membership Images', 'Membership Banner (Arabic)', 'membership', '16:9'),
  ('default_home_hero_banner_en', 'Home Hero Banners', 'Home Hero Banner (English)', 'banners', '3:1'),
  ('default_home_hero_banner_ar', 'Home Hero Banners', 'Home Hero Banner (Arabic)', 'banners', '3:1')
on conflict (asset_key) do update
set
  section = excluded.section,
  label = excluded.label,
  folder = excluded.folder,
  crop_ratio = excluded.crop_ratio,
  updated_at = now();

insert into public.brand_assets (asset_key, asset_name, asset_type, is_active)
select d.asset_key, d.label, null, true
from public.brand_asset_definitions d
where not exists (select 1 from public.brand_assets a where a.asset_key = d.asset_key);

commit;

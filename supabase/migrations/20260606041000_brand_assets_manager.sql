begin;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'brand_assets'
      and column_name = 'key'
  ) then
    execute 'alter table public.brand_assets rename column key to asset_key';
  end if;
end;
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'brand_assets'
      and column_name = 'public_url'
  ) then
    execute 'alter table public.brand_assets rename column public_url to asset_url';
  end if;
end;
$$;

alter table public.brand_assets
  add column if not exists id uuid,
  add column if not exists asset_name text,
  add column if not exists asset_type text,
  add column if not exists is_active boolean not null default true,
  add column if not exists created_at timestamptz not null default now();

update public.brand_assets set id = gen_random_uuid() where id is null;

alter table public.brand_assets
  alter column id set default gen_random_uuid(),
  alter column id set not null;

alter table public.brand_assets drop constraint if exists brand_assets_pkey;
alter table public.brand_assets add constraint brand_assets_pkey primary key (id);

alter table public.brand_assets drop constraint if exists brand_assets_asset_key_key;
alter table public.brand_assets add constraint brand_assets_asset_key_key unique (asset_key);

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'brand_assets'
      and column_name = 'asset_url'
  ) then
    execute 'alter table public.brand_assets alter column asset_url drop not null';
  end if;
end;
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'brand_assets'
      and column_name = 'bucket'
  ) then
    execute 'alter table public.brand_assets alter column bucket drop not null';
  end if;
end;
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'brand_assets'
      and column_name = 'path'
  ) then
    execute 'alter table public.brand_assets alter column path drop not null';
  end if;
end;
$$;

update public.brand_assets
set
  asset_name = coalesce(asset_name, initcap(replace(asset_key, '_', ' '))),
  created_at = coalesce(created_at, updated_at, now());

update public.brand_assets
set asset_key = 'default_profile_avatar'
where asset_key = 'default_avatar'
  and not exists (select 1 from public.brand_assets b2 where b2.asset_key = 'default_profile_avatar');

alter table public.brand_assets enable row level security;

drop policy if exists "brand_assets_read_public" on public.brand_assets;
drop policy if exists "brand_assets_public_read_active" on public.brand_assets;
create policy "brand_assets_public_read_active"
on public.brand_assets
for select
to anon, authenticated
using (is_active = true);

drop policy if exists "brand_assets_admin_write" on public.brand_assets;
drop policy if exists "brand_assets_admin_all" on public.brand_assets;
create policy "brand_assets_admin_all"
on public.brand_assets
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop trigger if exists brand_assets_set_updated_at on public.brand_assets;
create trigger brand_assets_set_updated_at
before update on public.brand_assets
for each row execute function public.set_updated_at();

insert into public.brand_assets (asset_key, asset_name, asset_type, is_active)
values
  ('app_logo', 'App Logo', 'logo', true),
  ('app_logo_dark', 'App Logo Dark', 'logo', true),
  ('app_logo_light', 'App Logo Light', 'logo', true),
  ('splash_logo', 'Splash Logo', 'logo', true),
  ('login_logo', 'Login Logo', 'logo', true),
  ('default_profile_avatar', 'Default Profile Avatar', 'avatar', true),
  ('default_profile_cover', 'Default Profile Cover', 'cover', true),
  ('default_customer_avatar', 'Default Customer Avatar', 'avatar', true),
  ('default_barber_avatar', 'Default Barber Avatar', 'avatar', true),
  ('default_barber_cover', 'Default Barber Cover', 'cover', true),
  ('default_shop_logo', 'Default Shop Logo', 'logo', true),
  ('default_shop_cover', 'Default Shop Cover', 'cover', true),
  ('default_service_image', 'Default Service Image', 'image', true),
  ('default_product_image', 'Default Product Image', 'image', true),
  ('default_reel_thumbnail', 'Default Reel Thumbnail', 'image', true),
  ('default_offer_image', 'Default Offer Image', 'image', true),
  ('default_style_image', 'Default Style Image', 'image', true),
  ('default_empty_state', 'Default Empty State', 'image', true),
  ('default_error_state', 'Default Error State', 'image', true),
  ('default_booking_image', 'Default Booking Image', 'image', true),
  ('default_hallaq_city_banner', 'Default Hallaq City Banner', 'banner', true),
  ('default_home_banner', 'Default Home Banner', 'banner', true)
on conflict (asset_key) do nothing;

do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values ('brand-assets', 'brand-assets', true)
    on conflict (id) do update set public = excluded.public;
  end if;

  if to_regclass('storage.objects') is not null then
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
        'awards',
        'style-library',
        'brand-assets'
      )
    );
  end if;
end;
$$;

commit;

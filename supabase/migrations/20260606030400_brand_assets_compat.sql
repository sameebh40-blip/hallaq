begin;

alter table public.brand_assets
  add column if not exists asset_key text,
  add column if not exists asset_url text,
  add column if not exists is_active boolean not null default true;

update public.brand_assets
set asset_key = coalesce(asset_key, key)
where asset_key is null;

update public.brand_assets
set asset_url = coalesce(asset_url, public_url)
where asset_url is null;

create unique index if not exists brand_assets_asset_key_unique on public.brand_assets (asset_key);
create index if not exists brand_assets_active_idx on public.brand_assets (is_active, updated_at desc);

commit;


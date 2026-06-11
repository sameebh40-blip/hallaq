begin;

alter table public.brand_assets
  add column if not exists asset_name text,
  add column if not exists asset_type text,
  add column if not exists created_at timestamptz not null default now();

update public.brand_assets
set asset_name = coalesce(asset_name, asset_key, key)
where asset_name is null;

update public.brand_assets
set created_at = coalesce(created_at, updated_at, now())
where created_at is null;

commit;


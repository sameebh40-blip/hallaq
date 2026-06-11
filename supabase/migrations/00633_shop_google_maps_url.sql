alter table public.barbershops
add column if not exists google_maps_url text;

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
  google_maps_url,
  phone,
  whatsapp,
  instagram,
  opening_hours,
  status,
  is_verified,
  is_featured,
  created_at
from public.barbershops;

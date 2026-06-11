begin;

create or replace function public.list_nearby_shops(
  p_lat double precision,
  p_lng double precision,
  p_limit int default 20,
  p_offset int default 0
)
returns table (
  id uuid,
  owner_profile_id uuid,
  name text,
  description text,
  cover_url text,
  logo_url text,
  cover_path text,
  logo_path text,
  area text,
  address text,
  lat double precision,
  lng double precision,
  google_maps_url text,
  phone text,
  whatsapp text,
  instagram text,
  opening_hours jsonb,
  status text,
  is_verified boolean,
  is_featured boolean,
  rating_avg numeric,
  rating_count int,
  badge_verified boolean,
  badge_elite boolean,
  badge_trending boolean,
  badge_top_rated boolean,
  badge_certified boolean,
  deleted_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  distance_km double precision,
  starting_price_bhd numeric
)
language sql
stable
as $$
  select
    s.id,
    s.owner_profile_id,
    s.name,
    s.description,
    s.cover_url,
    s.logo_url,
    s.cover_path,
    s.logo_path,
    s.area,
    s.address,
    s.lat,
    s.lng,
    s.google_maps_url,
    s.phone,
    s.whatsapp,
    s.instagram,
    s.opening_hours,
    s.status,
    s.is_verified,
    s.is_featured,
    s.rating_avg,
    s.rating_count,
    s.badge_verified,
    s.badge_elite,
    s.badge_trending,
    s.badge_top_rated,
    s.badge_certified,
    s.deleted_at,
    s.created_at,
    s.updated_at,
    public.distance_km(p_lat, p_lng, s.lat, s.lng) as distance_km,
    (
      select min(sv.price_bhd)
      from public.services sv
      where sv.shop_id = s.id
        and sv.is_active = true
        and sv.deleted_at is null
    ) as starting_price_bhd
  from public.barbershops s
  where s.lat is not null
    and s.lng is not null
    and s.deleted_at is null
    and s.status = 'approved'
  order by distance_km asc, s.rating_avg desc, s.created_at desc
  limit greatest(p_limit, 0)
  offset greatest(p_offset, 0);
$$;

commit;

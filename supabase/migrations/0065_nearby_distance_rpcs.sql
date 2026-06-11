begin;

create or replace function public.distance_km(
  from_lat double precision,
  from_lng double precision,
  to_lat double precision,
  to_lng double precision
)
returns double precision
language sql
immutable
as $$
  select
    6371.0 * 2.0 * asin(
      sqrt(
        power(sin(radians((to_lat - from_lat) / 2.0)), 2.0)
        + cos(radians(from_lat)) * cos(radians(to_lat)) * power(sin(radians((to_lng - from_lng) / 2.0)), 2.0)
      )
    );
$$;

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
  with ranked as (
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
  )
  select *
  from ranked
  order by distance_km asc, rating_avg desc, created_at desc
  limit greatest(p_limit, 0)
  offset greatest(p_offset, 0);
$$;

create or replace function public.list_nearby_barbers(
  p_lat double precision,
  p_lng double precision,
  p_limit int default 20,
  p_offset int default 0
)
returns table (
  id uuid,
  profile_id uuid,
  shop_id uuid,
  slug text,
  display_name text,
  avatar_url text,
  cover_url text,
  avatar_path text,
  cover_path text,
  bio text,
  specialty text,
  area text,
  address text,
  lat double precision,
  lng double precision,
  is_independent boolean,
  is_verified boolean,
  is_hallaq_certified boolean,
  rating_avg numeric,
  rating_count int,
  followers_count int,
  reviews_count int,
  available_now boolean,
  waiting_time_min int,
  queue_length int,
  badge_verified boolean,
  badge_elite boolean,
  badge_trending boolean,
  badge_top_rated boolean,
  badge_certified boolean,
  status text,
  deleted_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  distance_km double precision,
  starting_price_bhd numeric
)
language sql
stable
as $$
  with ranked as (
    select
      b.id,
      b.profile_id,
      b.shop_id,
      b.slug,
      b.display_name,
      b.avatar_url,
      b.cover_url,
      b.avatar_path,
      b.cover_path,
      b.bio,
      b.specialty,
      b.area,
      b.address,
      b.lat,
      b.lng,
      b.is_independent,
      b.is_verified,
      b.is_hallaq_certified,
      b.rating_avg,
      b.rating_count,
      b.followers_count,
      b.reviews_count,
      b.available_now,
      b.waiting_time_min,
      b.queue_length,
      b.badge_verified,
      b.badge_elite,
      b.badge_trending,
      b.badge_top_rated,
      b.badge_certified,
      b.status,
      b.deleted_at,
      b.created_at,
      b.updated_at,
      public.distance_km(p_lat, p_lng, b.lat, b.lng) as distance_km,
      (
        select min(sv.price_bhd)
        from public.barber_services_effective sv
        where sv.barber_ref = b.id
      ) as starting_price_bhd
    from public.barbers b
    where b.lat is not null
      and b.lng is not null
      and b.deleted_at is null
      and b.status = 'active'
      and b.is_verified = true
  )
  select *
  from ranked
  order by distance_km asc, rating_avg desc, created_at desc
  limit greatest(p_limit, 0)
  offset greatest(p_offset, 0);
$$;

commit;

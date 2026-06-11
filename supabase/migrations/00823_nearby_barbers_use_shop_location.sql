begin;

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
      coalesce(s.area, b.area) as area,
      coalesce(s.address, b.address) as address,
      coalesce(s.lat, b.lat) as lat,
      coalesce(s.lng, b.lng) as lng,
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
      case
        when coalesce(s.lat, b.lat) is null or coalesce(s.lng, b.lng) is null then null
        else public.distance_km(p_lat, p_lng, coalesce(s.lat, b.lat), coalesce(s.lng, b.lng))
      end as distance_km,
      (
        select min(sv.price_bhd)
        from public.barber_services_effective sv
        where sv.barber_ref = b.id
      ) as starting_price_bhd
    from public.barbers b
    left join public.barbershops s on s.id = b.shop_id and s.deleted_at is null and s.status in ('pending','approved')
    where b.deleted_at is null
      and b.status = 'active'
  )
  select *
  from ranked
  order by (distance_km is null) asc, distance_km asc, rating_avg desc, created_at desc
  limit greatest(p_limit, 0)
  offset greatest(p_offset, 0);
$$;

commit;


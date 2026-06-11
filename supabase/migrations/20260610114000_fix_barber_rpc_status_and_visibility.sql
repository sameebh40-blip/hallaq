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
    left join public.barbershops s
      on s.id = b.shop_id
     and s.deleted_at is null
     and s.is_active = true
     and s.status = 'approved'
    where b.deleted_at is null
      and b.is_active = true
      and b.status = 'approved'
  )
  select *
  from ranked
  order by (distance_km is null) asc, distance_km asc, rating_avg desc, created_at desc
  limit greatest(p_limit, 0)
  offset greatest(p_offset, 0);
$$;

grant execute on function public.list_nearby_barbers(double precision, double precision, int, int) to anon, authenticated;

create or replace function public.search_barbers(
  p_lat double precision,
  p_lng double precision,
  p_query text,
  p_limit int default 30,
  p_offset int default 0,
  p_open_now boolean default false,
  p_available_today boolean default false,
  p_verified_only boolean default false,
  p_home_service_only boolean default false,
  p_sort text default 'nearest',
  p_max_distance_km double precision default null,
  p_min_price_bhd numeric default null,
  p_max_price_bhd numeric default null
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
  with q as (
    select '%' || coalesce(nullif(trim(p_query), ''), '') || '%' as like_q
  ),
  ranked as (
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
      case
        when b.lat is null or b.lng is null then null
        else public.distance_km(p_lat, p_lng, b.lat, b.lng)
      end as distance_km,
      (
        select min(sv.price_bhd)
        from public.barber_services_effective sv
        where sv.barber_ref = b.id
      ) as starting_price_bhd
    from public.barbers b, q
    where b.deleted_at is null
      and b.is_active = true
      and b.status = 'approved'
      and (not p_open_now or b.available_now is true)
      and (
        not p_available_today
        or exists (
          select 1
          from public.availability_cache_days ac
          where ac.barber_id = b.id
            and ac.day = (now() at time zone 'Asia/Bahrain')::date
            and ac.duration_minutes = 30
            and ac.slot_minutes = 30
            and ac.has_slots = true
        )
      )
      and (not p_verified_only or b.is_verified is true or b.badge_verified is true)
      and (not p_home_service_only or b.home_service is true)
      and (
        p_max_distance_km is null
        or (b.lat is not null and b.lng is not null and public.distance_km(p_lat, p_lng, b.lat, b.lng) <= p_max_distance_km)
      )
      and (
        p_min_price_bhd is null
        or (
          select min(sv.price_bhd)
          from public.barber_services_effective sv
          where sv.barber_ref = b.id
        ) >= p_min_price_bhd
      )
      and (
        p_max_price_bhd is null
        or (
          select min(sv.price_bhd)
          from public.barber_services_effective sv
          where sv.barber_ref = b.id
        ) <= p_max_price_bhd
      )
      and (
        b.display_name ilike q.like_q
        or coalesce(b.area, '') ilike q.like_q
        or coalesce(b.address, '') ilike q.like_q
        or exists (
          select 1
          from public.barber_services_effective sv
          where sv.barber_ref = b.id
            and (
              coalesce(sv.name_en, '') ilike q.like_q
              or coalesce(sv.name_ar, '') ilike q.like_q
              or coalesce(sv.category, '') ilike q.like_q
            )
        )
      )
  )
  select *
  from ranked
  order by
    case when lower(coalesce(p_sort, 'nearest')) = 'top_rated' then null else (distance_km is null) end asc nulls last,
    case when lower(coalesce(p_sort, 'nearest')) = 'top_rated' then null else distance_km end asc nulls last,
    case when lower(coalesce(p_sort, 'nearest')) = 'top_rated' then null else rating_avg end desc nulls last,
    rating_avg desc,
    created_at desc
  limit greatest(p_limit, 0)
  offset greatest(p_offset, 0);
$$;

grant execute on function public.search_barbers(double precision, double precision, text, int, int, boolean, boolean, boolean, boolean, text, double precision, numeric, numeric) to anon, authenticated;

create or replace function public.city_trending_barbers(p_limit int default 30)
returns table (
  barber_id uuid,
  score bigint,
  bookings_count bigint,
  views_count bigint,
  likes_count bigint,
  followers_count int,
  rating_avg numeric,
  display_name text,
  area text,
  avatar_url text,
  avatar_path text
)
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  with week as (
    select now() - interval '7 days' as start_at
  ),
  booking_counts as (
    select
      b.barber_id,
      count(*)::bigint as bookings_count
    from public.bookings b, week
    where b.barber_id is not null
      and b.start_at >= week.start_at
      and b.status in ('confirmed','completed')
    group by b.barber_id
  ),
  reel_views as (
    select
      r.barber_id,
      sum(coalesce(r.views_count, 0))::bigint as views_count
    from public.reels r
    cross join week
    where r.barber_id is not null
      and r.status = 'approved'
      and r.deleted_at is null
      and r.created_at >= week.start_at
    group by r.barber_id
  ),
  reel_likes as (
    select
      r.barber_id,
      sum(coalesce(r.likes_count, 0))::bigint as likes_count
    from public.reels r
    where r.barber_id is not null
      and r.status = 'approved'
      and r.deleted_at is null
    group by r.barber_id
  )
  select
    br.id as barber_id,
    (
      coalesce(bc.bookings_count, 0) * 50
      + coalesce(rv.views_count, 0) * 2
      + coalesce(rl.likes_count, 0) * 5
      + coalesce(br.followers_count, 0)
      + (coalesce(br.rating_avg, 0) * 100)::bigint
    )::bigint as score,
    coalesce(bc.bookings_count, 0)::bigint as bookings_count,
    coalesce(rv.views_count, 0)::bigint as views_count,
    coalesce(rl.likes_count, 0)::bigint as likes_count,
    coalesce(br.followers_count, 0)::int as followers_count,
    coalesce(br.rating_avg, 0)::numeric as rating_avg,
    br.display_name,
    br.area,
    br.avatar_url,
    br.avatar_path
  from public.barbers br
  left join booking_counts bc on bc.barber_id = br.id
  left join reel_views rv on rv.barber_id = br.id
  left join reel_likes rl on rl.barber_id = br.id
  where br.deleted_at is null
    and br.is_active = true
    and br.status = 'approved'
  order by score desc nulls last, br.rating_avg desc, br.created_at desc
  limit greatest(1, least(p_limit, 50));
$$;

grant execute on function public.city_trending_barbers(int) to anon, authenticated;

commit;

begin;

alter table public.barbers
add column if not exists home_service boolean not null default false;

alter table public.barbershops
add column if not exists home_service boolean not null default false;

create or replace function public.has_hours_today(opening_hours jsonb)
returns boolean
language plpgsql
stable
as $$
declare
  now0 timestamptz := now();
  today_key text;
  raw text;
begin
  if opening_hours is null then
    return false;
  end if;

  today_key := case extract(isodow from (now0 at time zone 'Asia/Bahrain'))
    when 1 then 'mon'
    when 2 then 'tue'
    when 3 then 'wed'
    when 4 then 'thu'
    when 5 then 'fri'
    when 6 then 'sat'
    else 'sun'
  end;

  raw := trim(coalesce(opening_hours ->> today_key, ''));
  if raw = '' then
    return false;
  end if;

  if position('-' in raw) = 0 then
    return false;
  end if;

  return true;
end;
$$;

create or replace function public.is_open_now(opening_hours jsonb)
returns boolean
language plpgsql
stable
as $$
declare
  local_now timestamp := (now() at time zone 'Asia/Bahrain')::timestamp;
  today_key text;
  raw text;
  start_txt text;
  end_txt text;
  start_t time;
  end_t time;
  now_t time := local_now::time;
begin
  if opening_hours is null then
    return false;
  end if;

  today_key := case extract(isodow from local_now)
    when 1 then 'mon'
    when 2 then 'tue'
    when 3 then 'wed'
    when 4 then 'thu'
    when 5 then 'fri'
    when 6 then 'sat'
    else 'sun'
  end;

  raw := trim(coalesce(opening_hours ->> today_key, ''));
  if raw = '' or position('-' in raw) = 0 then
    return false;
  end if;

  start_txt := split_part(raw, '-', 1);
  end_txt := split_part(raw, '-', 2);
  start_t := start_txt::time;
  end_t := end_txt::time;

  if start_t = end_t then
    return true;
  end if;

  if end_t > start_t then
    return now_t >= start_t and now_t < end_t;
  end if;

  return now_t >= start_t or now_t < end_t;
exception
  when others then
    return false;
end;
$$;

create or replace function public.search_shops(
  p_lat double precision,
  p_lng double precision,
  p_query text,
  p_limit int default 30,
  p_offset int default 0,
  p_open_now boolean default false,
  p_available_today boolean default false,
  p_verified_only boolean default false,
  p_home_service_only boolean default false,
  p_sort text default 'nearest'
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
  with q as (
    select '%' || coalesce(nullif(trim(p_query), ''), '') || '%' as like_q
  ),
  ranked as (
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
      case
        when s.lat is null or s.lng is null then null
        else public.distance_km(p_lat, p_lng, s.lat, s.lng)
      end as distance_km,
      (
        select min(sv.price_bhd)
        from public.services sv
        where sv.shop_id = s.id
          and sv.is_active = true
          and sv.deleted_at is null
      ) as starting_price_bhd
    from public.barbershops s, q
    where s.deleted_at is null
      and s.status = 'approved'
      and (not p_open_now or public.is_open_now(s.opening_hours))
      and (not p_available_today or public.has_hours_today(s.opening_hours))
      and (not p_verified_only or s.is_verified is true or s.badge_verified is true)
      and (not p_home_service_only or s.home_service is true)
      and (
        s.name ilike q.like_q
        or coalesce(s.area, '') ilike q.like_q
        or coalesce(s.address, '') ilike q.like_q
        or exists (
          select 1
          from public.services sv
          where sv.shop_id = s.id
            and sv.is_active = true
            and sv.deleted_at is null
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
    case when lower(coalesce(p_sort, 'nearest')) = 'top_rated' then rating_avg end desc nulls last,
    rating_avg desc,
    created_at desc
  limit greatest(p_limit, 0)
  offset greatest(p_offset, 0);
$$;

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
  p_sort text default 'nearest'
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
      and b.status = 'active'
      and b.is_verified = true
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
    case when lower(coalesce(p_sort, 'nearest')) = 'top_rated' then rating_avg end desc nulls last,
    rating_avg desc,
    created_at desc
  limit greatest(p_limit, 0)
  offset greatest(p_offset, 0);
$$;

commit;

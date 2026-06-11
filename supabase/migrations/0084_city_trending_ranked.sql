begin;

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
      count(*)::bigint as views_count
    from public.reel_view_events v
    join public.reels r on r.id = v.reel_id
    cross join week
    where v.created_at >= week.start_at
      and r.barber_id is not null
      and r.status = 'approved'
      and r.deleted_at is null
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
  where br.status = 'active'
  order by score desc nulls last, br.rating_avg desc, br.created_at desc
  limit greatest(1, least(p_limit, 50));
$$;

grant execute on function public.city_trending_barbers(int) to anon, authenticated;

create or replace function public.city_trending_shops(p_limit int default 30)
returns table (
  shop_id uuid,
  score bigint,
  bookings_count bigint,
  views_count bigint,
  likes_count bigint,
  followers_count int,
  rating_avg numeric,
  name text,
  area text,
  logo_url text,
  logo_path text
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
      b.shop_id,
      count(*)::bigint as bookings_count
    from public.bookings b, week
    where b.shop_id is not null
      and b.start_at >= week.start_at
      and b.status in ('confirmed','completed')
    group by b.shop_id
  ),
  reel_views as (
    select
      r.shop_id,
      count(*)::bigint as views_count
    from public.reel_view_events v
    join public.reels r on r.id = v.reel_id
    cross join week
    where v.created_at >= week.start_at
      and r.shop_id is not null
      and r.status = 'approved'
      and r.deleted_at is null
    group by r.shop_id
  ),
  reel_likes as (
    select
      r.shop_id,
      sum(coalesce(r.likes_count, 0))::bigint as likes_count
    from public.reels r
    where r.shop_id is not null
      and r.status = 'approved'
      and r.deleted_at is null
    group by r.shop_id
  )
  select
    s.id as shop_id,
    (
      coalesce(bc.bookings_count, 0) * 45
      + coalesce(rv.views_count, 0) * 2
      + coalesce(rl.likes_count, 0) * 5
      + coalesce(s.followers_count, 0) * 2
      + (coalesce(s.rating_avg, 0) * 100)::bigint
    )::bigint as score,
    coalesce(bc.bookings_count, 0)::bigint as bookings_count,
    coalesce(rv.views_count, 0)::bigint as views_count,
    coalesce(rl.likes_count, 0)::bigint as likes_count,
    coalesce(s.followers_count, 0)::int as followers_count,
    coalesce(s.rating_avg, 0)::numeric as rating_avg,
    s.name,
    s.area,
    s.logo_url,
    s.logo_path
  from public.barbershops s
  left join booking_counts bc on bc.shop_id = s.id
  left join reel_views rv on rv.shop_id = s.id
  left join reel_likes rl on rl.shop_id = s.id
  where s.status = 'approved'
    and s.deleted_at is null
  order by score desc nulls last, s.rating_avg desc, s.created_at desc
  limit greatest(1, least(p_limit, 50));
$$;

grant execute on function public.city_trending_shops(int) to anon, authenticated;

create or replace function public.city_trending_reels(p_limit int default 30)
returns table (
  reel_id uuid,
  score bigint,
  views_count bigint,
  likes_count int,
  comments_count int,
  caption text,
  thumbnail_url text,
  thumbnail_path text,
  media_url text,
  media_path text,
  barber_id uuid,
  shop_id uuid,
  created_at timestamptz
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
  views_7d as (
    select
      v.reel_id,
      count(*)::bigint as views_count
    from public.reel_view_events v, week
    where v.created_at >= week.start_at
    group by v.reel_id
  )
  select
    r.id as reel_id,
    (
      coalesce(v.views_count, 0) * 2
      + coalesce(r.likes_count, 0) * 8
      + coalesce(r.comments_count, 0) * 6
      + coalesce(r.shares_count, 0) * 4
      + coalesce(r.saves_count, 0) * 4
    )::bigint as score,
    coalesce(v.views_count, 0)::bigint as views_count,
    coalesce(r.likes_count, 0)::int as likes_count,
    coalesce(r.comments_count, 0)::int as comments_count,
    r.caption,
    r.thumbnail_url,
    r.thumbnail_path,
    r.media_url,
    r.media_path,
    r.barber_id,
    r.shop_id,
    r.created_at
  from public.reels r
  left join views_7d v on v.reel_id = r.id
  where r.status = 'approved'
    and r.deleted_at is null
  order by score desc nulls last, r.created_at desc
  limit greatest(1, least(p_limit, 50));
$$;

grant execute on function public.city_trending_reels(int) to anon, authenticated;

commit;


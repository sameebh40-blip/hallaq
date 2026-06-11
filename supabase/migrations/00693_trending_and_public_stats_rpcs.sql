begin;

create or replace function public.get_trending_this_week()
returns table (
  kind text,
  entity_type text,
  entity_id uuid,
  score bigint
)
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select
    t.kind,
    case
      when t.kind = 'most_viewed_reel' then 'reel'
      when t.kind = 'top_rated_shop' then 'shop'
      else 'barber'
    end as entity_type,
    t.entity_id,
    t.score
  from public.trending_this_week t;
$$;

grant execute on function public.get_trending_this_week() to anon, authenticated;

create or replace function public.get_barber_public_stats(p_barber_id uuid)
returns table (
  barber_id uuid,
  years_experience int,
  total_bookings int,
  average_rating numeric,
  response_time_minutes numeric,
  completion_rate numeric,
  followers int,
  portfolio_count int,
  reel_views int
)
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select
    s.barber_id,
    s.years_experience,
    s.total_bookings,
    s.average_rating,
    s.response_time_minutes,
    s.completion_rate,
    s.followers,
    s.portfolio_count,
    s.reel_views
  from public.barber_public_stats s
  where s.barber_id = p_barber_id;
$$;

grant execute on function public.get_barber_public_stats(uuid) to anon, authenticated;

commit;


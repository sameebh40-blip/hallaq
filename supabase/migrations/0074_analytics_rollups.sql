begin;

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references public.profiles (id) on delete set null,
  event_name text not null,
  entity_type text,
  entity_id uuid,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  session_id text,
  platform text,
  app_version text,
  os_name text,
  os_version text,
  device_model text
);

create index if not exists analytics_events_event_idx on public.analytics_events (event_name, created_at desc);
create index if not exists analytics_events_profile_idx on public.analytics_events (profile_id, created_at desc);

alter table public.analytics_events enable row level security;

drop policy if exists "analytics_events_insert_public" on public.analytics_events;
create policy "analytics_events_insert_public"
on public.analytics_events
for insert
to anon, authenticated
with check (true);

drop policy if exists "analytics_events_admin_read" on public.analytics_events;
create policy "analytics_events_admin_read"
on public.analytics_events
for select
to authenticated
using (public.is_admin());

alter table public.analytics_events
add column if not exists session_id text,
add column if not exists platform text,
add column if not exists app_version text,
add column if not exists os_name text,
add column if not exists os_version text,
add column if not exists device_model text;

create index if not exists analytics_events_event_created_idx on public.analytics_events (event_name, created_at desc);
create index if not exists analytics_events_platform_created_idx on public.analytics_events (platform, created_at desc);
create index if not exists analytics_events_session_created_idx on public.analytics_events (session_id, created_at desc);

create table if not exists public.analytics_funnel_daily (
  day date primary key,
  home_view_sessions int not null default 0,
  shop_open_sessions int not null default 0,
  barber_open_sessions int not null default 0,
  booking_started_sessions int not null default 0,
  booking_completed_sessions int not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.analytics_device_daily (
  day date not null,
  platform text not null default 'unknown',
  app_version text not null default 'unknown',
  os_name text not null default 'unknown',
  os_version text not null default 'unknown',
  device_model text not null default 'unknown',
  sessions int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (day, platform, app_version, os_name, os_version, device_model)
);

create index if not exists analytics_device_daily_day_idx on public.analytics_device_daily (day desc);
create index if not exists analytics_device_daily_platform_idx on public.analytics_device_daily (platform, day desc);

alter table public.analytics_funnel_daily enable row level security;
alter table public.analytics_device_daily enable row level security;

drop policy if exists "analytics_funnel_daily_admin_read" on public.analytics_funnel_daily;
create policy "analytics_funnel_daily_admin_read"
on public.analytics_funnel_daily
for select
to authenticated
using (public.is_admin());

drop policy if exists "analytics_device_daily_admin_read" on public.analytics_device_daily;
create policy "analytics_device_daily_admin_read"
on public.analytics_device_daily
for select
to authenticated
using (public.is_admin());

create or replace function public.refresh_analytics_rollups(p_days int default 60)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  start_day date := (now() - (p_days || ' days')::interval)::date;
begin
  insert into public.analytics_funnel_daily (day)
  select gs.day
  from generate_series(start_day, (now())::date, interval '1 day') as gs(day)
  on conflict (day) do nothing;

  update public.analytics_funnel_daily d
  set
    home_view_sessions = coalesce(x.home_view_sessions, 0),
    shop_open_sessions = coalesce(x.shop_open_sessions, 0),
    barber_open_sessions = coalesce(x.barber_open_sessions, 0),
    booking_started_sessions = coalesce(x.booking_started_sessions, 0),
    booking_completed_sessions = coalesce(x.booking_completed_sessions, 0),
    updated_at = now()
  from (
    select
      (created_at)::date as day,
      count(distinct session_id) filter (where event_name = 'home_view' and session_id is not null and length(session_id) > 0) as home_view_sessions,
      count(distinct session_id) filter (where event_name = 'shop_open' and session_id is not null and length(session_id) > 0) as shop_open_sessions,
      count(distinct session_id) filter (where event_name = 'barber_open' and session_id is not null and length(session_id) > 0) as barber_open_sessions,
      count(distinct session_id) filter (where event_name = 'booking_started' and session_id is not null and length(session_id) > 0) as booking_started_sessions,
      count(distinct session_id) filter (where event_name in ('booking_completed','booking_created') and session_id is not null and length(session_id) > 0) as booking_completed_sessions
    from public.analytics_events
    where created_at >= start_day
      and event_name in ('home_view','shop_open','barber_open','booking_started','booking_completed','booking_created')
    group by 1
  ) x
  where d.day = x.day;

  delete from public.analytics_device_daily where day >= start_day;
  insert into public.analytics_device_daily (
    day,
    platform,
    app_version,
    os_name,
    os_version,
    device_model,
    sessions,
    updated_at
  )
  select
    (created_at)::date as day,
    coalesce(nullif(platform, ''), 'unknown') as platform,
    coalesce(nullif(app_version, ''), 'unknown') as app_version,
    coalesce(nullif(os_name, ''), 'unknown') as os_name,
    coalesce(nullif(os_version, ''), 'unknown') as os_version,
    coalesce(nullif(device_model, ''), 'unknown') as device_model,
    count(distinct session_id) as sessions,
    now() as updated_at
  from public.analytics_events
  where created_at >= start_day
    and session_id is not null
    and length(session_id) > 0
  group by 1,2,3,4,5,6;
end;
$$;

do $do$
begin
  create extension if not exists pg_cron;
exception
  when insufficient_privilege then null;
  when undefined_file then null;
end;
$do$;

do $do$
begin
  perform cron.schedule(
    'analytics_rollups_daily',
    '25 3 * * *',
    $cmd$select public.refresh_analytics_rollups(90);$cmd$
  );
exception
  when undefined_function then null;
  when duplicate_object then null;
end;
$do$;

commit;

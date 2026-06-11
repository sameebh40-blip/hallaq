create table if not exists public.profile_view_events (
  id uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in ('barber','shop')),
  target_id uuid not null,
  viewer_profile_id uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists profile_view_events_target_idx on public.profile_view_events (target_type, target_id, created_at desc);
create index if not exists profile_view_events_viewer_idx on public.profile_view_events (viewer_profile_id, created_at desc);

alter table public.profile_view_events enable row level security;

drop policy if exists "profile_view_events_insert_authed" on public.profile_view_events;
create policy "profile_view_events_insert_authed"
on public.profile_view_events
for insert
to authenticated
with check (viewer_profile_id = auth.uid());

drop policy if exists "profile_view_events_read_public" on public.profile_view_events;
create policy "profile_view_events_read_public"
on public.profile_view_events
for select
to anon, authenticated
using (true);

create or replace view public.barber_response_time_minutes as
with created as (
  select
    b.id as booking_id,
    b.barber_id,
    min(a.created_at) as created_at
  from public.bookings b
  join public.booking_audit_trail a on a.booking_id = b.id
  where a.action = 'created'
  group by b.id, b.barber_id
),
responded as (
  select
    b.id as booking_id,
    b.barber_id,
    min(a.created_at) as responded_at
  from public.bookings b
  join public.booking_audit_trail a on a.booking_id = b.id
  join public.barbers br on br.id = b.barber_id
  where a.action = 'status_changed'
    and a.new_status in ('accepted','rejected')
    and a.actor_profile_id = br.profile_id
  group by b.id, b.barber_id
)
select
  c.barber_id,
  avg(extract(epoch from (r.responded_at - c.created_at)) / 60.0)::numeric(10,2) as avg_minutes
from created c
join responded r on r.booking_id = c.booking_id
group by c.barber_id;

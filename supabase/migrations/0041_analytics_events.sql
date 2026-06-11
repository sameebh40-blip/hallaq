begin;

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references public.profiles (id) on delete set null,
  event_name text not null,
  entity_type text,
  entity_id uuid,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
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

commit;


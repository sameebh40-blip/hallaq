alter table public.reports
add column if not exists report_type text not null default 'other',
add column if not exists details text,
add column if not exists meta jsonb not null default '{}'::jsonb,
add column if not exists assigned_to uuid references public.profiles (id) on delete set null,
add column if not exists reviewed_by uuid references public.profiles (id) on delete set null,
add column if not exists reviewed_at timestamptz,
add column if not exists resolved_by uuid references public.profiles (id) on delete set null,
add column if not exists resolved_at timestamptz;

alter table public.reports drop constraint if exists reports_status_check;
alter table public.reports
add constraint reports_status_check
check (status in ('open','under_review','resolved','rejected'));

alter table public.reports drop constraint if exists reports_report_type_check;
alter table public.reports
add constraint reports_report_type_check
check (report_type in ('fake_shop','fake_barber','spam_review','inappropriate_reel','harassment','other'));

create index if not exists reports_status_created_idx on public.reports (status, created_at desc);
create index if not exists reports_report_type_idx on public.reports (report_type, created_at desc);
create index if not exists reports_entity_idx on public.reports (entity_type, entity_id);

drop policy if exists "reports_insert_authenticated" on public.reports;
create policy "reports_insert_authenticated"
on public.reports
for insert
to authenticated
with check (reporter_profile_id = auth.uid());

drop policy if exists "reports_read_own" on public.reports;
create policy "reports_read_own"
on public.reports
for select
to authenticated
using (reporter_profile_id = auth.uid());

drop policy if exists "reports_admin_read" on public.reports;
create policy "reports_admin_read"
on public.reports
for select
to authenticated
using (public.is_admin());

drop policy if exists "reports_admin_update" on public.reports;
create policy "reports_admin_update"
on public.reports
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create table if not exists public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  actor_profile_id uuid references public.profiles (id) on delete set null,
  action text not null,
  target_type text not null,
  target_id uuid,
  reason text,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists moderation_actions_created_idx on public.moderation_actions (created_at desc);
create index if not exists moderation_actions_target_idx on public.moderation_actions (target_type, target_id);

alter table public.moderation_actions enable row level security;

drop policy if exists "moderation_actions_admin_all" on public.moderation_actions;
create policy "moderation_actions_admin_all"
on public.moderation_actions
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

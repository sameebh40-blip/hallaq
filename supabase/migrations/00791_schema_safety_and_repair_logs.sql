begin;

alter table public.profiles add column if not exists verified boolean not null default false;
alter table public.profiles add column if not exists avatar_path text;
alter table public.profiles add column if not exists cover_path text;
alter table public.profiles add column if not exists bio text;
alter table public.profiles add column if not exists location text;
alter table public.profiles add column if not exists membership_tier text not null default 'Silver';

create table if not exists public.repair_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references public.profiles (id) on delete set null,
  repair_type text not null,
  target_table text not null,
  target_id text,
  before_data jsonb,
  after_data jsonb,
  status text not null default 'success' check (status in ('success','failed','dry_run')),
  error_message text,
  created_at timestamptz not null default now()
);

alter table public.repair_logs enable row level security;

drop policy if exists "repair_logs_admin_read" on public.repair_logs;
create policy "repair_logs_admin_read"
on public.repair_logs
for select
to authenticated
using (public.is_admin());

drop policy if exists "repair_logs_admin_insert" on public.repair_logs;
create policy "repair_logs_admin_insert"
on public.repair_logs
for insert
to authenticated
with check (public.is_admin() and admin_id = auth.uid());

create index if not exists repair_logs_created_idx on public.repair_logs (created_at desc);
create index if not exists repair_logs_target_idx on public.repair_logs (target_table, target_id);

commit;


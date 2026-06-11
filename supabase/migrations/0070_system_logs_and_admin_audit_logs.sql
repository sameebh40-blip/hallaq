begin;

create table if not exists public.system_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles (id) on delete set null,
  role text,
  page text,
  action text,
  error_message text,
  stack_trace text,
  severity text not null default 'error' check (severity in ('info','warning','error','critical')),
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists system_logs_created_at_idx on public.system_logs (created_at desc);
create index if not exists system_logs_user_id_idx on public.system_logs (user_id, created_at desc);
create index if not exists system_logs_severity_idx on public.system_logs (severity, created_at desc);

alter table public.system_logs enable row level security;

drop policy if exists "system_logs_admin_read" on public.system_logs;
create policy "system_logs_admin_read"
on public.system_logs
for select
to authenticated
using (public.is_admin());

drop policy if exists "system_logs_admin_write" on public.system_logs;
create policy "system_logs_admin_write"
on public.system_logs
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "system_logs_insert_any" on public.system_logs;
create policy "system_logs_insert_any"
on public.system_logs
for insert
to anon, authenticated
with check (true);

create table if not exists public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_profile_id uuid references public.profiles (id) on delete set null,
  action text not null,
  target_type text,
  target_id uuid,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists admin_audit_logs_created_at_idx on public.admin_audit_logs (created_at desc);
create index if not exists admin_audit_logs_admin_profile_id_idx on public.admin_audit_logs (admin_profile_id, created_at desc);

alter table public.admin_audit_logs enable row level security;

drop policy if exists "admin_audit_logs_admin_all" on public.admin_audit_logs;
create policy "admin_audit_logs_admin_all"
on public.admin_audit_logs
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

commit;


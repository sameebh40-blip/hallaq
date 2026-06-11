begin;

create table if not exists public.backup_logs (
  id uuid primary key default gen_random_uuid(),
  backup_type text not null check (backup_type in ('database','storage','full')),
  status text not null check (status in ('queued','running','succeeded','failed')),
  file_url text,
  size_mb numeric(12,2),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  error_message text
);

create index if not exists backup_logs_created_idx on public.backup_logs (created_at desc);
create index if not exists backup_logs_status_idx on public.backup_logs (status, created_at desc);

alter table public.backup_logs enable row level security;

drop policy if exists "backup_logs_admin_all" on public.backup_logs;
create policy "backup_logs_admin_all"
on public.backup_logs
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

commit;

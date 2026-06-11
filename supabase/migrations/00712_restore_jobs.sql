begin;

create table if not exists public.restore_jobs (
  id uuid primary key default gen_random_uuid(),
  backup_log_id uuid not null references public.backup_logs (id) on delete cascade,
  status text not null check (status in ('queued','running','succeeded','failed')),
  requested_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  finished_at timestamptz,
  error_message text
);

create index if not exists restore_jobs_created_idx on public.restore_jobs (created_at desc);
create index if not exists restore_jobs_backup_idx on public.restore_jobs (backup_log_id, created_at desc);

alter table public.restore_jobs enable row level security;

drop policy if exists "restore_jobs_admin_all" on public.restore_jobs;
create policy "restore_jobs_admin_all"
on public.restore_jobs
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

commit;


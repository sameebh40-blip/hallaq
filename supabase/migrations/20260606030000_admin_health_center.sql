begin;

alter table public.system_logs
  add column if not exists device text,
  add column if not exists platform text,
  add column if not exists status text not null default 'open';

alter table public.system_logs
  drop constraint if exists system_logs_status_check;

alter table public.system_logs
  add constraint system_logs_status_check
  check (status in ('open','fixed','ignored'));

create index if not exists system_logs_status_created_idx on public.system_logs (status, created_at desc);

create table if not exists public.health_check_results (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null default gen_random_uuid(),
  check_id text not null,
  status text not null check (status in ('ok','warning','broken','skipped')),
  detail text,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists health_check_results_created_idx on public.health_check_results (created_at desc);
create index if not exists health_check_results_run_idx on public.health_check_results (run_id, created_at desc);
create index if not exists health_check_results_check_idx on public.health_check_results (check_id, created_at desc);

alter table public.health_check_results enable row level security;

drop policy if exists "health_check_results_admin_all" on public.health_check_results;
create policy "health_check_results_admin_all"
on public.health_check_results
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create table if not exists public.brand_assets (
  key text primary key,
  bucket text not null,
  path text not null,
  public_url text not null,
  meta jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles (id) on delete set null
);

create index if not exists brand_assets_updated_idx on public.brand_assets (updated_at desc);

alter table public.brand_assets enable row level security;

drop policy if exists "brand_assets_read_public" on public.brand_assets;
create policy "brand_assets_read_public"
on public.brand_assets
for select
to anon, authenticated
using (true);

drop policy if exists "brand_assets_admin_write" on public.brand_assets;
create policy "brand_assets_admin_write"
on public.brand_assets
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create or replace function public.admin_get_database_size_bytes()
returns bigint
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;
  return pg_database_size(current_database());
end;
$$;

create or replace function public.admin_get_storage_usage_bytes()
returns bigint
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  total bigint;
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;

  if to_regclass('storage.objects') is null then
    return 0;
  end if;

  select coalesce(sum(nullif((metadata->>'size')::bigint, 0)), 0) into total
  from storage.objects;

  return coalesce(total, 0);
end;
$$;

create or replace function public.admin_security_audit()
returns table (
  id text,
  category text,
  status text,
  detail text,
  meta jsonb
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;

  return query
  select
    'rls.disabled.' || c.relname as id,
    'rls' as category,
    'broken' as status,
    'RLS is disabled on table ' || c.relname || '. Enable RLS and add policies.' as detail,
    jsonb_build_object('table', c.relname) as meta
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind = 'r'
    and coalesce(c.relrowsecurity, false) = false;

  return query
  select
    'policies.missing.' || t.table_name as id,
    'policies' as category,
    'warning' as status,
    'No RLS policies found for table ' || t.table_name || '. Add least-privilege policies.' as detail,
    jsonb_build_object('table', t.table_name) as meta
  from information_schema.tables t
  where t.table_schema = 'public'
    and t.table_type = 'BASE TABLE'
    and exists (
      select 1 from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relname = t.table_name and coalesce(c.relrowsecurity, false) = true
    )
    and not exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = t.table_name);

  return query
  select
    'policies.open.' || p.tablename || '.' || p.policyname as id,
    'policies' as category,
    'warning' as status,
    'Potentially open policy: ' || p.policyname || ' on ' || p.tablename || '. Review using/with_check clauses.' as detail,
    jsonb_build_object(
      'table', p.tablename,
      'policy', p.policyname,
      'roles', p.roles,
      'cmd', p.cmd,
      'qual', p.qual,
      'with_check', p.with_check
    ) as meta
  from pg_policies p
  where p.schemaname = 'public'
    and (coalesce(p.qual, '') ilike '%true%' or coalesce(p.with_check, '') ilike '%true%');
end;
$$;

commit;


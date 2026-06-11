create table if not exists public.role_requests (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  requested_role text not null check (requested_role in ('barber','shop_owner')),
  shop_name text,
  phone text,
  notes text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (profile_id, requested_role)
);

create index if not exists role_requests_status_idx on public.role_requests (status);
create index if not exists role_requests_profile_idx on public.role_requests (profile_id);

drop trigger if exists role_requests_set_updated_at on public.role_requests;
create trigger role_requests_set_updated_at
before update on public.role_requests
for each row execute function public.set_updated_at();

alter table public.role_requests enable row level security;

drop policy if exists "role_requests_insert_own" on public.role_requests;
create policy "role_requests_insert_own"
on public.role_requests
for insert
to authenticated
with check (profile_id = auth.uid());

drop policy if exists "role_requests_read_own" on public.role_requests;
create policy "role_requests_read_own"
on public.role_requests
for select
to authenticated
using (profile_id = auth.uid());

drop policy if exists "role_requests_admin_all" on public.role_requests;
create policy "role_requests_admin_all"
on public.role_requests
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "profiles_admin_read" on public.profiles;
create policy "profiles_admin_read"
on public.profiles
for select
to authenticated
using (public.is_admin());

drop policy if exists "profiles_admin_update" on public.profiles;
create policy "profiles_admin_update"
on public.profiles
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

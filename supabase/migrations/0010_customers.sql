create table if not exists public.customers (
  id uuid primary key references public.profiles (id) on delete cascade,
  full_name text not null default '',
  phone text not null default '',
  email text not null default '',
  language text not null default 'en',
  created_at timestamptz not null default now()
);

alter table public.customers enable row level security;

drop policy if exists "customers_read_own" on public.customers;
create policy "customers_read_own"
on public.customers
for select
to authenticated
using (id = auth.uid());

drop policy if exists "customers_insert_own" on public.customers;
create policy "customers_insert_own"
on public.customers
for insert
to authenticated
with check (
  id = auth.uid()
  and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'customer')
);

drop policy if exists "customers_update_own" on public.customers;
create policy "customers_update_own"
on public.customers
for update
to authenticated
using (id = auth.uid())
with check (
  id = auth.uid()
  and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'customer')
);

drop policy if exists "customers_admin_all" on public.customers;
create policy "customers_admin_all"
on public.customers
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());


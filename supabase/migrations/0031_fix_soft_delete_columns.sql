begin;

alter table public.barbershops add column if not exists deleted_at timestamptz;
alter table public.barbers add column if not exists deleted_at timestamptz;
alter table public.services add column if not exists deleted_at timestamptz;
alter table public.reels add column if not exists deleted_at timestamptz;

alter table public.barbershops
add column if not exists status text not null default 'pending'
check (status in ('pending','approved','suspended'));

create index if not exists barbershops_deleted_idx on public.barbershops (deleted_at);
create index if not exists barbers_deleted_idx on public.barbers (deleted_at);
create index if not exists services_deleted_idx on public.services (deleted_at);
create index if not exists reels_deleted_idx on public.reels (deleted_at);

create index if not exists barbershops_status_created_idx on public.barbershops (status, created_at desc);

drop policy if exists "shops_public_read" on public.barbershops;
create policy "shops_public_read"
on public.barbershops
for select
to anon, authenticated
using (
  public.is_admin()
  or owner_profile_id = auth.uid()
  or (deleted_at is null and status = 'approved')
);

drop view if exists public.shops;
create or replace view public.shops with (security_invoker = true) as
select
  id,
  owner_profile_id as owner_id,
  name,
  logo_url,
  cover_url,
  description,
  area,
  address,
  lat as latitude,
  lng as longitude,
  phone,
  whatsapp,
  instagram,
  opening_hours,
  status,
  is_verified,
  is_featured,
  created_at
from public.barbershops
where deleted_at is null;

commit;

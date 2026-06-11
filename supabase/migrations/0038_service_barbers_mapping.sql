begin;

create table if not exists public.service_barbers (
  service_id uuid not null references public.services (id) on delete cascade,
  barber_id uuid not null references public.barbers (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (service_id, barber_id)
);

create index if not exists service_barbers_barber_idx on public.service_barbers (barber_id);

alter table public.service_barbers enable row level security;

drop policy if exists "service_barbers_public_read" on public.service_barbers;
create policy "service_barbers_public_read"
on public.service_barbers
for select
to anon, authenticated
using (true);

drop policy if exists "service_barbers_manage_admin_or_shop_owner" on public.service_barbers;
create policy "service_barbers_manage_admin_or_shop_owner"
on public.service_barbers
for all
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.services s
    join public.barbershops sh on sh.id = s.shop_id
    join public.barbers b on b.id = service_barbers.barber_id
    where s.id = service_barbers.service_id
      and s.shop_id is not null
      and b.shop_id = s.shop_id
      and sh.owner_profile_id = auth.uid()
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.services s
    join public.barbershops sh on sh.id = s.shop_id
    join public.barbers b on b.id = barber_id
    where s.id = service_id
      and s.shop_id is not null
      and b.shop_id = s.shop_id
      and sh.owner_profile_id = auth.uid()
  )
);

create or replace view public.barber_services_effective with (security_invoker = true) as
select
  s.*,
  b.id as barber_ref
from public.services s
join public.barbers b on b.id = s.barber_id
where s.is_active = true and s.deleted_at is null
union all
select
  s.*,
  b.id as barber_ref
from public.services s
join public.barbers b on b.shop_id = s.shop_id
where s.barber_id is null
  and s.shop_id is not null
  and s.is_active = true
  and s.deleted_at is null
  and (
    not exists (select 1 from public.service_barbers sb where sb.service_id = s.id)
    or exists (select 1 from public.service_barbers sb where sb.service_id = s.id and sb.barber_id = b.id)
  );

commit;


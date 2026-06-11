alter table public.barbershops
  add column if not exists city_id uuid references public.cities (id) on delete set null;

alter table public.barbers
  add column if not exists city_id uuid references public.cities (id) on delete set null;

create index if not exists barbershops_city_id_idx on public.barbershops (city_id);
create index if not exists barbers_city_id_idx on public.barbers (city_id);

update public.barbershops s
set city_id = (
  select c.id
  from public.cities c
  where c.is_active = true
    and s.area is not null
    and s.area ilike '%' || c.name || '%'
  order by length(c.name) desc
  limit 1
)
where s.city_id is null;

update public.barbers b
set city_id = (
  select c.id
  from public.cities c
  where c.is_active = true
    and b.area is not null
    and b.area ilike '%' || c.name || '%'
  order by length(c.name) desc
  limit 1
)
where b.city_id is null;

update public.barbers b
set city_id = s.city_id
from public.barbershops s
where b.city_id is null
  and b.shop_id = s.id
  and s.city_id is not null;

begin;

create table if not exists public.cities (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  country text not null default 'Bahrain',
  lat double precision not null,
  lng double precision not null,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists cities_active_idx on public.cities (is_active, sort_order asc, created_at desc);

alter table public.cities enable row level security;

drop policy if exists "cities_read_public_active" on public.cities;
create policy "cities_read_public_active"
on public.cities
for select
to anon, authenticated
using (is_active = true);

drop policy if exists "cities_admin_all" on public.cities;
create policy "cities_admin_all"
on public.cities
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop trigger if exists cities_set_updated_at on public.cities;
create trigger cities_set_updated_at
before update on public.cities
for each row execute function public.set_updated_at();

insert into public.cities (name, country, lat, lng, is_active, sort_order)
values
  ('Manama', 'Bahrain', 26.2235, 50.5876, true, 0),
  ('Seef', 'Bahrain', 26.2326, 50.5468, true, 1),
  ('Juffair', 'Bahrain', 26.2147, 50.6025, true, 2),
  ('Riffa', 'Bahrain', 26.1297, 50.5552, true, 3),
  ('Muharraq', 'Bahrain', 26.2578, 50.6119, true, 4),
  ('Isa Town', 'Bahrain', 26.1749, 50.5473, true, 5),
  ('Saar', 'Bahrain', 26.2150, 50.4867, true, 6),
  ('Amwaj', 'Bahrain', 26.2850, 50.6569, true, 7),
  ('Hamad Town', 'Bahrain', 26.1153, 50.5063, true, 8),
  ('Sanabis', 'Bahrain', 26.2366, 50.5447, true, 9),
  ('Budaiya', 'Bahrain', 26.2063, 50.4568, true, 10)
on conflict (name) do update
set
  country = excluded.country,
  lat = excluded.lat,
  lng = excluded.lng,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order;

commit;

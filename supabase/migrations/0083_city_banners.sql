begin;

create table if not exists public.city_banners (
  id uuid primary key default gen_random_uuid(),
  title text not null default '',
  subtitle text not null default '',
  image_url text not null default '',
  href text not null default '/city',
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists city_banners_active_idx on public.city_banners (is_active, sort_order asc, created_at desc);

alter table public.city_banners enable row level security;

drop policy if exists "city_banners_read_public_active" on public.city_banners;
create policy "city_banners_read_public_active"
on public.city_banners
for select
to anon, authenticated
using (is_active = true);

drop policy if exists "city_banners_admin_all" on public.city_banners;
create policy "city_banners_admin_all"
on public.city_banners
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop trigger if exists city_banners_set_updated_at on public.city_banners;
create trigger city_banners_set_updated_at
before update on public.city_banners
for each row execute function public.set_updated_at();

insert into public.city_banners (title, subtitle, image_url, href, is_active, sort_order)
values (
  'Best Barber of the Week',
  'Ahmad Fade Studio',
  'https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Premium%20barber%20portrait%20close-up%2C%20Bahrain%20grooming%20editorial%2C%20clean%20white%20and%20gold%20luxury%20aesthetic%2C%20soft%20studio%20lighting%2C%20sharp%20skin%20fade%20haircut%2C%20high-end%20magazine%20photo%2C%2035mm%2C%20shallow%20depth%20of%20field%2C%20ultra%20detailed%2C%20photorealistic&image_size=landscape_16_9',
  '/city/trending',
  true,
  0
)
on conflict do nothing;

commit;


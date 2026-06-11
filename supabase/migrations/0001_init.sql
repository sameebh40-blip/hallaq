begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  full_name text,
  phone text,
  avatar_url text,
  cover_url text,
  my_barber_id uuid,
  role text not null default 'customer' check (role in ('customer','barber','shop_owner','admin')),
  verified boolean not null default false,
  status text not null default 'active' check (status in ('active','suspended','banned')),
  area text,
  lat double precision,
  lng double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profiles_role_idx on public.profiles (role);

alter table public.profiles enable row level security;

drop policy if exists "profiles_public_read" on public.profiles;
create policy "profiles_public_read"
on public.profiles
for select
to anon, authenticated
using (true);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles
for insert
to authenticated
with check (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create table if not exists public.barbershops (
  id uuid primary key default gen_random_uuid(),
  owner_profile_id uuid not null references public.profiles (id) on delete cascade,
  name text not null default '',
  description text,
  cover_url text,
  logo_url text,
  area text,
  address text,
  lat double precision,
  lng double precision,
  phone text,
  whatsapp text,
  instagram text,
  opening_hours jsonb not null default '{}'::jsonb,
  is_verified boolean not null default false,
  is_featured boolean not null default false,
  rating_avg numeric(3,2) not null default 0,
  rating_count int not null default 0,
  badge_verified boolean not null default false,
  badge_elite boolean not null default false,
  badge_trending boolean not null default false,
  badge_top_rated boolean not null default false,
  badge_certified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists barbershops_owner_idx on public.barbershops (owner_profile_id);
create index if not exists barbershops_location_idx on public.barbershops (lat, lng);

alter table public.barbershops enable row level security;

drop policy if exists "barbershops_public_read" on public.barbershops;
create policy "barbershops_public_read"
on public.barbershops
for select
to anon, authenticated
using (true);

drop policy if exists "barbershops_write_owner" on public.barbershops;
create policy "barbershops_write_owner"
on public.barbershops
for all
to authenticated
using (owner_profile_id = auth.uid())
with check (owner_profile_id = auth.uid());

drop trigger if exists barbershops_set_updated_at on public.barbershops;
create trigger barbershops_set_updated_at
before update on public.barbershops
for each row execute function public.set_updated_at();

create table if not exists public.barbers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  shop_id uuid references public.barbershops (id) on delete set null,
  slug text,
  display_name text not null default '',
  avatar_url text,
  cover_url text,
  bio text,
  specialty text,
  area text,
  address text,
  lat double precision,
  lng double precision,
  is_independent boolean not null default true,
  is_verified boolean not null default false,
  is_hallaq_certified boolean not null default false,
  rating_avg numeric(3,2) not null default 0,
  rating_count int not null default 0,
  followers_count int not null default 0,
  reviews_count int not null default 0,
  available_now boolean not null default false,
  waiting_time_min int,
  queue_length int,
  badge_verified boolean not null default false,
  badge_elite boolean not null default false,
  badge_trending boolean not null default false,
  badge_top_rated boolean not null default false,
  badge_certified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (profile_id)
);

create index if not exists barbers_shop_idx on public.barbers (shop_id);
create index if not exists barbers_location_idx on public.barbers (lat, lng);

alter table public.barbers enable row level security;

drop policy if exists "barbers_public_read" on public.barbers;
create policy "barbers_public_read"
on public.barbers
for select
to anon, authenticated
using (true);

drop policy if exists "barbers_write_owner" on public.barbers;
create policy "barbers_write_owner"
on public.barbers
for all
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

drop trigger if exists barbers_set_updated_at on public.barbers;
create trigger barbers_set_updated_at
before update on public.barbers
for each row execute function public.set_updated_at();

alter table public.profiles
drop constraint if exists profiles_my_barber_fk;
alter table public.profiles
add constraint profiles_my_barber_fk
foreign key (my_barber_id) references public.barbers (id) on delete set null;

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name_en text not null default '',
  name_ar text not null default '',
  created_at timestamptz not null default now()
);

alter table public.categories enable row level security;

create table if not exists public.advertisements (
  id uuid primary key default gen_random_uuid(),
  title text not null default '',
  image_url text,
  link_url text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.advertisements enable row level security;

create table if not exists public.featured_listings (
  id uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in ('barber','shop','reel')),
  target_id uuid not null,
  position int not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.featured_listings enable row level security;

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_profile_id uuid references public.profiles (id) on delete set null,
  entity_type text not null default 'generic',
  entity_id uuid,
  reason text,
  status text not null default 'open' check (status in ('open','resolved','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.reports enable row level security;

drop trigger if exists reports_set_updated_at on public.reports;
create trigger reports_set_updated_at
before update on public.reports
for each row execute function public.set_updated_at();

create table if not exists public.offers (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid references public.barbershops (id) on delete set null,
  barber_id uuid references public.barbers (id) on delete set null,
  title text not null default '',
  description text,
  discount_percent numeric(5,2),
  valid_from timestamptz,
  valid_to timestamptz,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.offers enable row level security;

drop trigger if exists offers_set_updated_at on public.offers;
create trigger offers_set_updated_at
before update on public.offers
for each row execute function public.set_updated_at();

create table if not exists public.haircut_history (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  barber_id uuid references public.barbers (id) on delete set null,
  cut_date date not null,
  style_name text,
  notes text,
  photo_urls text[] not null default '{}'::text[],
  created_at timestamptz not null default now()
);

alter table public.haircut_history enable row level security;

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid references public.barbershops (id) on delete set null,
  barber_id uuid references public.barbers (id) on delete set null,
  name_en text,
  name_ar text,
  description_en text,
  description_ar text,
  price_bhd numeric(10,3) not null default 0,
  duration_minutes int not null default 30,
  image_url text,
  category text,
  is_popular boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  owner_type text,
  owner_id uuid,
  name text,
  description text,
  price numeric(10,3),
  duration_min int,
  active boolean,
  deleted_at timestamptz
);

alter table public.services enable row level security;

drop policy if exists "services_public_read_active" on public.services;
create policy "services_public_read_active"
on public.services
for select
to anon, authenticated
using (is_active = true and deleted_at is null);

drop policy if exists "services_write_owner_basic" on public.services;
create policy "services_write_owner_basic"
on public.services
for all
to authenticated
using (
  (barber_id is not null and exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid()))
  or (shop_id is not null and exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid()))
)
with check (
  (barber_id is not null and exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid()))
  or (shop_id is not null and exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid()))
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  customer_profile_id uuid not null references public.profiles (id) on delete cascade,
  shop_id uuid references public.barbershops (id) on delete set null,
  barber_id uuid references public.barbers (id) on delete set null,
  service_id uuid references public.services (id) on delete set null,
  start_at timestamptz not null,
  end_at timestamptz not null,
  status text not null default 'pending' check (status in ('pending','confirmed','cancelled','completed')),
  notes text,
  total_price numeric(10,3),
  currency text not null default 'BHD',
  price_bhd numeric(10,3),
  duration_minutes int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists bookings_customer_idx on public.bookings (customer_profile_id, start_at desc);
create index if not exists bookings_shop_idx on public.bookings (shop_id, start_at desc);
create index if not exists bookings_barber_idx on public.bookings (barber_id, start_at desc);

alter table public.bookings enable row level security;

drop policy if exists "bookings_read_participants" on public.bookings;
create policy "bookings_read_participants"
on public.bookings
for select
to authenticated
using (
  customer_profile_id = auth.uid()
  or exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid())
  or exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid())
);

drop policy if exists "bookings_insert_customer" on public.bookings;
create policy "bookings_insert_customer"
on public.bookings
for insert
to authenticated
with check (customer_profile_id = auth.uid());

drop policy if exists "bookings_update_participants" on public.bookings;
create policy "bookings_update_participants"
on public.bookings
for update
to authenticated
using (
  customer_profile_id = auth.uid()
  or exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid())
  or exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid())
)
with check (
  customer_profile_id = auth.uid()
  or exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid())
  or exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid())
);

drop trigger if exists bookings_set_updated_at on public.bookings;
create trigger bookings_set_updated_at
before update on public.bookings
for each row execute function public.set_updated_at();

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  customer_profile_id uuid not null references public.profiles (id) on delete cascade,
  booking_id uuid references public.bookings (id) on delete set null,
  target_type text not null check (target_type in ('barber','shop')),
  target_id uuid not null,
  barber_id uuid references public.barbers (id) on delete set null,
  shop_id uuid references public.barbershops (id) on delete set null,
  rating int not null default 5 check (rating between 1 and 5),
  text text,
  comment text,
  photo_url text,
  image_url text,
  status text not null default 'published' check (status in ('pending','published','rejected')),
  created_at timestamptz not null default now()
);

alter table public.reviews enable row level security;

drop policy if exists "reviews_public_read_published" on public.reviews;
create policy "reviews_public_read_published"
on public.reviews
for select
to anon, authenticated
using (status = 'published');

drop policy if exists "reviews_insert_own" on public.reviews;
create policy "reviews_insert_own"
on public.reviews
for insert
to authenticated
with check (customer_profile_id = auth.uid());

create table if not exists public.reels (
  id uuid primary key default gen_random_uuid(),
  barber_id uuid references public.barbers (id) on delete set null,
  shop_id uuid references public.barbershops (id) on delete set null,
  media_type text not null default 'image' check (media_type in ('image','video')),
  media_url text,
  image_url text,
  video_url text,
  thumbnail_url text,
  caption text,
  location text,
  hashtags text[] not null default '{}'::text[],
  status text not null default 'approved' check (status in ('pending','approved','rejected')),
  approved_by uuid references public.profiles (id),
  approved_at timestamptz,
  rejected_by uuid references public.profiles (id),
  rejected_at timestamptz,
  rejection_reason text,
  is_featured boolean not null default false,
  is_sponsored boolean not null default false,
  likes_count int not null default 0,
  comments_count int not null default 0,
  saves_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.reels enable row level security;

drop policy if exists "reels_public_read_approved" on public.reels;
create policy "reels_public_read_approved"
on public.reels
for select
to anon, authenticated
using (status = 'approved');

drop policy if exists "reels_write_owner_basic" on public.reels;
create policy "reels_write_owner_basic"
on public.reels
for all
to authenticated
using (
  (barber_id is not null and exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid()))
  or (shop_id is not null and exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid()))
)
with check (
  (barber_id is not null and exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid()))
  or (shop_id is not null and exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid()))
);

drop trigger if exists reels_set_updated_at on public.reels;
create trigger reels_set_updated_at
before update on public.reels
for each row execute function public.set_updated_at();

create table if not exists public.reel_likes (
  id uuid primary key default gen_random_uuid(),
  reel_id uuid not null references public.reels (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (reel_id, profile_id)
);

alter table public.reel_likes enable row level security;

drop policy if exists "reel_likes_read_own" on public.reel_likes;
create policy "reel_likes_read_own"
on public.reel_likes
for select
to authenticated
using (profile_id = auth.uid());

drop policy if exists "reel_likes_write_own" on public.reel_likes;
create policy "reel_likes_write_own"
on public.reel_likes
for all
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

create table if not exists public.reel_comments (
  id uuid primary key default gen_random_uuid(),
  reel_id uuid not null references public.reels (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  text text not null default '',
  created_at timestamptz not null default now()
);

alter table public.reel_comments enable row level security;

drop policy if exists "reel_comments_public_read" on public.reel_comments;
create policy "reel_comments_public_read"
on public.reel_comments
for select
to anon, authenticated
using (true);

drop policy if exists "reel_comments_write_own" on public.reel_comments;
create policy "reel_comments_write_own"
on public.reel_comments
for all
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

create table if not exists public.follows (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  target_type text not null check (target_type in ('barber','shop')),
  target_id uuid not null,
  created_at timestamptz not null default now(),
  unique (profile_id, target_type, target_id)
);

alter table public.follows enable row level security;

drop policy if exists "follows_read_own" on public.follows;
create policy "follows_read_own"
on public.follows
for select
to authenticated
using (profile_id = auth.uid());

drop policy if exists "follows_write_own" on public.follows;
create policy "follows_write_own"
on public.follows
for all
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  target_type text not null check (target_type in ('barber','shop')),
  target_id uuid not null,
  created_at timestamptz not null default now(),
  unique (profile_id, target_type, target_id)
);

alter table public.favorites enable row level security;

drop policy if exists "favorites_read_own" on public.favorites;
create policy "favorites_read_own"
on public.favorites
for select
to authenticated
using (profile_id = auth.uid());

drop policy if exists "favorites_write_own" on public.favorites;
create policy "favorites_write_own"
on public.favorites
for all
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  type text not null default 'generic',
  title text not null default '',
  body text not null default '',
  data jsonb not null default '{}'::jsonb,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.notifications enable row level security;

drop policy if exists "notifications_read_own" on public.notifications;
create policy "notifications_read_own"
on public.notifications
for select
to authenticated
using (profile_id = auth.uid());

drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own"
on public.notifications
for update
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

drop policy if exists "notifications_insert_own" on public.notifications;
create policy "notifications_insert_own"
on public.notifications
for insert
to authenticated
with check (profile_id = auth.uid());

commit;

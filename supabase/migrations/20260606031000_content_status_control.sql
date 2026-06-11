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

alter table public.profiles add column if not exists role text not null default 'customer';
alter table public.profiles drop constraint if exists profiles_role_check;
update public.profiles
set role = case
  when role in ('customer','barber','shop_owner','admin') then role
  when role in ('shop','store_owner','owner') then 'shop_owner'
  when role in ('stylist') then 'barber'
  else 'customer'
end
where role is null or role not in ('customer','barber','shop_owner','admin');
alter table public.profiles
add constraint profiles_role_check
check (role in ('customer','barber','shop_owner','admin'));

create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  );
$$;

create table if not exists public.barbershops (
  id uuid primary key default gen_random_uuid(),
  owner_profile_id uuid not null references public.profiles (id) on delete cascade,
  name text not null default '',
  description text,
  area text,
  address text,
  cover_url text,
  cover_path text,
  logo_url text,
  logo_path text,
  phone text,
  whatsapp text,
  instagram text,
  opening_hours jsonb not null default '{}'::jsonb,
  is_verified boolean not null default false,
  is_featured boolean not null default false,
  rating_avg numeric(3,2) not null default 0,
  rating_count int not null default 0,
  deleted_at timestamptz,
  is_active boolean not null default true,
  status text not null default 'approved',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists barbershops_owner_idx on public.barbershops (owner_profile_id);

alter table public.barbershops enable row level security;

drop trigger if exists barbershops_set_updated_at on public.barbershops;
create trigger barbershops_set_updated_at
before update on public.barbershops
for each row execute function public.set_updated_at();

create table if not exists public.barbers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  shop_id uuid references public.barbershops (id) on delete set null,
  display_name text not null default '',
  bio text,
  specialty text,
  area text,
  address text,
  avatar_url text,
  avatar_path text,
  cover_url text,
  cover_path text,
  is_independent boolean not null default true,
  is_verified boolean not null default false,
  rating_avg numeric(3,2) not null default 0,
  rating_count int not null default 0,
  followers_count int not null default 0,
  reviews_count int not null default 0,
  available_now boolean not null default false,
  deleted_at timestamptz,
  is_active boolean not null default true,
  status text not null default 'approved',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (profile_id)
);

create index if not exists barbers_shop_idx on public.barbers (shop_id);

alter table public.barbers enable row level security;

drop trigger if exists barbers_set_updated_at on public.barbers;
create trigger barbers_set_updated_at
before update on public.barbers
for each row execute function public.set_updated_at();

create or replace function public.is_shop_owner(shop uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.barbershops s
    where s.id = shop and s.owner_profile_id = auth.uid()
  );
$$;

create or replace function public.is_barber_owner(barber uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.barbers b
    where b.id = barber and b.profile_id = auth.uid()
  );
$$;

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
  is_popular boolean not null default false,
  is_active boolean not null default true,
  status text not null default 'approved',
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.services enable row level security;

drop trigger if exists services_set_updated_at on public.services;
create trigger services_set_updated_at
before update on public.services
for each row execute function public.set_updated_at();

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid references public.barbershops (id) on delete cascade,
  name text not null default '',
  description text,
  price numeric(10,3) not null default 0,
  currency text not null default 'BHD',
  stock int not null default 0,
  images text[] not null default '{}'::text[],
  active boolean not null default true,
  is_active boolean not null default true,
  status text not null default 'approved',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.products enable row level security;

drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at
before update on public.products
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
  is_active boolean not null default true,
  status text not null default 'approved',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.offers enable row level security;

drop trigger if exists offers_set_updated_at on public.offers;
create trigger offers_set_updated_at
before update on public.offers
for each row execute function public.set_updated_at();

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  customer_profile_id uuid references public.profiles (id) on delete set null,
  target_type text not null default 'barber',
  target_id uuid,
  barber_id uuid references public.barbers (id) on delete set null,
  shop_id uuid references public.barbershops (id) on delete set null,
  rating int not null default 5 check (rating between 1 and 5),
  text text,
  comment text,
  status text not null default 'approved',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.reviews enable row level security;

create table if not exists public.style_library (
  id uuid primary key default gen_random_uuid(),
  slug text not null,
  name_en text not null default '',
  name_ar text not null default '',
  description_en text,
  description_ar text,
  category text,
  ai_style_key text,
  cover_url text,
  cover_path text,
  views_count bigint not null default 0,
  is_active boolean not null default true,
  status text not null default 'approved',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (slug)
);

alter table public.style_library enable row level security;

drop trigger if exists style_library_set_updated_at on public.style_library;
create trigger style_library_set_updated_at
before update on public.style_library
for each row execute function public.set_updated_at();

do $$
declare
  t regclass;
begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'reels' and c.relkind = 'r') then
    t := 'public.reels'::regclass;
  elsif exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'posts' and c.relkind = 'r') then
    t := 'public.posts'::regclass;
  else
    t := null;
  end if;

  if t is not null then
    execute format('alter table %s add column if not exists barber_id uuid', t);
    execute format('alter table %s add column if not exists shop_id uuid', t);
    execute format('alter table %s add column if not exists deleted_at timestamptz', t);
    execute format('alter table %s add column if not exists status text not null default ''approved''', t);
  end if;
end $$;

do $$
begin
  if exists (select 1 from pg_trigger where tgname = 'barbershops_shop_owner_update_guard' and tgrelid = 'public.barbershops'::regclass) then
    alter table public.barbershops disable trigger barbershops_shop_owner_update_guard;
  end if;
  if exists (select 1 from pg_trigger where tgname = 'barbers_shop_owner_assignment_guard' and tgrelid = 'public.barbers'::regclass) then
    alter table public.barbers disable trigger barbers_shop_owner_assignment_guard;
  end if;
  if exists (select 1 from pg_trigger where tgname = 'reviews_guard_updates' and tgrelid = 'public.reviews'::regclass) then
    alter table public.reviews disable trigger reviews_guard_updates;
  end if;
end $$;

alter table public.barbershops add column if not exists is_active boolean not null default true;
alter table public.barbershops alter column is_active set default true;

alter table public.barbershops add column if not exists status text;
alter table public.barbershops drop constraint if exists barbershops_status_check;
update public.barbershops
set status = case
  when status = 'suspended' then 'hidden'
  when status is null then 'approved'
  else status
end;
alter table public.barbershops alter column status set not null;
alter table public.barbershops alter column status set default 'approved';
alter table public.barbershops
add constraint barbershops_status_check
check (status in ('draft','pending','approved','hidden','archived','rejected'));

drop policy if exists "shops_public_read" on public.barbershops;
create policy "shops_public_read"
on public.barbershops
for select
to anon, authenticated
using (
  public.is_admin()
  or owner_profile_id = auth.uid()
  or (deleted_at is null and is_active = true and status = 'approved')
);

alter table public.barbers add column if not exists is_active boolean not null default true;
alter table public.barbers alter column is_active set default true;

alter table public.barbers add column if not exists status text;
alter table public.barbers drop constraint if exists barbers_status_check;
update public.barbers
set status = case
  when status = 'active' then 'approved'
  when status = 'suspended' then 'hidden'
  when status is null then 'approved'
  else status
end;
alter table public.barbers alter column status set not null;
alter table public.barbers alter column status set default 'approved';
alter table public.barbers
add constraint barbers_status_check
check (status in ('draft','pending','approved','hidden','archived','rejected'));

drop policy if exists "barbers_public_read" on public.barbers;
create policy "barbers_public_read"
on public.barbers
for select
to anon, authenticated
using (
  public.is_admin()
  or profile_id = auth.uid()
  or (shop_id is not null and exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid()))
  or (deleted_at is null and is_active = true and status = 'approved' and is_verified = true)
);

alter table public.services add column if not exists status text;
update public.services set status = coalesce(status, 'approved');
alter table public.services alter column status set not null;
alter table public.services alter column status set default 'approved';
alter table public.services drop constraint if exists services_status_check;
alter table public.services
add constraint services_status_check
check (status in ('draft','pending','approved','hidden','archived','rejected'));

drop policy if exists "services_public_read_active" on public.services;
create policy "services_public_read_active"
on public.services
for select
to anon, authenticated
using (
  public.is_admin()
  or (is_active = true and deleted_at is null and status = 'approved')
);

alter table public.products add column if not exists is_active boolean;
update public.products set is_active = coalesce(is_active, active, true);
alter table public.products alter column is_active set not null;
alter table public.products alter column is_active set default true;

alter table public.products add column if not exists status text;
update public.products set status = coalesce(status, 'approved');
alter table public.products alter column status set not null;
alter table public.products alter column status set default 'approved';
alter table public.products drop constraint if exists products_status_check;
alter table public.products
add constraint products_status_check
check (status in ('draft','pending','approved','hidden','archived','rejected'));

drop policy if exists "products_public_read_active" on public.products;
create policy "products_public_read_active"
on public.products
for select
to anon, authenticated
using (
  public.is_admin()
  or public.is_shop_owner(shop_id)
  or (is_active = true and active = true and status = 'approved')
);

alter table public.offers add column if not exists is_active boolean;
update public.offers set is_active = coalesce(is_active, active, true);
alter table public.offers alter column is_active set not null;
alter table public.offers alter column is_active set default true;

alter table public.offers add column if not exists status text;
update public.offers set status = coalesce(status, 'approved');
alter table public.offers alter column status set not null;
alter table public.offers alter column status set default 'approved';
alter table public.offers drop constraint if exists offers_status_check;
alter table public.offers
add constraint offers_status_check
check (status in ('draft','pending','approved','hidden','archived','rejected'));

drop policy if exists "offers_read_active" on public.offers;
create policy "offers_read_active"
on public.offers
for select
to anon, authenticated
using (
  public.is_admin()
  or (is_active = true and active = true and status = 'approved')
);

alter table public.reviews add column if not exists is_active boolean not null default true;
alter table public.reviews alter column is_active set default true;

alter table public.reviews add column if not exists status text;
alter table public.reviews drop constraint if exists reviews_status_check;
update public.reviews
set status = case
  when status = 'published' then 'approved'
  when status is null then 'approved'
  else status
end;
alter table public.reviews alter column status set not null;
alter table public.reviews alter column status set default 'approved';
alter table public.reviews
add constraint reviews_status_check
check (status in ('draft','pending','approved','hidden','archived','rejected'));

drop policy if exists "reviews_public_read" on public.reviews;
create policy "reviews_public_read"
on public.reviews
for select
to anon, authenticated
using (public.is_admin() or (status = 'approved' and is_active = true));

alter table public.style_library add column if not exists status text;
update public.style_library set status = coalesce(status, 'approved');
alter table public.style_library alter column status set not null;
alter table public.style_library alter column status set default 'approved';
alter table public.style_library drop constraint if exists style_library_status_check;
alter table public.style_library
add constraint style_library_status_check
check (status in ('draft','pending','approved','hidden','archived','rejected'));

drop policy if exists "style_library_public_read_active" on public.style_library;
create policy "style_library_public_read_active"
on public.style_library
for select
to anon, authenticated
using (public.is_admin() or (is_active = true and status = 'approved'));

do $$
declare
  t regclass;
begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'reels' and c.relkind = 'r') then
    t := 'public.reels'::regclass;
  elsif exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'posts' and c.relkind = 'r') then
    t := 'public.posts'::regclass;
  else
    t := null;
  end if;

  if t is not null then
    execute format('alter table %s drop constraint if exists reels_status_check', t);
    execute format(
      'alter table %s add constraint reels_status_check check (status in (''draft'',''pending'',''approved'',''hidden'',''archived'',''rejected''))',
      t
    );
    execute format('drop policy if exists "reels_public_read" on %s', t);
    execute format(
      'create policy "reels_public_read" on %s for select to anon, authenticated using (public.is_admin() or (deleted_at is null and status = ''approved'') or (barber_id is not null and exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid())) or (shop_id is not null and exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid())))',
      t
    );
  end if;
end $$;

do $$
begin
  if exists (select 1 from pg_trigger where tgname = 'barbershops_shop_owner_update_guard' and tgrelid = 'public.barbershops'::regclass) then
    alter table public.barbershops enable trigger barbershops_shop_owner_update_guard;
  end if;
  if exists (select 1 from pg_trigger where tgname = 'barbers_shop_owner_assignment_guard' and tgrelid = 'public.barbers'::regclass) then
    alter table public.barbers enable trigger barbers_shop_owner_assignment_guard;
  end if;
  if exists (select 1 from pg_trigger where tgname = 'reviews_guard_updates' and tgrelid = 'public.reviews'::regclass) then
    alter table public.reviews enable trigger reviews_guard_updates;
  end if;
end $$;

commit;

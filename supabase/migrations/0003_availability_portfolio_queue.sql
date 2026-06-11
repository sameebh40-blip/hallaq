create table if not exists public.barber_working_hours (
  id uuid primary key default gen_random_uuid(),
  barber_id uuid not null references public.barbers (id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  start_time time not null,
  end_time time not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (barber_id, weekday, start_time, end_time)
);

drop trigger if exists barber_working_hours_set_updated_at on public.barber_working_hours;
create trigger barber_working_hours_set_updated_at
before update on public.barber_working_hours
for each row execute function public.set_updated_at();

create table if not exists public.barber_time_off (
  id uuid primary key default gen_random_uuid(),
  barber_id uuid not null references public.barbers (id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  reason text,
  created_at timestamptz not null default now()
);

create index if not exists barber_time_off_barber_idx on public.barber_time_off (barber_id, starts_at desc);

create table if not exists public.shop_working_hours (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.barbershops (id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  start_time time not null,
  end_time time not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, weekday, start_time, end_time)
);

drop trigger if exists shop_working_hours_set_updated_at on public.shop_working_hours;
create trigger shop_working_hours_set_updated_at
before update on public.shop_working_hours
for each row execute function public.set_updated_at();

create table if not exists public.portfolio_items (
  id uuid primary key default gen_random_uuid(),
  owner_type text not null check (owner_type in ('barber','shop')),
  owner_id uuid not null,
  media_type text not null check (media_type in ('image','video')),
  media_url text not null,
  thumbnail_url text,
  caption text,
  created_at timestamptz not null default now()
);

create index if not exists portfolio_owner_idx on public.portfolio_items (owner_type, owner_id, created_at desc);

create table if not exists public.queue_status (
  id uuid primary key default gen_random_uuid(),
  owner_type text not null check (owner_type in ('barber','shop')),
  owner_id uuid not null,
  is_open boolean not null default false,
  queue_length int not null default 0,
  waiting_time_min int,
  updated_at timestamptz not null default now(),
  unique (owner_type, owner_id)
);

create or replace function public.touch_queue_status_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists queue_status_touch_updated_at on public.queue_status;
create trigger queue_status_touch_updated_at
before update on public.queue_status
for each row execute function public.touch_queue_status_updated_at();

alter table public.barber_working_hours enable row level security;
alter table public.barber_time_off enable row level security;
alter table public.shop_working_hours enable row level security;
alter table public.portfolio_items enable row level security;
alter table public.queue_status enable row level security;

drop policy if exists "barber_working_hours_read_public" on public.barber_working_hours;
create policy "barber_working_hours_read_public"
on public.barber_working_hours
for select
to anon, authenticated
using (true);

drop policy if exists "barber_working_hours_write_owner" on public.barber_working_hours;
create policy "barber_working_hours_write_owner"
on public.barber_working_hours
for all
to authenticated
using (public.is_barber_owner(barber_id))
with check (public.is_barber_owner(barber_id));

drop policy if exists "barber_working_hours_admin_all" on public.barber_working_hours;
create policy "barber_working_hours_admin_all"
on public.barber_working_hours
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "barber_time_off_read_owner" on public.barber_time_off;
create policy "barber_time_off_read_owner"
on public.barber_time_off
for select
to authenticated
using (public.is_barber_owner(barber_id) or public.is_admin());

drop policy if exists "barber_time_off_write_owner" on public.barber_time_off;
create policy "barber_time_off_write_owner"
on public.barber_time_off
for all
to authenticated
using (public.is_barber_owner(barber_id) or public.is_admin())
with check (public.is_barber_owner(barber_id) or public.is_admin());

drop policy if exists "shop_working_hours_read_public" on public.shop_working_hours;
create policy "shop_working_hours_read_public"
on public.shop_working_hours
for select
to anon, authenticated
using (true);

drop policy if exists "shop_working_hours_write_owner" on public.shop_working_hours;
create policy "shop_working_hours_write_owner"
on public.shop_working_hours
for all
to authenticated
using (public.is_shop_owner(shop_id) or public.is_admin())
with check (public.is_shop_owner(shop_id) or public.is_admin());

drop policy if exists "portfolio_items_public_read" on public.portfolio_items;
create policy "portfolio_items_public_read"
on public.portfolio_items
for select
to anon, authenticated
using (true);

drop policy if exists "portfolio_items_write_owner" on public.portfolio_items;
create policy "portfolio_items_write_owner"
on public.portfolio_items
for insert
to authenticated
with check (
  (owner_type = 'barber' and public.is_barber_owner(owner_id))
  or (owner_type = 'shop' and public.is_shop_owner(owner_id))
  or public.is_admin()
);

drop policy if exists "portfolio_items_update_owner" on public.portfolio_items;
create policy "portfolio_items_update_owner"
on public.portfolio_items
for update
to authenticated
using (
  (owner_type = 'barber' and public.is_barber_owner(owner_id))
  or (owner_type = 'shop' and public.is_shop_owner(owner_id))
  or public.is_admin()
)
with check (
  (owner_type = 'barber' and public.is_barber_owner(owner_id))
  or (owner_type = 'shop' and public.is_shop_owner(owner_id))
  or public.is_admin()
);

drop policy if exists "portfolio_items_delete_owner" on public.portfolio_items;
create policy "portfolio_items_delete_owner"
on public.portfolio_items
for delete
to authenticated
using (
  (owner_type = 'barber' and public.is_barber_owner(owner_id))
  or (owner_type = 'shop' and public.is_shop_owner(owner_id))
  or public.is_admin()
);

drop policy if exists "queue_status_public_read" on public.queue_status;
create policy "queue_status_public_read"
on public.queue_status
for select
to anon, authenticated
using (true);

drop policy if exists "queue_status_write_owner" on public.queue_status;
create policy "queue_status_write_owner"
on public.queue_status
for all
to authenticated
using (
  (owner_type = 'barber' and public.is_barber_owner(owner_id))
  or (owner_type = 'shop' and public.is_shop_owner(owner_id))
  or public.is_admin()
)
with check (
  (owner_type = 'barber' and public.is_barber_owner(owner_id))
  or (owner_type = 'shop' and public.is_shop_owner(owner_id))
  or public.is_admin()
);

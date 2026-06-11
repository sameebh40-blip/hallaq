begin;

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
add constraint profiles_role_check
check (role in ('customer','barber','shop_owner','admin','receptionist'));

create table if not exists public.shop_branches (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.barbershops (id) on delete cascade,
  name text not null,
  area text,
  address text,
  lat double precision,
  lng double precision,
  opening_hours jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, name)
);

create index if not exists shop_branches_shop_idx on public.shop_branches (shop_id, created_at desc);

alter table public.shop_branches enable row level security;

drop policy if exists "shop_branches_public_read" on public.shop_branches;
create policy "shop_branches_public_read"
on public.shop_branches
for select
to anon, authenticated
using (true);

drop policy if exists "shop_branches_write_owner" on public.shop_branches;
create policy "shop_branches_write_owner"
on public.shop_branches
for all
to authenticated
using (public.is_admin() or public.is_shop_owner(shop_id))
with check (public.is_admin() or public.is_shop_owner(shop_id));

drop trigger if exists shop_branches_set_updated_at on public.shop_branches;
create trigger shop_branches_set_updated_at
before update on public.shop_branches
for each row execute function public.set_updated_at();

insert into public.shop_branches (shop_id, name, area, address, lat, lng, opening_hours)
select s.id, 'Main Branch', s.area, s.address, s.lat, s.lng, coalesce(s.opening_hours, '{}'::jsonb)
from public.barbershops s
where not exists (select 1 from public.shop_branches b where b.shop_id = s.id)
on conflict (shop_id, name) do nothing;

alter table public.barbers
add column if not exists branch_id uuid references public.shop_branches (id) on delete set null;

update public.barbers b
set branch_id = sb.id
from public.shop_branches sb
where b.shop_id is not null
  and b.branch_id is null
  and sb.shop_id = b.shop_id
  and sb.name = 'Main Branch';

update public.barbers
set branch_id = null
where shop_id is null
  and branch_id is not null;

alter table public.barbers drop constraint if exists barbers_shop_branch_check;
alter table public.barbers
add constraint barbers_shop_branch_check
check (
  (shop_id is null and branch_id is null)
  or (shop_id is not null and branch_id is not null)
) not valid;

alter table public.barbers validate constraint barbers_shop_branch_check;

create index if not exists barbers_branch_idx on public.barbers (branch_id, created_at desc);

alter table public.bookings
add column if not exists branch_id uuid references public.shop_branches (id) on delete set null,
add column if not exists customer_name text,
add column if not exists customer_phone text;

alter table public.bookings alter column customer_profile_id drop not null;

update public.bookings bk
set branch_id = sb.id
from public.shop_branches sb
where bk.shop_id is not null
  and bk.branch_id is null
  and sb.shop_id = bk.shop_id
  and sb.name = 'Main Branch';

alter table public.bookings drop constraint if exists bookings_customer_required_check;
alter table public.bookings
add constraint bookings_customer_required_check
check (
  customer_profile_id is not null
  or (customer_name is not null and length(trim(customer_name)) > 0 and customer_phone is not null and length(trim(customer_phone)) > 0)
) not valid;

alter table public.bookings validate constraint bookings_customer_required_check;

alter table public.bookings drop constraint if exists bookings_branch_required_check;
alter table public.bookings
add constraint bookings_branch_required_check
check (
  shop_id is null
  or branch_id is not null
) not valid;

alter table public.bookings validate constraint bookings_branch_required_check;

create index if not exists bookings_branch_idx on public.bookings (branch_id, start_at desc);

create table if not exists public.shop_staff (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.barbershops (id) on delete cascade,
  branch_id uuid not null references public.shop_branches (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  staff_role text not null check (staff_role in ('receptionist')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, branch_id, profile_id, staff_role)
);

create index if not exists shop_staff_profile_idx on public.shop_staff (profile_id, created_at desc);
create index if not exists shop_staff_shop_branch_idx on public.shop_staff (shop_id, branch_id, created_at desc);

alter table public.shop_staff enable row level security;

drop policy if exists "shop_staff_read_own" on public.shop_staff;
create policy "shop_staff_read_own"
on public.shop_staff
for select
to authenticated
using (profile_id = auth.uid() or public.is_admin() or public.is_shop_owner(shop_id));

drop policy if exists "shop_staff_write_owner" on public.shop_staff;
create policy "shop_staff_write_owner"
on public.shop_staff
for all
to authenticated
using (public.is_admin() or public.is_shop_owner(shop_id))
with check (public.is_admin() or public.is_shop_owner(shop_id));

drop trigger if exists shop_staff_set_updated_at on public.shop_staff;
create trigger shop_staff_set_updated_at
before update on public.shop_staff
for each row execute function public.set_updated_at();

create or replace function public.is_branch_staff(branch uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.shop_staff ss
    where ss.branch_id = branch
      and ss.profile_id = auth.uid()
  );
$$;

drop policy if exists "bookings_read_participants" on public.bookings;
create policy "bookings_read_participants"
on public.bookings
for select
to authenticated
using (
  customer_profile_id = auth.uid()
  or exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid())
  or exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid())
  or (branch_id is not null and public.is_branch_staff(branch_id))
);

drop policy if exists "bookings_update_participants" on public.bookings;
create policy "bookings_update_participants"
on public.bookings
for update
to authenticated
using (
  customer_profile_id = auth.uid()
  or exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid())
  or exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid())
  or (branch_id is not null and public.is_branch_staff(branch_id))
)
with check (
  customer_profile_id = auth.uid()
  or exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid())
  or exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid())
  or (branch_id is not null and public.is_branch_staff(branch_id))
);

create or replace function public.bookings_guard_reception_updates()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if exists (select 1 from public.barbers b where b.id = old.barber_id and b.profile_id = auth.uid()) then
    return new;
  end if;

  if old.shop_id is not null and exists (select 1 from public.barbershops s where s.id = old.shop_id and s.owner_profile_id = auth.uid()) then
    return new;
  end if;

  if old.branch_id is null or not public.is_branch_staff(old.branch_id) then
    return new;
  end if;

  if (
    new.total_price is distinct from old.total_price
    or new.currency is distinct from old.currency
    or new.price_bhd is distinct from old.price_bhd
    or new.duration_minutes is distinct from old.duration_minutes
  ) then
    raise exception 'Not allowed';
  end if;

  if (
    new.shop_id is distinct from old.shop_id
    or new.branch_id is distinct from old.branch_id
    or new.barber_id is distinct from old.barber_id
    or new.service_id is distinct from old.service_id
    or new.customer_profile_id is distinct from old.customer_profile_id
  ) then
    raise exception 'Not allowed';
  end if;

  return new;
end;
$$;

drop trigger if exists bookings_guard_reception_updates on public.bookings;
create trigger bookings_guard_reception_updates
before update on public.bookings
for each row execute function public.bookings_guard_reception_updates();

create or replace function public.create_booking(
  service_id uuid,
  start_at timestamptz,
  barber_id uuid,
  shop_id uuid default null,
  notes text default null
)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_barber_shop_id uuid;
  v_barber_branch_id uuid;
  v_service record;
  v_shop_id uuid;
  v_branch_id uuid;
  v_duration int;
  v_price numeric(10,3);
  v_end_at timestamptz;
  v_buffer int := 0;
  v_booking public.bookings%rowtype;
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  if barber_id is null then
    raise exception using message = 'INVALID_BARBER';
  end if;

  select b.shop_id, b.branch_id
  into v_barber_shop_id, v_barber_branch_id
  from public.barbers b
  where b.id = barber_id;

  if v_barber_shop_id is null and shop_id is not null then
    raise exception using message = 'INVALID_SHOP';
  end if;

  v_shop_id := coalesce(shop_id, v_barber_shop_id);

  if v_shop_id is not null then
    v_branch_id := v_barber_branch_id;
    if v_branch_id is null then
      select sb.id
      into v_branch_id
      from public.shop_branches sb
      where sb.shop_id = v_shop_id
      order by sb.created_at asc
      limit 1;
    end if;
    if v_branch_id is null then
      raise exception using message = 'BRANCH_NOT_FOUND';
    end if;
  else
    v_branch_id := null;
  end if;

  select
    s.id,
    s.shop_id,
    s.barber_id,
    s.is_active,
    s.deleted_at,
    s.price_bhd,
    s.duration_minutes,
    s.price,
    s.duration_min
  into v_service
  from public.services s
  where s.id = service_id
  limit 1;

  if v_service.id is null then
    raise exception using message = 'SERVICE_NOT_FOUND';
  end if;

  if v_service.deleted_at is not null or v_service.is_active is not true then
    raise exception using message = 'SERVICE_INACTIVE';
  end if;

  if v_service.barber_id is not null and v_service.barber_id <> barber_id then
    raise exception using message = 'SERVICE_NOT_FOR_BARBER';
  end if;

  if v_service.shop_id is not null then
    v_shop_id := coalesce(v_shop_id, v_service.shop_id);
    if v_shop_id <> v_service.shop_id then
      raise exception using message = 'SERVICE_NOT_FOR_SHOP';
    end if;
    if v_barber_shop_id is distinct from v_service.shop_id then
      raise exception using message = 'BARBER_NOT_IN_SHOP';
    end if;
  end if;

  v_duration := coalesce(v_service.duration_minutes, v_service.duration_min, 30);
  if v_duration <= 0 then
    raise exception using message = 'INVALID_DURATION';
  end if;

  v_price := coalesce(v_service.price_bhd, v_service.price, 0)::numeric(10,3);
  v_end_at := start_at + make_interval(mins => v_duration);

  select coalesce(br.buffer_minutes, s.buffer_minutes, 0)
  into v_buffer
  from public.barbers br
  left join public.barbershops s on s.id = br.shop_id
  where br.id = barber_id;

  if exists (
    select 1
    from public.barber_time_off t
    where t.barber_id = barber_id
      and tstzrange(t.starts_at, t.ends_at, '[)') && tstzrange(start_at, v_end_at, '[)')
  ) then
    raise exception using message = 'BARBER_TIME_OFF';
  end if;

  if exists (
    select 1
    from public.bookings b
    where b.barber_id = barber_id
      and b.status in ('pending','confirmed')
      and tstzrange(b.start_at, b.end_at + make_interval(mins => v_buffer), '[)') && tstzrange(start_at, v_end_at, '[)')
  ) then
    raise exception using message = 'BOOKING_OVERLAP';
  end if;

  insert into public.bookings (
    customer_profile_id,
    customer_name,
    customer_phone,
    shop_id,
    branch_id,
    barber_id,
    service_id,
    start_at,
    end_at,
    status,
    notes,
    total_price,
    currency,
    price_bhd,
    duration_minutes
  )
  values (
    v_user,
    null,
    null,
    v_shop_id,
    v_branch_id,
    barber_id,
    service_id,
    start_at,
    v_end_at,
    'pending',
    notes,
    v_price,
    'BHD',
    v_price,
    v_duration
  )
  returning * into v_booking;

  return v_booking;
end;
$$;

create or replace function public.create_reception_booking(
  service_id uuid,
  start_at timestamptz,
  barber_id uuid,
  shop_id uuid,
  branch_id uuid,
  customer_profile_id uuid default null,
  customer_name text default null,
  customer_phone text default null,
  notes text default null
)
returns public.bookings
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_actor uuid;
  v_barber_shop_id uuid;
  v_barber_branch_id uuid;
  v_service record;
  v_duration int;
  v_price numeric(10,3);
  v_end_at timestamptz;
  v_buffer int := 0;
  v_booking public.bookings%rowtype;
begin
  v_actor := auth.uid();
  if v_actor is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  if not (public.is_admin() or public.is_shop_owner(shop_id) or public.is_branch_staff(branch_id)) then
    raise exception using message = 'NOT_ALLOWED';
  end if;

  select b.shop_id, b.branch_id
  into v_barber_shop_id, v_barber_branch_id
  from public.barbers b
  where b.id = barber_id;

  if v_barber_shop_id is distinct from shop_id then
    raise exception using message = 'BARBER_NOT_IN_SHOP';
  end if;
  if v_barber_branch_id is distinct from branch_id then
    raise exception using message = 'BARBER_NOT_IN_BRANCH';
  end if;

  select
    s.id,
    s.shop_id,
    s.barber_id,
    s.is_active,
    s.deleted_at,
    s.price_bhd,
    s.duration_minutes,
    s.price,
    s.duration_min
  into v_service
  from public.services s
  where s.id = service_id
  limit 1;

  if v_service.id is null then
    raise exception using message = 'SERVICE_NOT_FOUND';
  end if;

  if v_service.deleted_at is not null or v_service.is_active is not true then
    raise exception using message = 'SERVICE_INACTIVE';
  end if;

  if v_service.barber_id is not null and v_service.barber_id <> barber_id then
    raise exception using message = 'SERVICE_NOT_FOR_BARBER';
  end if;

  if v_service.shop_id is not null and v_service.shop_id <> shop_id then
    raise exception using message = 'SERVICE_NOT_FOR_SHOP';
  end if;

  if customer_profile_id is null then
    if customer_name is null or length(trim(customer_name)) = 0 then
      raise exception using message = 'CUSTOMER_NAME_REQUIRED';
    end if;
    if customer_phone is null or length(trim(customer_phone)) = 0 then
      raise exception using message = 'CUSTOMER_PHONE_REQUIRED';
    end if;
  end if;

  v_duration := coalesce(v_service.duration_minutes, v_service.duration_min, 30);
  if v_duration <= 0 then
    raise exception using message = 'INVALID_DURATION';
  end if;

  v_price := coalesce(v_service.price_bhd, v_service.price, 0)::numeric(10,3);
  v_end_at := start_at + make_interval(mins => v_duration);

  select coalesce(br.buffer_minutes, s.buffer_minutes, 0)
  into v_buffer
  from public.barbers br
  left join public.barbershops s on s.id = br.shop_id
  where br.id = barber_id;

  if exists (
    select 1
    from public.barber_time_off t
    where t.barber_id = barber_id
      and tstzrange(t.starts_at, t.ends_at, '[)') && tstzrange(start_at, v_end_at, '[)')
  ) then
    raise exception using message = 'BARBER_TIME_OFF';
  end if;

  if exists (
    select 1
    from public.bookings b
    where b.barber_id = barber_id
      and b.status in ('pending','confirmed')
      and tstzrange(b.start_at, b.end_at + make_interval(mins => v_buffer), '[)') && tstzrange(start_at, v_end_at, '[)')
  ) then
    raise exception using message = 'BOOKING_OVERLAP';
  end if;

  insert into public.bookings (
    customer_profile_id,
    customer_name,
    customer_phone,
    shop_id,
    branch_id,
    barber_id,
    service_id,
    start_at,
    end_at,
    status,
    notes,
    total_price,
    currency,
    price_bhd,
    duration_minutes
  )
  values (
    customer_profile_id,
    customer_name,
    customer_phone,
    shop_id,
    branch_id,
    barber_id,
    service_id,
    start_at,
    v_end_at,
    'confirmed',
    notes,
    v_price,
    'BHD',
    v_price,
    v_duration
  )
  returning * into v_booking;

  return v_booking;
end;
$$;

do $$
begin
  if to_regprocedure('public.create_reception_booking(uuid, timestamptz, uuid, uuid, uuid, uuid, text, text, text)') is not null then
    revoke all on function public.create_reception_booking(uuid, timestamptz, uuid, uuid, uuid, uuid, text, text, text) from public;
  end if;

  if to_regprocedure('public.create_reception_booking(uuid, timestamptz, uuid, uuid, uuid, uuid, text, text, text)') is not null
     and exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.create_reception_booking(uuid, timestamptz, uuid, uuid, uuid, uuid, text, text, text) to authenticated;
  end if;
end;
$$;

commit;

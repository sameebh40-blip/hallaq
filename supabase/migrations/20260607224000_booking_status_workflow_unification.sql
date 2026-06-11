begin;

alter table public.bookings add column if not exists confirmed_at timestamptz;
alter table public.bookings add column if not exists started_at timestamptz;
alter table public.bookings add column if not exists completed_at timestamptz;
alter table public.bookings add column if not exists no_show_at timestamptz;
alter table public.bookings add column if not exists barber_profile_id uuid references public.profiles (id) on delete set null;
alter table public.bookings add column if not exists shop_owner_profile_id uuid references public.profiles (id) on delete set null;

create index if not exists bookings_barber_profile_idx on public.bookings (barber_profile_id, start_at desc);
create index if not exists bookings_shop_owner_profile_idx on public.bookings (shop_owner_profile_id, start_at desc);

create or replace function public.bookings_set_participants()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  if new.barber_id is not null then
    select b.profile_id into new.barber_profile_id from public.barbers b where b.id = new.barber_id;
  else
    new.barber_profile_id := null;
  end if;

  if new.shop_id is not null then
    select s.owner_profile_id into new.shop_owner_profile_id from public.barbershops s where s.id = new.shop_id;
  else
    new.shop_owner_profile_id := null;
  end if;

  return new;
end;
$$;

drop trigger if exists bookings_set_participants on public.bookings;
create trigger bookings_set_participants
before insert or update of barber_id, shop_id on public.bookings
for each row execute function public.bookings_set_participants();

create or replace function public.bookings_prepare_insert()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_barber record;
  v_shop record;
  v_service record;
  v_duration int;
  v_price numeric(10,3);
  v_deposit_required numeric(10,3) := 0;
  v_deposit_type text;
  v_deposit_value numeric(10,3);
begin
  if new.start_at is null then
    raise exception using message = 'INVALID_START_AT';
  end if;
  if new.barber_id is null then
    raise exception using message = 'INVALID_BARBER';
  end if;
  if new.service_id is null then
    raise exception using message = 'SERVICE_NOT_FOUND';
  end if;

  select id, shop_id, deleted_at, is_active, status
  into v_barber
  from public.barbers
  where id = new.barber_id
  limit 1;

  if v_barber.id is null then
    raise exception using message = 'INVALID_BARBER';
  end if;
  if v_barber.deleted_at is not null or v_barber.is_active is not true or v_barber.status <> 'approved' then
    raise exception using message = 'BARBER_INACTIVE';
  end if;

  if new.shop_id is null then
    new.shop_id := v_barber.shop_id;
  end if;

  if new.shop_id is not null and v_barber.shop_id is not null and new.shop_id <> v_barber.shop_id then
    raise exception using message = 'BARBER_NOT_IN_SHOP';
  end if;

  if new.shop_id is not null then
    select id, deleted_at, is_active, status
    into v_shop
    from public.barbershops
    where id = new.shop_id
    limit 1;
    if v_shop.id is null then
      raise exception using message = 'INVALID_SHOP';
    end if;
    if v_shop.deleted_at is not null or v_shop.is_active is not true or v_shop.status <> 'approved' then
      raise exception using message = 'SHOP_INACTIVE';
    end if;
  end if;

  select
    id,
    shop_id,
    barber_id,
    deleted_at,
    is_active,
    status,
    price_bhd,
    price,
    duration_minutes,
    duration_min,
    deposit_type,
    deposit_value
  into v_service
  from public.services
  where id = new.service_id
  limit 1;

  if v_service.id is null then
    raise exception using message = 'SERVICE_NOT_FOUND';
  end if;
  if v_service.deleted_at is not null or v_service.is_active is not true or v_service.status <> 'approved' then
    raise exception using message = 'SERVICE_INACTIVE';
  end if;

  if v_service.barber_id is not null and v_service.barber_id <> new.barber_id then
    raise exception using message = 'SERVICE_NOT_FOR_BARBER';
  end if;

  if v_service.shop_id is not null then
    if new.shop_id is null then
      new.shop_id := v_service.shop_id;
    end if;
    if new.shop_id <> v_service.shop_id then
      raise exception using message = 'SERVICE_NOT_FOR_SHOP';
    end if;
    if v_barber.shop_id is distinct from v_service.shop_id then
      raise exception using message = 'BARBER_NOT_IN_SHOP';
    end if;
  end if;

  v_duration := coalesce(v_service.duration_minutes, v_service.duration_min, new.duration_minutes, 30);
  if v_duration <= 0 then
    raise exception using message = 'INVALID_DURATION';
  end if;
  new.duration_minutes := v_duration;
  new.end_at := new.start_at + make_interval(mins => v_duration);

  v_price := coalesce(v_service.price_bhd, v_service.price, 0)::numeric(10,3);
  new.currency := coalesce(nullif(trim(coalesce(new.currency, '')), ''), 'BHD');
  new.total_price := v_price;
  new.price_bhd := v_price;

  v_deposit_type := nullif(trim(coalesce(v_service.deposit_type, '')), '');
  v_deposit_value := coalesce(v_service.deposit_value, 0)::numeric(10,3);
  if v_deposit_type is not null and v_deposit_value > 0 then
    if v_deposit_type = 'fixed' then
      v_deposit_required := v_deposit_value;
    elsif v_deposit_type = 'percent' then
      v_deposit_required := round((v_price * v_deposit_value / 100.0)::numeric, 3);
    end if;
  end if;
  if v_deposit_required < 0 then v_deposit_required := 0; end if;
  if v_deposit_required > v_price then v_deposit_required := v_price; end if;
  new.deposit_required_amount := v_deposit_required;

  new.status := coalesce(nullif(trim(coalesce(new.status, '')), ''), 'pending');
  if new.status not in ('pending','confirmed','in_progress','rescheduled','no_show','cancelled','completed') then
    raise exception using message = 'INVALID_STATUS';
  end if;

  if new.status = 'confirmed' and new.confirmed_at is null then
    new.confirmed_at := now();
  end if;
  if new.status = 'in_progress' and new.started_at is null then
    new.started_at := now();
  end if;
  if new.status = 'completed' and new.completed_at is null then
    new.completed_at := now();
  end if;
  if new.status = 'no_show' and new.no_show_at is null then
    new.no_show_at := now();
  end if;

  return new;
end;
$$;

create or replace function public.bookings_guard_update()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_minutes int;
  v_actor uuid;
begin
  if public.is_admin() then
    return new;
  end if;

  if new.customer_profile_id is distinct from old.customer_profile_id then
    raise exception using message = 'BOOKING_CUSTOMER_IMMUTABLE';
  end if;
  if new.shop_id is distinct from old.shop_id then
    raise exception using message = 'BOOKING_SHOP_IMMUTABLE';
  end if;
  if new.barber_id is distinct from old.barber_id then
    raise exception using message = 'BOOKING_BARBER_IMMUTABLE';
  end if;
  if new.service_id is distinct from old.service_id then
    raise exception using message = 'BOOKING_SERVICE_IMMUTABLE';
  end if;
  if new.duration_minutes is distinct from old.duration_minutes then
    raise exception using message = 'BOOKING_DURATION_IMMUTABLE';
  end if;

  if new.status is distinct from old.status then
    if old.status = 'pending' and new.status in ('confirmed','cancelled') then
      null;
    elsif old.status = 'confirmed' and new.status in ('in_progress','completed','cancelled','no_show','rescheduled') then
      null;
    elsif old.status = 'in_progress' and new.status in ('completed','cancelled','no_show') then
      null;
    elsif old.status = 'rescheduled' and new.status in ('confirmed','in_progress','completed','cancelled','no_show') then
      null;
    else
      raise exception using message = 'INVALID_STATUS_TRANSITION';
    end if;

    v_actor := coalesce(new.cancelled_by_profile_id, auth.uid());
    if new.status = 'confirmed' and new.confirmed_at is null then
      new.confirmed_at := now();
    end if;
    if new.status = 'in_progress' and new.started_at is null then
      new.started_at := now();
    end if;
    if new.status = 'completed' and new.completed_at is null then
      new.completed_at := now();
    end if;
    if new.status = 'no_show' and new.no_show_at is null then
      new.no_show_at := now();
    end if;
    if new.status = 'cancelled' then
      if new.cancelled_at is null then new.cancelled_at := now(); end if;
      if new.cancelled_by_profile_id is null then new.cancelled_by_profile_id := v_actor; end if;
    end if;
    if new.status = 'rescheduled' then
      if new.rescheduled_at is null then new.rescheduled_at := now(); end if;
      if new.rescheduled_by_profile_id is null then new.rescheduled_by_profile_id := v_actor; end if;
    end if;
  end if;

  if new.start_at is distinct from old.start_at then
    v_minutes := coalesce(new.duration_minutes, old.duration_minutes);
    if v_minutes is null or v_minutes <= 0 then
      v_minutes := greatest(1, round(extract(epoch from (old.end_at - old.start_at)) / 60.0)::int);
    end if;
    new.end_at := new.start_at + make_interval(mins => v_minutes);
  end if;

  if new.end_at <= new.start_at then
    raise exception using message = 'INVALID_TIME_RANGE';
  end if;

  return new;
end;
$$;

create or replace function public.start_booking(booking_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_booking public.bookings%rowtype;
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  select * into v_booking
  from public.bookings b
  where b.id = booking_id
  limit 1;

  if v_booking.id is null then
    raise exception using message = 'BOOKING_NOT_FOUND';
  end if;

  if not (
    exists (select 1 from public.barbers br where br.id = v_booking.barber_id and br.profile_id = v_user)
    or exists (select 1 from public.barbershops s where s.id = v_booking.shop_id and s.owner_profile_id = v_user)
    or (v_booking.branch_id is not null and public.is_branch_staff(v_booking.branch_id))
    or public.is_admin()
  ) then
    raise exception using message = 'FORBIDDEN';
  end if;

  if v_booking.status <> 'confirmed' then
    raise exception using message = 'BOOKING_NOT_STARTABLE';
  end if;

  update public.bookings
  set status = 'in_progress',
      updated_at = now()
  where id = v_booking.id
  returning * into v_booking;

  return v_booking;
end;
$$;

create or replace function public.complete_booking(booking_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_booking public.bookings%rowtype;
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  select * into v_booking
  from public.bookings b
  where b.id = booking_id
  limit 1;

  if v_booking.id is null then
    raise exception using message = 'BOOKING_NOT_FOUND';
  end if;

  if not (
    exists (select 1 from public.barbers br where br.id = v_booking.barber_id and br.profile_id = v_user)
    or exists (select 1 from public.barbershops s where s.id = v_booking.shop_id and s.owner_profile_id = v_user)
    or (v_booking.branch_id is not null and public.is_branch_staff(v_booking.branch_id))
    or public.is_admin()
  ) then
    raise exception using message = 'FORBIDDEN';
  end if;

  if v_booking.status not in ('confirmed','in_progress') then
    raise exception using message = 'BOOKING_NOT_COMPLETABLE';
  end if;

  update public.bookings
  set status = 'completed',
      updated_at = now()
  where id = v_booking.id
  returning * into v_booking;

  return v_booking;
end;
$$;

create or replace function public.mark_booking_no_show(booking_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_booking public.bookings%rowtype;
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  select * into v_booking
  from public.bookings b
  where b.id = booking_id
  limit 1;

  if v_booking.id is null then
    raise exception using message = 'BOOKING_NOT_FOUND';
  end if;

  if not (
    exists (select 1 from public.barbers br where br.id = v_booking.barber_id and br.profile_id = v_user)
    or exists (select 1 from public.barbershops s where s.id = v_booking.shop_id and s.owner_profile_id = v_user)
    or (v_booking.branch_id is not null and public.is_branch_staff(v_booking.branch_id))
    or public.is_admin()
  ) then
    raise exception using message = 'FORBIDDEN';
  end if;

  if v_booking.status not in ('confirmed','in_progress') then
    raise exception using message = 'BOOKING_NOT_NO_SHOW';
  end if;

  update public.bookings
  set status = 'no_show',
      updated_at = now()
  where id = v_booking.id
  returning * into v_booking;

  return v_booking;
end;
$$;

do $$
begin
  if to_regprocedure('public.start_booking(uuid)') is not null then
    revoke all on function public.start_booking(uuid) from public;
  end if;
  if to_regprocedure('public.complete_booking(uuid)') is not null then
    revoke all on function public.complete_booking(uuid) from public;
  end if;
  if to_regprocedure('public.mark_booking_no_show(uuid)') is not null then
    revoke all on function public.mark_booking_no_show(uuid) from public;
  end if;

  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    if to_regprocedure('public.start_booking(uuid)') is not null then
      grant execute on function public.start_booking(uuid) to authenticated;
    end if;
    if to_regprocedure('public.complete_booking(uuid)') is not null then
      grant execute on function public.complete_booking(uuid) to authenticated;
    end if;
    if to_regprocedure('public.mark_booking_no_show(uuid)') is not null then
      grant execute on function public.mark_booking_no_show(uuid) to authenticated;
    end if;
  end if;
end;
$$;

commit;


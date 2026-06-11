begin;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'bookings_time_range_chk'
      and conrelid = 'public.bookings'::regclass
  ) then
    alter table public.bookings
      add constraint bookings_time_range_chk
      check (end_at > start_at) not valid;
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'bookings_duration_positive_chk'
      and conrelid = 'public.bookings'::regclass
  ) then
    alter table public.bookings
      add constraint bookings_duration_positive_chk
      check (duration_minutes is null or duration_minutes > 0) not valid;
  end if;
end;
$$;

create or replace function public.touch_booking_on_payment_change()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_booking uuid;
begin
  v_booking := coalesce(new.booking_id, old.booking_id);
  if v_booking is null then
    return null;
  end if;
  update public.bookings
  set updated_at = now()
  where id = v_booking;
  return null;
end;
$$;

drop trigger if exists payments_touch_booking on public.payments;
create trigger payments_touch_booking
after insert or update or delete on public.payments
for each row execute function public.touch_booking_on_payment_change();

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
  if new.status not in ('pending','confirmed','cancelled','completed') then
    raise exception using message = 'INVALID_STATUS';
  end if;

  return new;
end;
$$;

drop trigger if exists bookings_prepare_insert on public.bookings;
create trigger bookings_prepare_insert
before insert on public.bookings
for each row execute function public.bookings_prepare_insert();

create or replace function public.bookings_guard_update()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_minutes int;
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
    if old.status = 'pending' and new.status in ('confirmed','cancelled','completed') then
      null;
    elsif old.status = 'confirmed' and new.status in ('completed','cancelled') then
      null;
    else
      raise exception using message = 'INVALID_STATUS_TRANSITION';
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

drop trigger if exists bookings_guard_before_update on public.bookings;
create trigger bookings_guard_before_update
before update on public.bookings
for each row execute function public.bookings_guard_update();

commit;


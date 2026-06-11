begin;

create extension if not exists btree_gist;

alter table public.bookings
  add column if not exists customer_id uuid;

alter table public.bookings
  add column if not exists date date;

alter table public.bookings
  add column if not exists start_time time;

alter table public.bookings
  add column if not exists end_time time;

alter table public.bookings
  add column if not exists discount_amount numeric(10,3) not null default 0;

alter table public.bookings
  add column if not exists payment_status text not null default 'unpaid';

alter table public.bookings
  add column if not exists source text not null default 'unknown';

alter table public.bookings
  add column if not exists reel_id uuid references public.posts (id) on delete set null;

alter table public.bookings
  add column if not exists offer_id uuid references public.offers (id) on delete set null;

alter table public.bookings
  add column if not exists cancelled_by text;

alter table public.bookings
  add column if not exists cancelled_reason text;

alter table public.bookings
  add column if not exists rescheduled_from uuid references public.bookings (id) on delete set null;

update public.bookings
set
  customer_id = customer_profile_id,
  date = ((start_at at time zone 'Asia/Bahrain')::date),
  start_time = ((start_at at time zone 'Asia/Bahrain')::time),
  end_time = ((end_at at time zone 'Asia/Bahrain')::time),
  source_post_id = coalesce(source_post_id, reel_id),
  reel_id = coalesce(reel_id, source_post_id)
where
  customer_id is distinct from customer_profile_id
  or date is distinct from ((start_at at time zone 'Asia/Bahrain')::date)
  or start_time is distinct from ((start_at at time zone 'Asia/Bahrain')::time)
  or end_time is distinct from ((end_at at time zone 'Asia/Bahrain')::time)
  or source_post_id is null
  or reel_id is null;

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'bookings_status_check'
      and conrelid = 'public.bookings'::regclass
  ) then
    alter table public.bookings drop constraint bookings_status_check;
  end if;

  alter table public.bookings
    add constraint bookings_status_check
    check (status in ('pending','confirmed','in_progress','rescheduled','no_show','cancelled','completed')) not valid;
  alter table public.bookings validate constraint bookings_status_check;
end $$;

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'bookings_payment_status_chk'
      and conrelid = 'public.bookings'::regclass
  ) then
    alter table public.bookings drop constraint bookings_payment_status_chk;
  end if;

  alter table public.bookings
    add constraint bookings_payment_status_chk
    check (payment_status in ('unpaid','pending','paid','failed','refunded')) not valid;
  alter table public.bookings validate constraint bookings_payment_status_chk;
end $$;

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'bookings_payment_method_chk'
      and conrelid = 'public.bookings'::regclass
  ) then
    alter table public.bookings drop constraint bookings_payment_method_chk;
  end if;

  alter table public.bookings
    add constraint bookings_payment_method_chk
    check (payment_method in ('cash','card','benefitpay','apple_pay','stc_pay')) not valid;
  alter table public.bookings validate constraint bookings_payment_method_chk;
end $$;

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'bookings_no_overlap_per_barber'
      and conrelid = 'public.bookings'::regclass
  ) then
    alter table public.bookings drop constraint bookings_no_overlap_per_barber;
  end if;

  alter table public.bookings
    add constraint bookings_no_overlap_per_barber
    exclude using gist (
      barber_id with =,
      tstzrange(start_at, end_at, '[)') with &&
    )
    where (status in ('pending','confirmed','in_progress'));
end $$;

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
  v_post record;
  v_offer record;
  v_duration int;
  v_price numeric(10,3);
  v_deposit_required numeric(10,3) := 0;
  v_deposit_type text;
  v_deposit_value numeric(10,3);
begin
  if new.discount_amount is null then new.discount_amount := 0; end if;
  if new.discount_amount < 0 then
    raise exception using message = 'INVALID_DISCOUNT';
  end if;

  if new.start_at is null then
    raise exception using message = 'INVALID_START_AT';
  end if;
  if new.barber_id is null then
    raise exception using message = 'INVALID_BARBER';
  end if;
  if new.service_id is null then
    raise exception using message = 'SERVICE_NOT_FOUND';
  end if;

  if new.source_post_id is null and new.reel_id is not null then
    new.source_post_id := new.reel_id;
  end if;
  if new.reel_id is null and new.source_post_id is not null then
    new.reel_id := new.source_post_id;
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

  if new.source_post_id is not null then
    select id, deleted_at, is_active, status
    into v_post
    from public.posts
    where id = new.source_post_id
    limit 1;

    if v_post.id is null then
      raise exception using message = 'INVALID_SOURCE_POST';
    end if;
    if v_post.deleted_at is not null or v_post.is_active is not true or v_post.status <> 'approved' then
      raise exception using message = 'SOURCE_POST_INACTIVE';
    end if;
  end if;

  if new.offer_id is not null then
    select id, shop_id, barber_id, active, is_active, status, valid_from, valid_to
    into v_offer
    from public.offers
    where id = new.offer_id
    limit 1;

    if v_offer.id is null then
      raise exception using message = 'INVALID_OFFER';
    end if;
    if coalesce(v_offer.active, true) is not true
      or coalesce(v_offer.is_active, true) is not true
      or v_offer.status <> 'approved'
      or (v_offer.valid_from is not null and v_offer.valid_from > now())
      or (v_offer.valid_to is not null and v_offer.valid_to < now()) then
      raise exception using message = 'OFFER_INACTIVE';
    end if;
    if v_offer.barber_id is not null and v_offer.barber_id <> new.barber_id then
      raise exception using message = 'OFFER_NOT_FOR_BARBER';
    end if;
    if v_offer.shop_id is not null and new.shop_id is not null and v_offer.shop_id <> new.shop_id then
      raise exception using message = 'OFFER_NOT_FOR_SHOP';
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
  new.price_bhd := v_price;
  if new.discount_amount > v_price then new.discount_amount := v_price; end if;
  new.total_price := greatest(v_price - new.discount_amount, 0)::numeric(10,3);

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

  if new.payment_status is null or new.payment_status = '' then
    new.payment_status := 'unpaid';
  end if;

  new.source := coalesce(nullif(trim(coalesce(new.source, '')), ''), 'unknown');

  if new.cancelled_reason is null and new.cancel_reason is not null then
    new.cancelled_reason := new.cancel_reason;
  end if;
  if new.cancel_reason is null and new.cancelled_reason is not null then
    new.cancel_reason := new.cancelled_reason;
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

  new.customer_id := new.customer_profile_id;
  new.date := ((new.start_at at time zone 'Asia/Bahrain')::date);
  new.start_time := ((new.start_at at time zone 'Asia/Bahrain')::time);
  new.end_time := ((new.end_at at time zone 'Asia/Bahrain')::time);

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
  v_cancelled_by text;
begin
  if public.is_admin() then
    if new.source_post_id is null and new.reel_id is not null then
      new.source_post_id := new.reel_id;
    end if;
    if new.reel_id is null and new.source_post_id is not null then
      new.reel_id := new.source_post_id;
    end if;
    new.customer_id := new.customer_profile_id;
    new.date := ((new.start_at at time zone 'Asia/Bahrain')::date);
    new.start_time := ((new.start_at at time zone 'Asia/Bahrain')::time);
    new.end_time := ((new.end_at at time zone 'Asia/Bahrain')::time);
    if new.cancel_reason is null and new.cancelled_reason is not null then
      new.cancel_reason := new.cancelled_reason;
    end if;
    if new.cancelled_reason is null and new.cancel_reason is not null then
      new.cancelled_reason := new.cancel_reason;
    end if;
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
      if new.cancelled_reason is null and new.cancel_reason is not null then new.cancelled_reason := new.cancel_reason; end if;
      if new.cancel_reason is null and new.cancelled_reason is not null then new.cancel_reason := new.cancelled_reason; end if;

      if new.cancelled_by is null or new.cancelled_by = '' then
        if public.is_admin() then
          v_cancelled_by := 'admin';
        elsif v_actor = old.customer_profile_id then
          v_cancelled_by := 'customer';
        elsif old.barber_id is not null and public.is_barber_owner(old.barber_id) then
          v_cancelled_by := 'barber';
        elsif old.shop_id is not null and public.is_shop_owner(old.shop_id) then
          v_cancelled_by := 'shop';
        else
          v_cancelled_by := null;
        end if;
        new.cancelled_by := v_cancelled_by;
      end if;
    end if;

    if new.status = 'rescheduled' then
      if new.rescheduled_at is null then new.rescheduled_at := now(); end if;
      if new.rescheduled_by_profile_id is null then new.rescheduled_by_profile_id := v_actor; end if;
    end if;
  end if;

  if new.start_at is distinct from old.start_at then
    v_minutes := coalesce(new.duration_minutes, old.duration_minutes);
    if old.start_at <= now() then
      raise exception using message = 'TOO_LATE_TO_RESCHEDULE';
    end if;
    if v_minutes is null or v_minutes <= 0 then
      v_minutes := greatest(1, round(extract(epoch from (old.end_at - old.start_at)) / 60.0)::int);
    end if;
    if new.start_at <= now() then
      raise exception using message = 'BOOKING_PAST_TIME';
    end if;
    new.end_at := new.start_at + make_interval(mins => v_minutes);
  end if;

  if new.end_at <= new.start_at then
    raise exception using message = 'INVALID_TIME_RANGE';
  end if;

  if new.source_post_id is null and new.reel_id is not null then
    new.source_post_id := new.reel_id;
  end if;
  if new.reel_id is null and new.source_post_id is not null then
    new.reel_id := new.source_post_id;
  end if;

  new.customer_id := new.customer_profile_id;
  new.date := ((new.start_at at time zone 'Asia/Bahrain')::date);
  new.start_time := ((new.start_at at time zone 'Asia/Bahrain')::time);
  new.end_time := ((new.end_at at time zone 'Asia/Bahrain')::time);

  return new;
end;
$$;

create or replace function public.hold_booking_slot(
  service_id uuid,
  start_at timestamptz,
  barber_id uuid,
  shop_id uuid default null,
  hold_minutes int default 5
)
returns table (hold_id uuid, expires_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_service record;
  v_barber record;
  v_shop record;
  v_duration int;
  v_end_at timestamptz;
  v_shop_id uuid;
  v_barber_shop_id uuid;
  v_expires timestamptz;
  v_buffer int := 0;
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  if hold_minutes is null or hold_minutes < 1 or hold_minutes > 30 then
    hold_minutes := 5;
  end if;

  select b.id, b.shop_id, b.deleted_at, b.is_active, b.status into v_barber
  from public.barbers b
  where b.id = $3
  limit 1;

  if v_barber.id is null then
    raise exception using message = 'INVALID_BARBER';
  end if;
  if v_barber.deleted_at is not null or v_barber.is_active is not true or v_barber.status <> 'approved' then
    raise exception using message = 'BARBER_INACTIVE';
  end if;

  select b.shop_id into v_barber_shop_id from public.barbers b where b.id = $3;
  v_shop_id := coalesce($4, v_barber_shop_id);

  if v_shop_id is not null then
    select s.id, s.deleted_at, s.is_active, s.status into v_shop
    from public.barbershops s
    where s.id = v_shop_id
    limit 1;
    if v_shop.id is null then
      raise exception using message = 'INVALID_SHOP';
    end if;
    if v_shop.deleted_at is not null or v_shop.is_active is not true or v_shop.status <> 'approved' then
      raise exception using message = 'SHOP_INACTIVE';
    end if;
  end if;

  select
    s.id,
    s.shop_id,
    s.barber_id,
    s.is_active,
    s.status,
    s.deleted_at,
    s.duration_minutes,
    s.duration_min
  into v_service
  from public.services s
  where s.id = $1
  limit 1;

  if v_service.id is null then
    raise exception using message = 'SERVICE_NOT_FOUND';
  end if;

  if v_service.deleted_at is not null or v_service.is_active is not true or v_service.status <> 'approved' then
    raise exception using message = 'SERVICE_INACTIVE';
  end if;

  if v_service.barber_id is not null and v_service.barber_id <> $3 then
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

  v_end_at := $2 + make_interval(mins => v_duration);

  select coalesce(br.buffer_minutes, s.buffer_minutes, 0)
  into v_buffer
  from public.barbers br
  left join public.barbershops s on s.id = br.shop_id
  where br.id = $3;

  delete from public.booking_slot_holds h
  where h.consumed_at is null and h.expires_at <= now();

  if exists (
    select 1
    from public.barber_time_off t
    where t.barber_id = $3
      and tstzrange(t.starts_at, t.ends_at, '[)') && tstzrange($2, v_end_at, '[)')
  ) then
    raise exception using message = 'BARBER_TIME_OFF';
  end if;

  if exists (
    select 1
    from public.bookings b
    where b.barber_id = $3
      and b.status in ('pending','confirmed','in_progress')
      and tstzrange(b.start_at, b.end_at + make_interval(mins => v_buffer), '[)') && tstzrange($2, v_end_at, '[)')
  ) then
    raise exception using message = 'BOOKING_OVERLAP';
  end if;

  if exists (
    select 1
    from public.booking_slot_holds h
    where h.barber_id = $3
      and h.consumed_at is null
      and h.expires_at > now()
      and tstzrange(h.start_at, h.end_at, '[)') && tstzrange($2, v_end_at, '[)')
  ) then
    raise exception using message = 'SLOT_HELD';
  end if;

  v_expires := now() + make_interval(mins => hold_minutes);

  insert into public.booking_slot_holds as h (
    profile_id,
    barber_id,
    shop_id,
    service_id,
    start_at,
    end_at,
    expires_at
  )
  values (
    v_user,
    $3,
    v_shop_id,
    $1,
    $2,
    v_end_at,
    v_expires
  )
  returning h.id, h.expires_at into hold_id, expires_at;

  return next;
  return;
end;
$$;

revoke all on function public.hold_booking_slot(uuid, timestamptz, uuid, uuid, int) from public;
grant execute on function public.hold_booking_slot(uuid, timestamptz, uuid, uuid, int) to authenticated;

create or replace function public.create_booking(
  service_id uuid,
  start_at timestamptz,
  barber_id uuid,
  shop_id uuid default null,
  notes text default null,
  payment_method text default 'cash',
  source_post_id uuid default null,
  source text default 'unknown',
  reel_id uuid default null,
  offer_id uuid default null,
  discount_amount numeric(10,3) default 0
)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  p_service_id uuid := service_id;
  p_start_at timestamptz := start_at;
  p_barber_id uuid := barber_id;
  p_shop_id uuid := shop_id;
  p_notes text := notes;
  p_payment_method text := payment_method;
  p_source_post_id uuid := source_post_id;
  p_source text := source;
  p_reel_id uuid := reel_id;
  p_offer_id uuid := offer_id;
  p_discount_amount numeric(10,3) := coalesce(discount_amount, 0)::numeric(10,3);

  v_user uuid;
  v_barber_shop_id uuid;
  v_service record;
  v_barber record;
  v_shop record;
  v_shop_id uuid;
  v_branch_id uuid;
  v_duration int;
  v_price numeric(10,3);
  v_end_at timestamptz;
  v_buffer int := 0;
  v_booking public.bookings%rowtype;
  v_deposit_type text;
  v_deposit_value numeric(10,3);
  v_deposit_required numeric(10,3) := 0;
  v_payee_type text;
  v_payee_id uuid;
  v_payment_method text;
  v_post record;
  v_offer record;
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  if p_barber_id is null then
    raise exception using message = 'INVALID_BARBER';
  end if;

  p_source_post_id := coalesce(p_source_post_id, p_reel_id);
  p_reel_id := coalesce(p_reel_id, p_source_post_id);

  select b.id, b.shop_id, b.deleted_at, b.is_active, b.status
  into v_barber
  from public.barbers b
  where b.id = p_barber_id
  limit 1;

  if v_barber.id is null then
    raise exception using message = 'INVALID_BARBER';
  end if;
  if v_barber.deleted_at is not null or v_barber.is_active is not true or v_barber.status <> 'approved' then
    raise exception using message = 'BARBER_INACTIVE';
  end if;

  v_barber_shop_id := v_barber.shop_id;

  if v_barber_shop_id is null and p_shop_id is not null then
    raise exception using message = 'INVALID_SHOP';
  end if;

  v_shop_id := coalesce(p_shop_id, v_barber_shop_id);
  if v_shop_id is not null then
    select s.id, s.deleted_at, s.is_active, s.status
    into v_shop
    from public.barbershops s
    where s.id = v_shop_id
    limit 1;
    if v_shop.id is null then
      raise exception using message = 'INVALID_SHOP';
    end if;
    if v_shop.deleted_at is not null or v_shop.is_active is not true or v_shop.status <> 'approved' then
      raise exception using message = 'SHOP_INACTIVE';
    end if;
    v_branch_id := public.ensure_shop_default_branch(v_shop_id);
  end if;

  select
    s.id,
    s.shop_id,
    s.barber_id,
    s.is_active,
    s.status,
    s.deleted_at,
    s.price_bhd,
    s.duration_minutes,
    s.price,
    s.duration_min,
    s.deposit_type,
    s.deposit_value
  into v_service
  from public.services s
  where s.id = p_service_id
  limit 1;

  if v_service.id is null then
    raise exception using message = 'SERVICE_NOT_FOUND';
  end if;

  if v_service.deleted_at is not null or v_service.is_active is not true or v_service.status <> 'approved' then
    raise exception using message = 'SERVICE_INACTIVE';
  end if;

  if v_service.barber_id is not null and v_service.barber_id <> p_barber_id then
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
    v_branch_id := public.ensure_shop_default_branch(v_shop_id);
  end if;

  if p_source_post_id is not null then
    select p.id, p.deleted_at, p.is_active, p.status
    into v_post
    from public.posts p
    where p.id = p_source_post_id
    limit 1;

    if v_post.id is null then
      raise exception using message = 'INVALID_SOURCE_POST';
    end if;
    if v_post.deleted_at is not null or v_post.is_active is not true or v_post.status <> 'approved' then
      raise exception using message = 'SOURCE_POST_INACTIVE';
    end if;
  end if;

  if p_offer_id is not null then
    select o.id, o.shop_id, o.barber_id, o.active, o.is_active, o.status, o.valid_from, o.valid_to
    into v_offer
    from public.offers o
    where o.id = p_offer_id
    limit 1;

    if v_offer.id is null then
      raise exception using message = 'INVALID_OFFER';
    end if;
    if coalesce(v_offer.active, true) is not true
      or coalesce(v_offer.is_active, true) is not true
      or v_offer.status <> 'approved'
      or (v_offer.valid_from is not null and v_offer.valid_from > now())
      or (v_offer.valid_to is not null and v_offer.valid_to < now()) then
      raise exception using message = 'OFFER_INACTIVE';
    end if;
    if v_offer.barber_id is not null and v_offer.barber_id <> p_barber_id then
      raise exception using message = 'OFFER_NOT_FOR_BARBER';
    end if;
    if v_offer.shop_id is not null and v_shop_id is not null and v_offer.shop_id <> v_shop_id then
      raise exception using message = 'OFFER_NOT_FOR_SHOP';
    end if;
  end if;

  v_duration := coalesce(v_service.duration_minutes, v_service.duration_min, 30);
  if v_duration <= 0 then
    raise exception using message = 'INVALID_DURATION';
  end if;

  v_price := coalesce(v_service.price_bhd, v_service.price, 0)::numeric(10,3);
  if p_discount_amount < 0 then
    raise exception using message = 'INVALID_DISCOUNT';
  end if;
  if p_discount_amount > v_price then
    p_discount_amount := v_price;
  end if;
  v_end_at := p_start_at + make_interval(mins => v_duration);

  select coalesce(br.buffer_minutes, s.buffer_minutes, 0)
  into v_buffer
  from public.barbers br
  left join public.barbershops s on s.id = br.shop_id
  where br.id = p_barber_id;

  if exists (
    select 1
    from public.barber_time_off t
    where t.barber_id = p_barber_id
      and tstzrange(t.starts_at, t.ends_at, '[)') && tstzrange(p_start_at, v_end_at, '[)')
  ) then
    raise exception using message = 'BARBER_TIME_OFF';
  end if;

  if exists (
    select 1
    from public.bookings b
    where b.barber_id = p_barber_id
      and b.status in ('pending','confirmed','in_progress')
      and tstzrange(b.start_at, b.end_at + make_interval(mins => v_buffer), '[)') && tstzrange(p_start_at, v_end_at, '[)')
  ) then
    raise exception using message = 'BOOKING_OVERLAP';
  end if;

  v_payment_method := lower(trim(coalesce(p_payment_method, '')));
  if v_payment_method not in ('cash','card','benefitpay','apple_pay','stc_pay') then
    v_payment_method := 'cash';
  end if;

  if v_payment_method <> 'cash' then
    raise exception using message = 'PAYMENT_METHOD_NOT_SUPPORTED';
  end if;

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

  insert into public.bookings (
    customer_profile_id,
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
    duration_minutes,
    deposit_required_amount,
    payment_method,
    payment_status,
    discount_amount,
    source,
    source_post_id,
    reel_id,
    offer_id
  )
  values (
    v_user,
    v_shop_id,
    v_branch_id,
    p_barber_id,
    p_service_id,
    p_start_at,
    v_end_at,
    'confirmed',
    p_notes,
    greatest(v_price - p_discount_amount, 0)::numeric(10,3),
    'BHD',
    v_price,
    v_duration,
    v_deposit_required,
    v_payment_method,
    case when v_deposit_required > 0 then 'pending' else 'unpaid' end,
    p_discount_amount,
    coalesce(nullif(trim(coalesce(p_source, '')), ''), 'unknown'),
    p_source_post_id,
    p_reel_id,
    p_offer_id
  )
  returning * into v_booking;

  v_payee_type := case when v_shop_id is not null then 'shop' else 'barber' end;
  v_payee_id := coalesce(v_shop_id, p_barber_id);

  if v_deposit_required > 0 then
    insert into public.payments (
      booking_id,
      payer_profile_id,
      payee_type,
      payee_id,
      amount,
      currency,
      provider,
      status,
      purpose
    )
    values (
      v_booking.id,
      v_user,
      v_payee_type,
      v_payee_id,
      v_deposit_required,
      'BHD',
      'manual',
      'pending',
      'deposit'
    );
  end if;

  return v_booking;
end;
$$;

revoke all on function public.create_booking(uuid, timestamptz, uuid, uuid, text, text, uuid, text, uuid, uuid, numeric) from public;
grant execute on function public.create_booking(uuid, timestamptz, uuid, uuid, text, text, uuid, text, uuid, uuid, numeric) to authenticated;

create or replace function public.create_booking_with_hold(
  service_id uuid,
  start_at timestamptz,
  barber_id uuid,
  hold_id uuid,
  shop_id uuid default null,
  notes text default null,
  payment_method text default 'cash',
  source_post_id uuid default null,
  source text default 'unknown',
  reel_id uuid default null,
  offer_id uuid default null,
  discount_amount numeric(10,3) default 0
)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_hold public.booking_slot_holds%rowtype;
  v_booking public.bookings%rowtype;
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  select *
  into v_hold
  from public.booking_slot_holds h
  where h.id = $4
    and h.profile_id = v_user
    and h.consumed_at is null
    and h.expires_at > now()
  for update;

  if v_hold.id is null then
    raise exception using message = 'HOLD_NOT_FOUND';
  end if;

  if v_hold.service_id is distinct from $1 or v_hold.barber_id is distinct from $3 or v_hold.start_at is distinct from $2 then
    raise exception using message = 'HOLD_MISMATCH';
  end if;

  v_booking := public.create_booking($1, $2, $3, $5, $6, $7, $8, $9, $10, $11, $12);

  update public.booking_slot_holds
  set consumed_at = now()
  where id = v_hold.id;

  return v_booking;
end;
$$;

revoke all on function public.create_booking_with_hold(uuid, timestamptz, uuid, uuid, uuid, text, text, uuid, text, uuid, uuid, numeric) from public;
grant execute on function public.create_booking_with_hold(uuid, timestamptz, uuid, uuid, uuid, text, text, uuid, text, uuid, uuid, numeric) to authenticated;

create or replace function public.create_booking_safely(
  service_id uuid,
  start_at timestamptz,
  barber_id uuid,
  shop_id uuid default null,
  notes text default null,
  payment_method text default 'cash',
  source_post_id uuid default null,
  source text default 'unknown',
  reel_id uuid default null,
  offer_id uuid default null,
  discount_amount numeric(10,3) default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking public.bookings%rowtype;
begin
  begin
    v_booking := public.create_booking(service_id, start_at, barber_id, shop_id, notes, payment_method, source_post_id, source, reel_id, offer_id, discount_amount);
    return jsonb_build_object('ok', true, 'booking', to_jsonb(v_booking));
  exception when others then
    return jsonb_build_object('ok', false, 'error', sqlerrm);
  end;
end;
$$;

revoke all on function public.create_booking_safely(uuid, timestamptz, uuid, uuid, text, text, uuid, text, uuid, uuid, numeric) from public;
grant execute on function public.create_booking_safely(uuid, timestamptz, uuid, uuid, text, text, uuid, text, uuid, uuid, numeric) to authenticated;

commit;

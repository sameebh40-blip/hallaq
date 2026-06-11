begin;

create table if not exists public.waitlist_entries (
  id uuid primary key default gen_random_uuid(),
  barber_id uuid not null references public.barbers (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'waiting' check (status in ('waiting','notified','booked','cancelled','expired')),
  eta_minutes int,
  notified_at timestamptz,
  booked_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists waitlist_entries_barber_created_idx on public.waitlist_entries (barber_id, created_at asc);
create unique index if not exists waitlist_entries_active_unique_idx
on public.waitlist_entries (barber_id, profile_id)
where status in ('waiting','notified');

alter table public.waitlist_entries enable row level security;

drop policy if exists "waitlist_entries_read_own" on public.waitlist_entries;
create policy "waitlist_entries_read_own"
on public.waitlist_entries
for select
to authenticated
using (profile_id = auth.uid() or public.is_admin());

drop policy if exists "waitlist_entries_read_staff" on public.waitlist_entries;
create policy "waitlist_entries_read_staff"
on public.waitlist_entries
for select
to authenticated
using (
  public.is_admin()
  or (public.is_barber_owner(barber_id))
  or (
    exists (
      select 1
      from public.barbers b
      join public.barbershops s on s.id = b.shop_id
      where b.id = waitlist_entries.barber_id and s.owner_profile_id = auth.uid()
    )
  )
);

drop policy if exists "waitlist_entries_insert_own" on public.waitlist_entries;
create policy "waitlist_entries_insert_own"
on public.waitlist_entries
for insert
to authenticated
with check (profile_id = auth.uid());

drop policy if exists "waitlist_entries_update_own" on public.waitlist_entries;
create policy "waitlist_entries_update_own"
on public.waitlist_entries
for update
to authenticated
using (profile_id = auth.uid() or public.is_admin())
with check (profile_id = auth.uid() or public.is_admin());

grant select, insert, update on public.waitlist_entries to authenticated;

create or replace function public.waitlist_guard_updates()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if new.profile_id is distinct from old.profile_id or new.barber_id is distinct from old.barber_id then
    raise exception 'Not allowed';
  end if;

  if new.status is distinct from old.status then
    if old.status = 'waiting' and new.status = 'cancelled' then
      new.cancelled_at := now();
      return new;
    end if;
    raise exception 'Not allowed';
  end if;

  if new.notified_at is distinct from old.notified_at
    or new.booked_at is distinct from old.booked_at
    or new.cancelled_at is distinct from old.cancelled_at
  then
    raise exception 'Not allowed';
  end if;

  return new;
end;
$$;

drop trigger if exists waitlist_guard_updates on public.waitlist_entries;
create trigger waitlist_guard_updates
before update on public.waitlist_entries
for each row execute function public.waitlist_guard_updates();

create or replace function public.get_waitlist_status(p_barber uuid)
returns table (
  status text,
  waitlist_position int,
  eta_minutes int
)
language plpgsql
stable
security definer
set search_path = public
set row_security = off
as $$
declare
  v_id uuid;
  v_created timestamptz;
  v_status text;
  v_eta int;
  v_pos int;
begin
  if auth.uid() is null then
    return query select 'unauthorized'::text, null::int, null::int;
    return;
  end if;

  select e.id, e.created_at, e.status, e.eta_minutes
  into v_id, v_created, v_status, v_eta
  from public.waitlist_entries e
  where e.barber_id = p_barber
    and e.profile_id = auth.uid()
    and e.status in ('waiting','notified')
  order by e.created_at desc
  limit 1;

  if v_id is null then
    return query select 'none'::text, null::int, null::int;
    return;
  end if;

  select count(*)::int + 1
  into v_pos
  from public.waitlist_entries e
  where e.barber_id = p_barber
    and e.status = 'waiting'
    and e.created_at < v_created;

  return query select v_status, v_pos as waitlist_position, coalesce(v_eta, greatest(10, v_pos * 15));
end;
$$;

grant execute on function public.get_waitlist_status(uuid) to authenticated;

create or replace function public.notify_waitlist_slot_available(p_barber uuid)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_entry record;
begin
  select e.id, e.profile_id
  into v_entry
  from public.waitlist_entries e
  where e.barber_id = p_barber
    and e.status = 'waiting'
  order by e.created_at asc
  limit 1
  for update skip locked;

  if v_entry.id is null then
    return;
  end if;

  update public.waitlist_entries
  set status = 'notified',
      notified_at = now()
  where id = v_entry.id;

  insert into public.notifications (profile_id, type, title, body, data)
  values (
    v_entry.profile_id,
    'waitlist',
    'Slot available',
    'A booking slot is available now. Tap to book.',
    jsonb_build_object('barber_id', p_barber, 'waitlist_entry_id', v_entry.id)
  );
end;
$$;

create or replace function public.availability_cache_notify_waitlist_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  today0 date;
begin
  today0 := (now() at time zone 'Asia/Bahrain')::date;
  if tg_op = 'UPDATE' and new.has_slots = true and old.has_slots = false and new.day = today0 then
    perform public.notify_waitlist_slot_available(new.barber_id);
  end if;
  return null;
end;
$$;

drop trigger if exists availability_cache_notify_waitlist on public.availability_cache_days;
create trigger availability_cache_notify_waitlist
after update of has_slots on public.availability_cache_days
for each row execute function public.availability_cache_notify_waitlist_trigger();

create or replace function public.barber_availability_status(p_barber uuid)
returns text
language plpgsql
stable
set search_path = public
as $$
declare
  today0 date;
  has_today boolean;
  has_soon boolean;
  is_now boolean;
begin
  today0 := (now() at time zone 'Asia/Bahrain')::date;

  select coalesce(b.available_now, false) into is_now
  from public.barbers b
  where b.id = p_barber;

  if coalesce(is_now, false) then
    return 'available_now';
  end if;

  select exists (
    select 1
    from public.availability_cache_days d
    where d.barber_id = p_barber and d.day = today0 and d.has_slots = true
    limit 1
  ) into has_today;

  if coalesce(has_today, false) then
    return 'available_now';
  end if;

  select exists (
    select 1
    from public.availability_cache_days d
    where d.barber_id = p_barber
      and d.day between today0 and (today0 + interval '7 days')::date
      and d.has_slots = true
    limit 1
  ) into has_soon;

  if coalesce(has_soon, false) then
    return 'busy_today';
  end if;

  return 'fully_booked';
end;
$$;

create or replace function public.barbers_availability_status(p_barbers uuid[])
returns table (
  barber_id uuid,
  status text
)
language sql
stable
as $$
  select x as barber_id, public.barber_availability_status(x) as status
  from unnest(p_barbers) as x;
$$;

grant execute on function public.barber_availability_status(uuid) to anon, authenticated;
grant execute on function public.barbers_availability_status(uuid[]) to anon, authenticated;

create table if not exists public.gift_cards (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  purchaser_profile_id uuid not null references public.profiles (id) on delete cascade,
  recipient_contact text,
  message text,
  amount_bhd numeric(10,3) not null,
  balance_bhd numeric(10,3) not null,
  status text not null default 'active' check (status in ('active','redeemed','cancelled')),
  redeemed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (code)
);

alter table public.gift_cards enable row level security;

drop policy if exists "gift_cards_read_own" on public.gift_cards;
create policy "gift_cards_read_own"
on public.gift_cards
for select
to authenticated
using (purchaser_profile_id = auth.uid() or public.is_admin());

drop policy if exists "gift_cards_insert_own" on public.gift_cards;
create policy "gift_cards_insert_own"
on public.gift_cards
for insert
to authenticated
with check (purchaser_profile_id = auth.uid());

drop policy if exists "gift_cards_update_admin" on public.gift_cards;
create policy "gift_cards_update_admin"
on public.gift_cards
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

grant select, insert on public.gift_cards to authenticated;

create table if not exists public.gift_card_wallet (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  balance_bhd numeric(10,3) not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.gift_card_wallet enable row level security;

drop policy if exists "gift_card_wallet_read_own" on public.gift_card_wallet;
create policy "gift_card_wallet_read_own"
on public.gift_card_wallet
for select
to authenticated
using (profile_id = auth.uid());

drop policy if exists "gift_card_wallet_write_own" on public.gift_card_wallet;
create policy "gift_card_wallet_write_own"
on public.gift_card_wallet
for all
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

grant select, insert, update on public.gift_card_wallet to authenticated;

create table if not exists public.gift_card_redemptions (
  id uuid primary key default gen_random_uuid(),
  gift_card_id uuid not null references public.gift_cards (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  amount_bhd numeric(10,3) not null,
  created_at timestamptz not null default now()
);

create index if not exists gift_card_redemptions_profile_created_idx on public.gift_card_redemptions (profile_id, created_at desc);

alter table public.gift_card_redemptions enable row level security;

drop policy if exists "gift_card_redemptions_read_own" on public.gift_card_redemptions;
create policy "gift_card_redemptions_read_own"
on public.gift_card_redemptions
for select
to authenticated
using (profile_id = auth.uid() or public.is_admin());

drop policy if exists "gift_card_redemptions_insert_admin" on public.gift_card_redemptions;
create policy "gift_card_redemptions_insert_admin"
on public.gift_card_redemptions
for insert
to authenticated
with check (public.is_admin());

grant select on public.gift_card_redemptions to authenticated;

create or replace function public.gift_card_code()
returns text
language sql
immutable
as $$
  select upper(encode(gen_random_bytes(6), 'hex'));
$$;

create or replace function public.gift_card_purchase(p_amount_bhd numeric, p_recipient_contact text default null, p_message text default null)
returns table (
  gift_card_id uuid,
  code text
)
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_code text;
  v_id uuid;
  v_amount numeric(10,3);
  i int := 0;
begin
  if auth.uid() is null then
    raise exception 'Unauthorized';
  end if;

  v_amount := greatest(coalesce(p_amount_bhd, 0), 0);
  if v_amount <= 0 then
    raise exception 'Invalid amount';
  end if;

  loop
    v_code := public.gift_card_code();
    begin
      insert into public.gift_cards (code, purchaser_profile_id, recipient_contact, message, amount_bhd, balance_bhd)
      values (v_code, auth.uid(), nullif(trim(p_recipient_contact), ''), nullif(trim(p_message), ''), v_amount, v_amount)
      returning id into v_id;
      exit;
    exception when unique_violation then
      i := i + 1;
      if i > 5 then
        raise exception 'Failed to generate code';
      end if;
    end;
  end loop;

  return query select v_id, v_code;
end;
$$;

grant execute on function public.gift_card_purchase(numeric, text, text) to authenticated;

create or replace function public.gift_card_redeem(p_code text)
returns numeric
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v record;
  v_amount numeric(10,3);
begin
  if auth.uid() is null then
    raise exception 'Unauthorized';
  end if;

  select id, balance_bhd, status
  into v
  from public.gift_cards
  where code = upper(trim(p_code))
  limit 1
  for update;

  if v.id is null then
    raise exception 'Invalid code';
  end if;

  if v.status <> 'active' then
    raise exception 'Gift card not active';
  end if;

  v_amount := coalesce(v.balance_bhd, 0);
  if v_amount <= 0 then
    raise exception 'Gift card empty';
  end if;

  update public.gift_cards
  set status = 'redeemed',
      balance_bhd = 0,
      redeemed_at = now()
  where id = v.id;

  insert into public.gift_card_wallet (profile_id, balance_bhd, updated_at)
  values (auth.uid(), v_amount, now())
  on conflict (profile_id) do update
  set balance_bhd = public.gift_card_wallet.balance_bhd + excluded.balance_bhd,
      updated_at = now();

  insert into public.gift_card_redemptions (gift_card_id, profile_id, amount_bhd)
  values (v.id, auth.uid(), v_amount);

  return (select balance_bhd from public.gift_card_wallet where profile_id = auth.uid());
end;
$$;

grant execute on function public.gift_card_redeem(text) to authenticated;

alter table public.barbershops
add column if not exists home_service_enabled boolean not null default false,
add column if not exists home_service_visit_fee_bhd numeric(10,3) not null default 0,
add column if not exists home_service_radius_km double precision;

create or replace function public.search_home_service_shops(
  p_lat double precision,
  p_lng double precision,
  p_limit int default 30,
  p_offset int default 0
)
returns table (
  id uuid,
  name text,
  cover_url text,
  logo_url text,
  cover_path text,
  logo_path text,
  area text,
  address text,
  lat double precision,
  lng double precision,
  google_maps_url text,
  rating_avg numeric,
  rating_count int,
  home_service_visit_fee_bhd numeric,
  home_service_radius_km double precision,
  distance_km double precision
)
language sql
stable
as $$
  with ranked as (
    select
      s.id,
      s.name,
      s.cover_url,
      s.logo_url,
      s.cover_path,
      s.logo_path,
      s.area,
      s.address,
      s.lat,
      s.lng,
      s.google_maps_url,
      s.rating_avg,
      s.rating_count,
      s.home_service_visit_fee_bhd,
      s.home_service_radius_km,
      s.created_at,
      case
        when s.lat is null or s.lng is null then null
        else public.distance_km(p_lat, p_lng, s.lat, s.lng)
      end as distance_km
    from public.barbershops s
    where s.deleted_at is null
      and s.status = 'approved'
      and s.home_service_enabled = true
  )
  select
    ranked.id,
    ranked.name,
    ranked.cover_url,
    ranked.logo_url,
    ranked.cover_path,
    ranked.logo_path,
    ranked.area,
    ranked.address,
    ranked.lat,
    ranked.lng,
    ranked.google_maps_url,
    ranked.rating_avg,
    ranked.rating_count,
    ranked.home_service_visit_fee_bhd,
    ranked.home_service_radius_km,
    ranked.distance_km
  from ranked
  order by
    (ranked.distance_km is null) asc,
    ranked.distance_km asc,
    ranked.rating_avg desc,
    ranked.created_at desc
  limit greatest(p_limit, 0)
  offset greatest(p_offset, 0);
$$;

grant execute on function public.search_home_service_shops(double precision, double precision, int, int) to anon, authenticated;

alter table public.awards
add column if not exists winner_photo_url text,
add column if not exists winner_photo_path text,
add column if not exists stats jsonb not null default '{}'::jsonb,
add column if not exists reason text;

drop policy if exists "award_categories_public_read" on public.award_categories;
create policy "award_categories_public_read"
on public.award_categories
for select
to anon, authenticated
using (true);

drop policy if exists "awards_public_read" on public.awards;
create policy "awards_public_read"
on public.awards
for select
to anon, authenticated
using (true);

grant select on public.award_categories to anon, authenticated;
grant select on public.awards to anon, authenticated;

create or replace function public.business_health_score(p_entity_type text, p_entity_id uuid)
returns jsonb
language plpgsql
stable
set search_path = public
as $$
declare
  v_followers int := 0;
  v_reviews int := 0;
  v_rating numeric := 0;
  v_completed int := 0;
  v_total int := 0;
  v_completion numeric := 0;
  v_score int := 0;
begin
  if p_entity_type = 'barber' then
    select coalesce(followers_count, 0), coalesce(rating_count, 0), coalesce(rating_avg, 0)
    into v_followers, v_reviews, v_rating
    from public.barbers
    where id = p_entity_id;

    select
      count(*) filter (where status = 'completed')::int,
      count(*)::int
    into v_completed, v_total
    from public.bookings
    where barber_id = p_entity_id
      and start_at >= (now() - interval '30 days');
  elsif p_entity_type = 'shop' then
    select coalesce(followers_count, 0), coalesce(rating_count, 0), coalesce(rating_avg, 0)
    into v_followers, v_reviews, v_rating
    from public.barbershops
    where id = p_entity_id;

    select
      count(*) filter (where status = 'completed')::int,
      count(*)::int
    into v_completed, v_total
    from public.bookings
    where shop_id = p_entity_id
      and start_at >= (now() - interval '30 days');
  else
    return jsonb_build_object('score', 0, 'metrics', jsonb_build_object());
  end if;

  if coalesce(v_total, 0) > 0 then
    v_completion := (v_completed::numeric / v_total::numeric);
  else
    v_completion := 0;
  end if;

  v_score :=
    least(40, greatest(0, round(coalesce(v_rating, 0) * 8)))::int
    + least(20, greatest(0, round(ln(1 + greatest(v_followers, 0)) * 5)))::int
    + least(20, greatest(0, round(coalesce(v_completion, 0) * 20)))::int
    + least(20, greatest(0, round(least(1, coalesce(v_reviews, 0) / 120.0) * 20)))::int;

  return jsonb_build_object(
    'score', greatest(0, least(100, v_score)),
    'metrics', jsonb_build_object(
      'reviews', v_reviews,
      'completionRate', round(v_completion * 100),
      'followers', v_followers,
      'rating', v_rating,
      'bookings30d', v_total
    )
  );
end;
$$;

grant execute on function public.business_health_score(text, uuid) to anon, authenticated;

commit;

begin;

insert into public.admin_settings (key, value)
values
  ('maintenance_mode', jsonb_build_object('enabled', false)),
  ('require_post_approval', jsonb_build_object('enabled', true)),
  ('allow_customer_signup', jsonb_build_object('enabled', true))
on conflict (key) do nothing;

alter table public.barbershops add column if not exists deleted_at timestamptz;
alter table public.barbers add column if not exists deleted_at timestamptz;
alter table public.services add column if not exists deleted_at timestamptz;
alter table public.reels add column if not exists deleted_at timestamptz;

create index if not exists barbershops_deleted_idx on public.barbershops (deleted_at);
create index if not exists barbers_deleted_idx on public.barbers (deleted_at);
create index if not exists services_deleted_idx on public.services (deleted_at);
create index if not exists reels_deleted_idx on public.reels (deleted_at);

create index if not exists reels_feed_idx on public.reels (status, deleted_at, created_at desc);
create index if not exists reels_shop_feed_idx on public.reels (shop_id, status, deleted_at, created_at desc);
create index if not exists bookings_shop_status_start_idx on public.bookings (shop_id, status, start_at desc);

create or replace function public.get_setting_bool(p_key text, p_default boolean)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((value->>'enabled')::boolean, p_default)
  from public.admin_settings
  where key = p_key
$$;

do $$
begin
  if to_regprocedure('public.get_setting_bool(text, boolean)') is not null then
    if exists (select 1 from pg_roles where rolname = 'anon') then
      grant execute on function public.get_setting_bool(text, boolean) to anon;
    end if;
    if exists (select 1 from pg_roles where rolname = 'authenticated') then
      grant execute on function public.get_setting_bool(text, boolean) to authenticated;
    end if;
  end if;
end;
$$;

create or replace function public.enforce_protected_fields_barbershops()
returns trigger
language plpgsql
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if new.status is distinct from old.status then
    raise exception 'Not allowed';
  end if;
  if new.is_verified is distinct from old.is_verified then
    raise exception 'Not allowed';
  end if;
  if new.is_featured is distinct from old.is_featured then
    raise exception 'Not allowed';
  end if;
  if new.deleted_at is distinct from old.deleted_at then
    raise exception 'Not allowed';
  end if;

  return new;
end;
$$;

drop trigger if exists barbershops_protected_fields on public.barbershops;
create trigger barbershops_protected_fields
before update on public.barbershops
for each row
execute function public.enforce_protected_fields_barbershops();

create or replace function public.enforce_protected_fields_barbers()
returns trigger
language plpgsql
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if new.status is distinct from old.status then
    raise exception 'Not allowed';
  end if;
  if new.is_verified is distinct from old.is_verified then
    raise exception 'Not allowed';
  end if;
  if new.is_hallaq_certified is distinct from old.is_hallaq_certified then
    raise exception 'Not allowed';
  end if;
  if new.deleted_at is distinct from old.deleted_at then
    raise exception 'Not allowed';
  end if;

  return new;
end;
$$;

drop trigger if exists barbers_protected_fields on public.barbers;
create trigger barbers_protected_fields
before update on public.barbers
for each row
execute function public.enforce_protected_fields_barbers();

create or replace function public.set_reel_status_on_insert()
returns trigger
language plpgsql
as $$
declare
  require_approval boolean;
begin
  if public.is_admin() then
    return new;
  end if;

  require_approval := public.get_setting_bool('require_post_approval', true);
  if require_approval then
    new.status := 'pending';
  else
    new.status := 'approved';
  end if;

  new.is_featured := false;
  new.is_sponsored := false;
  new.approved_by := null;
  new.approved_at := null;
  new.rejected_by := null;
  new.rejected_at := null;
  new.rejection_reason := null;

  return new;
end;
$$;

drop trigger if exists reels_set_status_on_insert on public.reels;
create trigger reels_set_status_on_insert
before insert on public.reels
for each row
execute function public.set_reel_status_on_insert();

create or replace function public.enforce_reels_protected_fields()
returns trigger
language plpgsql
as $$
declare
  is_owner boolean;
begin
  if public.is_admin() then
    return new;
  end if;

  is_owner := exists (
    select 1
    from public.barbershops s
    where s.id = old.shop_id and s.owner_profile_id = auth.uid()
  )
  or exists (
    select 1
    from public.barbers b
    where b.id = old.barber_id and b.profile_id = auth.uid()
  );

  if new.status is distinct from old.status and new.status <> 'pending' then
    raise exception 'Not allowed';
  end if;
  if new.is_featured is distinct from old.is_featured then
    raise exception 'Not allowed';
  end if;
  if new.is_sponsored is distinct from old.is_sponsored then
    raise exception 'Not allowed';
  end if;
  if new.approved_by is distinct from old.approved_by then
    raise exception 'Not allowed';
  end if;
  if new.approved_at is distinct from old.approved_at then
    raise exception 'Not allowed';
  end if;
  if new.rejected_by is distinct from old.rejected_by then
    raise exception 'Not allowed';
  end if;
  if new.rejected_at is distinct from old.rejected_at then
    raise exception 'Not allowed';
  end if;
  if new.rejection_reason is distinct from old.rejection_reason then
    raise exception 'Not allowed';
  end if;
  if new.deleted_at is distinct from old.deleted_at then
    if is_owner and old.deleted_at is null and new.deleted_at is not null then
      return new;
    end if;
    raise exception 'Not allowed';
  end if;

  return new;
end;
$$;

drop trigger if exists reels_protected_fields on public.reels;
create trigger reels_protected_fields
before update on public.reels
for each row
execute function public.enforce_reels_protected_fields();

create or replace function public.enforce_booking_status_transition()
returns trigger
language plpgsql
as $$
declare
  is_owner boolean;
  is_barber boolean;
begin
  if public.is_admin() then
    return new;
  end if;

  if new.status is not distinct from old.status then
    return new;
  end if;

  is_owner := exists (select 1 from public.barbershops s where s.id = old.shop_id and s.owner_profile_id = auth.uid());
  is_barber := exists (select 1 from public.barbers b where b.id = old.barber_id and b.profile_id = auth.uid());

  if is_owner or is_barber then
    if old.status = 'pending' and new.status in ('confirmed','cancelled') then
      return new;
    end if;
    if old.status = 'confirmed' and new.status in ('completed','cancelled') then
      return new;
    end if;
    raise exception 'Not allowed';
  end if;

  if old.customer_profile_id = auth.uid() then
    if old.status = 'pending' and new.status = 'cancelled' then
      return new;
    end if;
    if old.status = 'confirmed' and new.status = 'cancelled' then
      return new;
    end if;
    raise exception 'Not allowed';
  end if;

  raise exception 'Not allowed';
end;
$$;

drop trigger if exists bookings_status_transition on public.bookings;
create trigger bookings_status_transition
before update of status on public.bookings
for each row
execute function public.enforce_booking_status_transition();

drop policy if exists "shops_public_read" on public.barbershops;
create policy "shops_public_read"
on public.barbershops
for select
to anon, authenticated
using (
  public.is_admin()
  or owner_profile_id = auth.uid()
  or (deleted_at is null and status = 'approved')
);

drop policy if exists "barbers_public_read" on public.barbers;
create policy "barbers_public_read"
on public.barbers
for select
to anon, authenticated
using (
  public.is_admin()
  or profile_id = auth.uid()
  or (shop_id is not null and exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid()))
  or (deleted_at is null and status = 'active' and is_verified = true)
);

drop policy if exists "reels_public_read" on public.reels;
create policy "reels_public_read"
on public.reels
for select
to anon, authenticated
using (
  public.is_admin()
  or (barber_id is not null and exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid()))
  or (shop_id is not null and exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid()))
  or (deleted_at is null and status = 'approved')
);

create or replace view public.shops with (security_invoker = true) as
select
  id,
  owner_profile_id as owner_id,
  name,
  logo_url,
  cover_url,
  description,
  area,
  address,
  lat as latitude,
  lng as longitude,
  phone,
  whatsapp,
  instagram,
  opening_hours,
  status,
  is_verified,
  is_featured,
  created_at
from public.barbershops
where deleted_at is null;

create or replace view public.posts with (security_invoker = true) as
select
  r.id,
  r.shop_id,
  r.barber_id,
  coalesce(b.profile_id, s.owner_profile_id) as created_by,
  coalesce(r.media_url, r.video_url, r.image_url) as media_url,
  r.media_type,
  r.thumbnail_url,
  r.caption,
  r.location,
  r.status,
  r.is_featured,
  r.likes_count,
  r.comments_count,
  r.saves_count,
  r.created_at
from public.reels r
left join public.barbers b on b.id = r.barber_id
left join public.barbershops s on s.id = r.shop_id
where r.deleted_at is null;

commit;

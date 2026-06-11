begin;

create or replace function public.ensure_shop_default_branch(p_shop_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_branch_id uuid;
begin
  if p_shop_id is null then
    return null;
  end if;

  select id
  into v_branch_id
  from public.shop_branches
  where shop_id = p_shop_id
    and name = 'Main Branch'
  order by created_at asc
  limit 1;

  if v_branch_id is not null then
    return v_branch_id;
  end if;

  insert into public.shop_branches (shop_id, name)
  values (p_shop_id, 'Main Branch')
  on conflict (shop_id, name) do nothing;

  select id
  into v_branch_id
  from public.shop_branches
  where shop_id = p_shop_id
    and name = 'Main Branch'
  order by created_at asc
  limit 1;

  return v_branch_id;
end;
$$;

create table if not exists public.shop_memberships (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  shop_id uuid not null references public.barbershops (id) on delete cascade,
  branch_id uuid not null references public.shop_branches (id) on delete cascade,
  membership_role text not null check (membership_role in ('owner', 'barber', 'receptionist')),
  is_primary boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists shop_memberships_unique_idx
  on public.shop_memberships (profile_id, shop_id, branch_id, membership_role);
create index if not exists shop_memberships_profile_idx
  on public.shop_memberships (profile_id, membership_role, created_at desc);
create index if not exists shop_memberships_shop_idx
  on public.shop_memberships (shop_id, membership_role, created_at desc);
create index if not exists shop_memberships_branch_idx
  on public.shop_memberships (branch_id, membership_role, created_at desc);

alter table public.shop_memberships enable row level security;

drop policy if exists "shop_memberships_read_own" on public.shop_memberships;
create policy "shop_memberships_read_own"
on public.shop_memberships
for select
to authenticated
using (
  profile_id = auth.uid()
  or public.is_admin()
  or public.is_shop_owner(shop_id)
);

drop policy if exists "shop_memberships_write_owner" on public.shop_memberships;
create policy "shop_memberships_write_owner"
on public.shop_memberships
for all
to authenticated
using (public.is_admin() or public.is_shop_owner(shop_id))
with check (public.is_admin() or public.is_shop_owner(shop_id));

drop trigger if exists shop_memberships_set_updated_at on public.shop_memberships;
create trigger shop_memberships_set_updated_at
before update on public.shop_memberships
for each row execute function public.set_updated_at();

insert into public.shop_branches (shop_id, name, area, address, lat, lng, opening_hours)
select
  s.id,
  'Main Branch',
  s.area,
  s.address,
  s.lat,
  s.lng,
  coalesce(s.opening_hours, '{}'::jsonb)
from public.barbershops s
where not exists (
  select 1
  from public.shop_branches sb
  where sb.shop_id = s.id
)
on conflict (shop_id, name) do nothing;

update public.barbers b
set branch_id = public.ensure_shop_default_branch(b.shop_id)
where b.shop_id is not null
  and b.branch_id is null;

update public.barbers
set branch_id = null
where shop_id is null
  and branch_id is not null;

insert into public.shop_memberships (profile_id, shop_id, branch_id, membership_role, is_primary)
select
  s.owner_profile_id,
  s.id,
  public.ensure_shop_default_branch(s.id),
  'owner',
  true
from public.barbershops s
where s.owner_profile_id is not null
on conflict (profile_id, shop_id, branch_id, membership_role) do update
set is_primary = excluded.is_primary,
    updated_at = now();

insert into public.shop_memberships (profile_id, shop_id, branch_id, membership_role, is_primary)
select
  b.profile_id,
  b.shop_id,
  coalesce(b.branch_id, public.ensure_shop_default_branch(b.shop_id)),
  'barber',
  true
from public.barbers b
where b.profile_id is not null
  and b.shop_id is not null
on conflict (profile_id, shop_id, branch_id, membership_role) do update
set is_primary = excluded.is_primary,
    updated_at = now();

insert into public.shop_memberships (profile_id, shop_id, branch_id, membership_role, is_primary)
select
  ss.profile_id,
  ss.shop_id,
  ss.branch_id,
  'receptionist',
  true
from public.shop_staff ss
where ss.profile_id is not null
on conflict (profile_id, shop_id, branch_id, membership_role) do update
set is_primary = excluded.is_primary,
    updated_at = now();

delete from public.shop_memberships sm
using public.barbershops s
where sm.membership_role = 'owner'
  and sm.shop_id = s.id
  and sm.profile_id is distinct from s.owner_profile_id;

update public.shop_memberships sm
set branch_id = public.ensure_shop_default_branch(sm.shop_id),
    is_primary = true,
    updated_at = now()
where sm.membership_role = 'owner';

with duplicate_owner_memberships as (
  select
    id,
    row_number() over (partition by shop_id, membership_role order by is_primary desc, created_at asc, id asc) as rn
  from public.shop_memberships
  where membership_role = 'owner'
)
delete from public.shop_memberships sm
using duplicate_owner_memberships d
where sm.id = d.id
  and d.rn > 1;

create unique index if not exists shop_memberships_one_owner_per_shop_idx
on public.shop_memberships (shop_id)
where membership_role = 'owner';

create or replace function public.enforce_shop_membership_consistency()
returns trigger
language plpgsql
as $$
declare
  branch_shop_id uuid;
  shop_owner_id uuid;
begin
  select sb.shop_id
  into branch_shop_id
  from public.shop_branches sb
  where sb.id = new.branch_id;

  if branch_shop_id is null then
    raise exception 'shop_membership_branch_missing';
  end if;

  if branch_shop_id is distinct from new.shop_id then
    raise exception 'shop_membership_branch_shop_mismatch';
  end if;

  if new.membership_role = 'owner' then
    select s.owner_profile_id
    into shop_owner_id
    from public.barbershops s
    where s.id = new.shop_id;

    if shop_owner_id is distinct from new.profile_id then
      raise exception 'shop_membership_owner_mismatch';
    end if;

    new.is_primary := true;
  end if;

  return new;
end;
$$;

drop trigger if exists shop_memberships_enforce_consistency on public.shop_memberships;
create trigger shop_memberships_enforce_consistency
before insert or update on public.shop_memberships
for each row execute function public.enforce_shop_membership_consistency();

create or replace function public.admin_create_shop(
  p_name text,
  p_area text default null,
  p_address text default null,
  p_phone text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'not_allowed';
  end if;

  raise exception 'deprecated_admin_create_shop_use_owner_profile_variant';
end;
$$;

create or replace function public.admin_create_shop(
  p_owner_profile_id uuid,
  p_name text,
  p_area text default null,
  p_address text default null,
  p_phone text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if not public.is_admin() then
    raise exception 'not_allowed';
  end if;

  if p_owner_profile_id is null then
    raise exception 'owner_profile_id_required';
  end if;

  insert into public.barbershops (owner_profile_id, name, area, address, phone)
  values (
    p_owner_profile_id,
    coalesce(p_name, ''),
    nullif(trim(p_area), ''),
    nullif(trim(p_address), ''),
    nullif(trim(p_phone), '')
  )
  returning id into v_id;

  perform public.sync_profile_role_from_entities(p_owner_profile_id);

  return v_id;
end;
$$;

comment on function public.admin_create_shop(text, text, text, text)
is 'DEPRECATED: use direct inserts or the admin_create_shop(uuid, text, text, text, text) variant that requires owner_profile_id.';

comment on function public.admin_create_shop(uuid, text, text, text, text)
is 'Creates a shop for a specific owner profile and keeps profile roles aligned.';

create or replace function public.admin_data_integrity_scan(p_limit int default 50)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  out jsonb;
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;

  out := jsonb_build_object(
    'generated_at', now(),

    'orphan_services', (
      select jsonb_agg(jsonb_build_object('id', s.id, 'shop_id', s.shop_id, 'barber_id', s.barber_id))
      from (
        select id, shop_id, barber_id
        from public.services
        where deleted_at is null
          and shop_id is null
          and barber_id is null
        order by created_at desc
        limit p_limit
      ) s
    ),

    'services_without_owner', (
      select jsonb_agg(jsonb_build_object('id', s.id, 'owner_type', s.owner_type, 'owner_id', s.owner_id))
      from (
        select id, owner_type, owner_id
        from public.services
        where deleted_at is null
          and (owner_type is null or btrim(owner_type) = '' or owner_id is null)
        order by created_at desc
        limit p_limit
      ) s
    ),

    'products_without_shop', (
      select jsonb_agg(jsonb_build_object('id', p.id, 'shop_id', p.shop_id))
      from (
        select id, shop_id
        from public.products
        where deleted_at is null
          and shop_id is null
        order by created_at desc
        limit p_limit
      ) p
    ),

    'reels_without_media', (
      select jsonb_agg(jsonb_build_object('id', r.id, 'media_type', r.media_type, 'media_path', r.media_path, 'media_url', r.media_url))
      from (
        select id, media_type, media_path, media_url
        from public.reels
        where deleted_at is null
          and (media_path is null or btrim(media_path) = '')
          and (media_url is null or btrim(media_url) = '')
        order by created_at desc
        limit p_limit
      ) r
    ),

    'broken_saved_items', (
      select jsonb_agg(jsonb_build_object('id', s.id, 'user_id', s.user_id, 'item_type', s.item_type, 'item_id', s.item_id))
      from (
        select id, user_id, item_type, item_id
        from public.saved_items
        where not (
          (item_type = 'shop' and exists (select 1 from public.barbershops sh where sh.id::text = item_id))
          or (item_type = 'barber' and exists (select 1 from public.barbers b where b.id::text = item_id))
          or (item_type = 'reel' and exists (select 1 from public.reels r where r.id::text = item_id))
        )
        order by created_at desc
        limit p_limit
      ) s
    ),

    'duplicate_emails', (
      select jsonb_agg(jsonb_build_object('email', x.email, 'count', x.cnt))
      from (
        select lower(btrim(email)) as email, count(*) as cnt
        from public.profiles
        where email is not null and btrim(email) <> ''
        group by lower(btrim(email))
        having count(*) > 1
        order by cnt desc, email asc
        limit p_limit
      ) x
    ),

    'duplicate_phone_numbers', (
      select jsonb_agg(jsonb_build_object('phone', x.phone, 'count', x.cnt))
      from (
        select btrim(phone) as phone, count(*) as cnt
        from public.profiles
        where phone is not null and btrim(phone) <> ''
        group by btrim(phone)
        having count(*) > 1
        order by cnt desc, phone asc
        limit p_limit
      ) x
    ),

    'shops_missing_branches', (
      select jsonb_agg(jsonb_build_object('shop_id', s.id, 'owner_profile_id', s.owner_profile_id, 'name', s.name))
      from (
        select s.id, s.owner_profile_id, s.name
        from public.barbershops s
        where not exists (
          select 1
          from public.shop_branches sb
          where sb.shop_id = s.id
        )
        order by s.created_at desc
        limit p_limit
      ) s
    ),

    'barbers_missing_branch', (
      select jsonb_agg(jsonb_build_object('barber_id', b.id, 'profile_id', b.profile_id, 'shop_id', b.shop_id))
      from (
        select b.id, b.profile_id, b.shop_id
        from public.barbers b
        where b.shop_id is not null
          and b.branch_id is null
        order by b.created_at desc
        limit p_limit
      ) b
    ),

    'ownership_role_mismatches', (
      select jsonb_agg(
        jsonb_build_object(
          'shop_id', s.id,
          'shop_name', s.name,
          'owner_profile_id', s.owner_profile_id,
          'owner_role', s.role
        )
      )
      from (
        select s.id, s.name, s.owner_profile_id, p.role
        from public.barbershops s
        join public.profiles p on p.id = s.owner_profile_id
        where s.owner_profile_id is not null
          and coalesce(p.role, '') <> 'shop_owner'
        order by s.created_at desc
        limit p_limit
      ) s
    ),

    'owner_membership_mismatches', (
      select jsonb_agg(
        jsonb_build_object(
          'shop_id', s.id,
          'shop_name', s.name,
          'owner_profile_id', s.owner_profile_id,
          'owner_membership_count', s.owner_membership_count
        )
      )
      from (
        select
          s.id,
          s.name,
          s.owner_profile_id,
          (
            select count(*)
            from public.shop_memberships sm
            where sm.shop_id = s.id
              and sm.membership_role = 'owner'
              and sm.profile_id = s.owner_profile_id
          ) as owner_membership_count
        from public.barbershops s
        where s.owner_profile_id is not null
      ) s
      where s.owner_membership_count = 0
      limit p_limit
    ),

    'stale_owner_memberships', (
      select jsonb_agg(
        jsonb_build_object(
          'membership_id', sm.id,
          'shop_id', sm.shop_id,
          'profile_id', sm.profile_id,
          'actual_owner_profile_id', sm.owner_profile_id
        )
      )
      from (
        select sm.id, sm.shop_id, sm.profile_id, s.owner_profile_id
        from public.shop_memberships sm
        join public.barbershops s on s.id = sm.shop_id
        where sm.membership_role = 'owner'
          and sm.profile_id is distinct from s.owner_profile_id
        order by sm.created_at desc
        limit p_limit
      ) sm
    ),

    'barber_membership_mismatches', (
      select jsonb_agg(
        jsonb_build_object(
          'barber_id', b.id,
          'profile_id', b.profile_id,
          'shop_id', b.shop_id,
          'branch_id', b.branch_id
        )
      )
      from (
        select b.id, b.profile_id, b.shop_id, b.branch_id
        from public.barbers b
        where b.shop_id is not null
          and b.profile_id is not null
          and not exists (
            select 1
            from public.shop_memberships sm
            where sm.profile_id = b.profile_id
              and sm.shop_id = b.shop_id
              and sm.branch_id = b.branch_id
              and sm.membership_role = 'barber'
          )
        order by b.created_at desc
        limit p_limit
      ) b
    )
  );

  return coalesce(out, '{}'::jsonb);
end;
$$;

commit;

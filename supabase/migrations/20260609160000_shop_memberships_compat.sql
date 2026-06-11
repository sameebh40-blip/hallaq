begin;

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
set is_primary = excluded.is_primary;

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
set is_primary = excluded.is_primary;

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
set is_primary = excluded.is_primary;

create or replace function public.sync_shop_memberships_from_barbershops()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' or old.owner_profile_id is distinct from new.owner_profile_id then
    delete from public.shop_memberships
    where profile_id = old.owner_profile_id
      and shop_id = old.id
      and membership_role = 'owner';
  end if;

  if tg_op <> 'DELETE' and new.owner_profile_id is not null then
    insert into public.shop_memberships (profile_id, shop_id, branch_id, membership_role, is_primary)
    values (new.owner_profile_id, new.id, public.ensure_shop_default_branch(new.id), 'owner', true)
    on conflict (profile_id, shop_id, branch_id, membership_role) do update
    set is_primary = excluded.is_primary,
        updated_at = now();
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists barbershops_sync_memberships on public.barbershops;
create trigger barbershops_sync_memberships
after insert or update of owner_profile_id or delete on public.barbershops
for each row execute function public.sync_shop_memberships_from_barbershops();

create or replace function public.sync_shop_memberships_from_barbers()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE'
     or old.profile_id is distinct from new.profile_id
     or old.shop_id is distinct from new.shop_id
     or old.branch_id is distinct from new.branch_id then
    if old.shop_id is not null then
      delete from public.shop_memberships
      where profile_id = old.profile_id
        and shop_id = old.shop_id
        and membership_role = 'barber';
    end if;
  end if;

  if tg_op <> 'DELETE' and new.shop_id is not null and new.profile_id is not null then
    insert into public.shop_memberships (profile_id, shop_id, branch_id, membership_role, is_primary)
    values (new.profile_id, new.shop_id, coalesce(new.branch_id, public.ensure_shop_default_branch(new.shop_id)), 'barber', true)
    on conflict (profile_id, shop_id, branch_id, membership_role) do update
    set is_primary = excluded.is_primary,
        updated_at = now();
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists barbers_sync_memberships on public.barbers;
create trigger barbers_sync_memberships
after insert or update of profile_id, shop_id, branch_id or delete on public.barbers
for each row execute function public.sync_shop_memberships_from_barbers();

create or replace function public.sync_shop_memberships_from_shop_staff()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE'
     or old.profile_id is distinct from new.profile_id
     or old.shop_id is distinct from new.shop_id
     or old.branch_id is distinct from new.branch_id
     or old.staff_role is distinct from new.staff_role then
    delete from public.shop_memberships
    where profile_id = old.profile_id
      and shop_id = old.shop_id
      and branch_id = old.branch_id
      and membership_role = old.staff_role;
  end if;

  if tg_op <> 'DELETE' and new.profile_id is not null and new.shop_id is not null and new.branch_id is not null then
    insert into public.shop_memberships (profile_id, shop_id, branch_id, membership_role, is_primary)
    values (new.profile_id, new.shop_id, new.branch_id, new.staff_role, true)
    on conflict (profile_id, shop_id, branch_id, membership_role) do update
    set is_primary = excluded.is_primary,
        updated_at = now();
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists shop_staff_sync_memberships on public.shop_staff;
create trigger shop_staff_sync_memberships
after insert or update of profile_id, shop_id, branch_id, staff_role or delete on public.shop_staff
for each row execute function public.sync_shop_memberships_from_shop_staff();

commit;

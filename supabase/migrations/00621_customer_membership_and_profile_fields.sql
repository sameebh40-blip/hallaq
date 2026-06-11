begin;

alter table public.profiles
  add column if not exists bio text,
  add column if not exists location text,
  add column if not exists membership_tier text not null default 'Silver'
    check (membership_tier in ('Silver','Gold','Platinum'));

create table if not exists public.customer_membership (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  points integer not null default 0,
  tier text not null default 'Silver' check (tier in ('Silver','Gold','Platinum')),
  updated_at timestamptz not null default now(),
  unique (user_id)
);

alter table public.customer_membership enable row level security;

drop policy if exists "customer_membership_read_own" on public.customer_membership;
create policy "customer_membership_read_own"
on public.customer_membership
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "customer_membership_write_own" on public.customer_membership;
create policy "customer_membership_write_own"
on public.customer_membership
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create index if not exists customer_membership_user_updated_idx on public.customer_membership (user_id, updated_at desc);

create or replace function public.compute_membership_tier(points int)
returns text
language plpgsql
immutable
as $$
begin
  if points >= 1400 then
    return 'Platinum';
  elsif points >= 500 then
    return 'Gold';
  else
    return 'Silver';
  end if;
end;
$$;

create or replace function public.recompute_customer_membership(p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  pts int := 0;
  t text := 'Silver';
begin
  select coalesce(sum(l.delta), 0)::int
  into pts
  from public.loyalty_ledger l
  where l.profile_id = p_profile_id;

  t := public.compute_membership_tier(pts);

  insert into public.customer_membership (user_id, points, tier, updated_at)
  values (p_profile_id, pts, t, now())
  on conflict (user_id) do update
    set points = excluded.points,
        tier = excluded.tier,
        updated_at = excluded.updated_at;

  update public.profiles
  set membership_tier = t
  where id = p_profile_id;
end;
$$;

create or replace function public.customer_membership_sync_from_ledger()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  pid uuid;
begin
  pid := coalesce(new.profile_id, old.profile_id);
  if pid is not null then
    perform public.recompute_customer_membership(pid);
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists loyalty_ledger_sync_customer_membership on public.loyalty_ledger;
create trigger loyalty_ledger_sync_customer_membership
after insert or update or delete on public.loyalty_ledger
for each row
execute function public.customer_membership_sync_from_ledger();

create table if not exists public.profile_addresses (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  label text not null default '',
  line1 text not null default '',
  line2 text,
  city text,
  country text,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profile_addresses_profile_created_idx on public.profile_addresses (profile_id, created_at desc);

alter table public.profile_addresses enable row level security;

drop policy if exists "profile_addresses_read_own" on public.profile_addresses;
create policy "profile_addresses_read_own"
on public.profile_addresses
for select
to authenticated
using (profile_id = auth.uid());

drop policy if exists "profile_addresses_write_own" on public.profile_addresses;
create policy "profile_addresses_write_own"
on public.profile_addresses
for all
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

drop trigger if exists profile_addresses_set_updated_at on public.profile_addresses;
create trigger profile_addresses_set_updated_at
before update on public.profile_addresses
for each row execute function public.set_updated_at();

commit;


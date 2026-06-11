begin;

alter table public.profiles
add column if not exists must_change_password boolean not null default true;

update public.profiles
set must_change_password = false
where must_change_password is true;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role, email, phone, status, must_change_password)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    'customer',
    new.email,
    new.phone,
    'active',
    false
  )
  on conflict (id) do update
    set email = coalesce(public.profiles.email, excluded.email),
        phone = coalesce(public.profiles.phone, excluded.phone)
    where public.profiles.email is null or public.profiles.phone is null;

  return new;
end;
$$;

insert into public.profiles (id, full_name, role, email, phone, status, must_change_password)
select u.id, '', 'customer', u.email, u.phone, 'active', false
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null;

alter table public.barbershops
add column if not exists name_ar text,
add column if not exists tiktok text,
add column if not exists category text,
add column if not exists commission_rate numeric(5,2),
add column if not exists subscription_plan text;

alter table public.barbershops
drop constraint if exists barbershops_commission_rate_check;

alter table public.barbershops
add constraint barbershops_commission_rate_check
check (commission_rate is null or (commission_rate >= 0 and commission_rate <= 100));

alter table public.barbers
add column if not exists instagram text,
add column if not exists tiktok text,
add column if not exists specialties text[] not null default '{}'::text[],
add column if not exists experience_years int,
add column if not exists commission_rate numeric(5,2);

alter table public.barbers
drop constraint if exists barbers_experience_years_check;
alter table public.barbers
add constraint barbers_experience_years_check
check (experience_years is null or (experience_years >= 0 and experience_years <= 80));

alter table public.barbers
drop constraint if exists barbers_commission_rate_check;
alter table public.barbers
add constraint barbers_commission_rate_check
check (commission_rate is null or (commission_rate >= 0 and commission_rate <= 100));

create table if not exists public.barber_account_requests (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.barbershops (id) on delete cascade,
  requested_by_profile_id uuid not null references public.profiles (id) on delete cascade,
  full_name text not null default '',
  email text,
  phone text,
  notes text,
  status text not null default 'pending',
  decided_by_profile_id uuid references public.profiles (id) on delete set null,
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.barber_account_requests
drop constraint if exists barber_account_requests_status_check;

alter table public.barber_account_requests
add constraint barber_account_requests_status_check
check (status in ('pending','approved','rejected','cancelled'));

alter table public.barber_account_requests enable row level security;

drop trigger if exists barber_account_requests_set_updated_at on public.barber_account_requests;
create trigger barber_account_requests_set_updated_at
before update on public.barber_account_requests
for each row execute function public.set_updated_at();

drop policy if exists "barber_account_requests_admin_all" on public.barber_account_requests;
create policy "barber_account_requests_admin_all"
on public.barber_account_requests
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "barber_account_requests_insert_shop_owner" on public.barber_account_requests;
create policy "barber_account_requests_insert_shop_owner"
on public.barber_account_requests
for insert
to authenticated
with check (
  requested_by_profile_id = auth.uid()
  and public.is_shop_owner(shop_id)
  and status = 'pending'
);

drop policy if exists "barber_account_requests_read_related" on public.barber_account_requests;
create policy "barber_account_requests_read_related"
on public.barber_account_requests
for select
to authenticated
using (
  public.is_admin()
  or requested_by_profile_id = auth.uid()
  or public.is_shop_owner(shop_id)
);

drop policy if exists "barber_account_requests_update_owner_cancel" on public.barber_account_requests;
create policy "barber_account_requests_update_owner_cancel"
on public.barber_account_requests
for update
to authenticated
using (
  requested_by_profile_id = auth.uid()
  and status = 'pending'
)
with check (
  requested_by_profile_id = auth.uid()
  and status in ('pending','cancelled')
);

drop policy if exists "profiles_public_read" on public.profiles;
drop policy if exists "profiles_authenticated_read" on public.profiles;
create policy "profiles_authenticated_read"
on public.profiles
for select
to authenticated
using (true);

drop policy if exists "barbershops_public_read" on public.barbershops;

commit;


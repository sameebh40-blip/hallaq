begin;

create table if not exists public.loyalty_ledger (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  booking_id uuid references public.bookings (id) on delete set null,
  delta integer not null,
  reason text not null default '',
  created_at timestamptz not null default now(),
  unique (booking_id)
);

create index if not exists loyalty_ledger_profile_created_idx on public.loyalty_ledger (profile_id, created_at desc);

alter table public.loyalty_ledger enable row level security;

drop policy if exists "loyalty_ledger_read_own" on public.loyalty_ledger;
create policy "loyalty_ledger_read_own"
on public.loyalty_ledger
for select
to authenticated
using (profile_id = auth.uid());

drop policy if exists "loyalty_ledger_admin_all" on public.loyalty_ledger;
create policy "loyalty_ledger_admin_all"
on public.loyalty_ledger
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create or replace function public.award_loyalty_points_on_booking_completed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is distinct from old.status and new.status = 'completed' then
    insert into public.loyalty_ledger (profile_id, booking_id, delta, reason)
    values (new.customer_profile_id, new.id, 10, 'booking_completed')
    on conflict (booking_id) do nothing;

    update public.customers
    set loyalty_points = loyalty_points + 10
    where id = new.customer_profile_id;
  end if;

  return new;
end;
$$;

drop trigger if exists bookings_award_loyalty_points on public.bookings;
create trigger bookings_award_loyalty_points
after update of status on public.bookings
for each row
execute function public.award_loyalty_points_on_booking_completed();

create or replace function public.enforce_customers_protected_fields()
returns trigger
language plpgsql
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if new.loyalty_points is distinct from old.loyalty_points then
    raise exception 'Not allowed';
  end if;

  return new;
end;
$$;

drop trigger if exists customers_protected_fields on public.customers;
create trigger customers_protected_fields
before update on public.customers
for each row
execute function public.enforce_customers_protected_fields();

commit;


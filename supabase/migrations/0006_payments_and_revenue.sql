alter table public.bookings
add column if not exists total_price numeric(10,3),
add column if not exists currency text not null default 'BHD';

create or replace function public.set_booking_price_from_service()
returns trigger
language plpgsql
as $$
declare
  s_price numeric(10,3);
begin
  if new.total_price is null then
    select price into s_price from public.services where id = new.service_id;
    new.total_price = coalesce(s_price, 0);
  end if;
  if new.currency is null or new.currency = '' then
    new.currency = 'BHD';
  end if;
  return new;
end;
$$;

drop trigger if exists bookings_set_price_from_service on public.bookings;
create trigger bookings_set_price_from_service
before insert on public.bookings
for each row execute function public.set_booking_price_from_service();

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id) on delete cascade,
  payer_profile_id uuid not null references public.profiles (id) on delete cascade,
  payee_type text not null check (payee_type in ('barber','shop')),
  payee_id uuid not null,
  amount numeric(10,3) not null,
  currency text not null default 'BHD',
  provider text not null default 'manual',
  provider_reference text,
  status text not null default 'pending' check (status in ('pending','succeeded','failed','cancelled','refunded')),
  authorized_at timestamptz,
  captured_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_reference)
);

create index if not exists payments_booking_idx on public.payments (booking_id);
create index if not exists payments_payer_idx on public.payments (payer_profile_id, created_at desc);
create index if not exists payments_payee_idx on public.payments (payee_type, payee_id, created_at desc);

drop trigger if exists payments_set_updated_at on public.payments;
create trigger payments_set_updated_at
before update on public.payments
for each row execute function public.set_updated_at();

create table if not exists public.refunds (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments (id) on delete cascade,
  amount numeric(10,3) not null,
  currency text not null default 'BHD',
  provider text not null default 'manual',
  provider_reference text,
  status text not null default 'pending' check (status in ('pending','succeeded','failed','cancelled')),
  reason text,
  created_at timestamptz not null default now()
);

create index if not exists refunds_payment_idx on public.refunds (payment_id, created_at desc);

create or replace view public.shop_revenue_daily as
select
  p.payee_id as shop_id,
  date_trunc('day', coalesce(p.captured_at, p.created_at))::date as day,
  p.currency,
  sum(p.amount) filter (where p.status = 'succeeded') as gross_revenue,
  count(*) filter (where p.status = 'succeeded') as payments_count
from public.payments p
where p.payee_type = 'shop'
group by 1, 2, 3;

create or replace view public.barber_revenue_daily as
select
  p.payee_id as barber_id,
  date_trunc('day', coalesce(p.captured_at, p.created_at))::date as day,
  p.currency,
  sum(p.amount) filter (where p.status = 'succeeded') as gross_revenue,
  count(*) filter (where p.status = 'succeeded') as payments_count
from public.payments p
where p.payee_type = 'barber'
group by 1, 2, 3;

alter table public.payments enable row level security;
alter table public.refunds enable row level security;

drop policy if exists "payments_read_participants" on public.payments;
create policy "payments_read_participants"
on public.payments
for select
to authenticated
using (
  payer_profile_id = auth.uid()
  or (payee_type = 'barber' and public.is_barber_owner(payee_id))
  or (payee_type = 'shop' and public.is_shop_owner(payee_id))
  or public.is_admin()
);

drop policy if exists "payments_admin_all" on public.payments;
create policy "payments_admin_all"
on public.payments
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "refunds_read_participants" on public.refunds;
create policy "refunds_read_participants"
on public.refunds
for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.payments p
    where p.id = refunds.payment_id
      and (
        p.payer_profile_id = auth.uid()
        or (p.payee_type = 'barber' and public.is_barber_owner(p.payee_id))
        or (p.payee_type = 'shop' and public.is_shop_owner(p.payee_id))
      )
  )
);

drop policy if exists "refunds_admin_all" on public.refunds;
create policy "refunds_admin_all"
on public.refunds
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

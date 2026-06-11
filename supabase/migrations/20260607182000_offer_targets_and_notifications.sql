begin;

create table if not exists public.offer_targets (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid not null references public.offers (id) on delete cascade,
  customer_profile_id uuid not null references public.profiles (id) on delete cascade,
  barber_id uuid references public.barbers (id) on delete set null,
  shop_id uuid references public.barbershops (id) on delete set null,
  sent_by_profile_id uuid references public.profiles (id) on delete set null,
  status text not null default 'sent' check (status in ('sent','redeemed','expired','cancelled')),
  redeemed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists offer_targets_customer_idx on public.offer_targets (customer_profile_id, created_at desc);
create index if not exists offer_targets_offer_idx on public.offer_targets (offer_id, created_at desc);
create index if not exists offer_targets_barber_idx on public.offer_targets (barber_id, created_at desc);

alter table public.offer_targets enable row level security;

drop policy if exists "offer_targets_read_customer" on public.offer_targets;
create policy "offer_targets_read_customer"
on public.offer_targets
for select
to authenticated
using (public.is_admin() or customer_profile_id = auth.uid());

drop policy if exists "offer_targets_read_sender" on public.offer_targets;
create policy "offer_targets_read_sender"
on public.offer_targets
for select
to authenticated
using (public.is_admin() or (barber_id is not null and public.is_barber_owner(barber_id)) or (shop_id is not null and public.is_shop_owner(shop_id)));

drop policy if exists "offer_targets_insert_sender" on public.offer_targets;
create policy "offer_targets_insert_sender"
on public.offer_targets
for insert
to authenticated
with check (
  public.is_admin()
  or (barber_id is not null and public.is_barber_owner(barber_id))
  or (shop_id is not null and public.is_shop_owner(shop_id))
);

drop policy if exists "offer_targets_update_customer_redeem" on public.offer_targets;
create policy "offer_targets_update_customer_redeem"
on public.offer_targets
for update
to authenticated
using (public.is_admin() or customer_profile_id = auth.uid())
with check (public.is_admin() or customer_profile_id = auth.uid());

create or replace function public.on_offer_target_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_barber_name text;
  v_shop_name text;
  v_title text;
  v_body text;
begin
  v_title := 'New offer';
  v_barber_name := null;
  v_shop_name := null;

  if new.barber_id is not null then
    select b.display_name into v_barber_name from public.barbers b where b.id = new.barber_id;
  end if;
  if new.shop_id is not null then
    select s.name into v_shop_name from public.barbershops s where s.id = new.shop_id;
  end if;

  v_body := 'You received a new offer.';
  if coalesce(v_barber_name, '') <> '' then
    v_body := 'You received a new offer from ' || v_barber_name || '.';
  elsif coalesce(v_shop_name, '') <> '' then
    v_body := 'You received a new offer from ' || v_shop_name || '.';
  end if;

  perform public.notify(
    new.customer_profile_id,
    'offer_received',
    v_title,
    v_body,
    jsonb_build_object(
      'offer_id',
      new.offer_id,
      'offer_target_id',
      new.id,
      'barber_id',
      new.barber_id,
      'shop_id',
      new.shop_id
    )
  );

  return new;
end;
$$;

drop trigger if exists offer_targets_notify_insert on public.offer_targets;
create trigger offer_targets_notify_insert
after insert on public.offer_targets
for each row execute function public.on_offer_target_insert();

commit;


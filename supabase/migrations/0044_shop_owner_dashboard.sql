begin;

alter table public.barbers
add column if not exists status text not null default 'active'
check (status in ('active','on_leave','inactive'));

create index if not exists barbers_shop_status_idx on public.barbers (shop_id, status);

create or replace function public.enforce_shop_owner_barber_assignment()
returns trigger
language plpgsql
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if old.profile_id = auth.uid() then
    return new;
  end if;

  if not public.is_shop_owner(coalesce(new.shop_id, old.shop_id)) then
    raise exception 'Not allowed';
  end if;

  if new.profile_id is distinct from old.profile_id then raise exception 'Not allowed'; end if;
  if new.slug is distinct from old.slug then raise exception 'Not allowed'; end if;
  if new.address is distinct from old.address then raise exception 'Not allowed'; end if;
  if new.lat is distinct from old.lat then raise exception 'Not allowed'; end if;
  if new.lng is distinct from old.lng then raise exception 'Not allowed'; end if;
  if new.is_verified is distinct from old.is_verified then raise exception 'Not allowed'; end if;
  if new.is_hallaq_certified is distinct from old.is_hallaq_certified then raise exception 'Not allowed'; end if;
  if new.rating_avg is distinct from old.rating_avg then raise exception 'Not allowed'; end if;
  if new.rating_count is distinct from old.rating_count then raise exception 'Not allowed'; end if;
  if new.followers_count is distinct from old.followers_count then raise exception 'Not allowed'; end if;
  if new.reviews_count is distinct from old.reviews_count then raise exception 'Not allowed'; end if;
  if new.available_now is distinct from old.available_now then raise exception 'Not allowed'; end if;
  if new.waiting_time_min is distinct from old.waiting_time_min then raise exception 'Not allowed'; end if;
  if new.queue_length is distinct from old.queue_length then raise exception 'Not allowed'; end if;
  if new.badge_verified is distinct from old.badge_verified then raise exception 'Not allowed'; end if;
  if new.badge_elite is distinct from old.badge_elite then raise exception 'Not allowed'; end if;
  if new.badge_trending is distinct from old.badge_trending then raise exception 'Not allowed'; end if;
  if new.badge_top_rated is distinct from old.badge_top_rated then raise exception 'Not allowed'; end if;
  if new.badge_certified is distinct from old.badge_certified then raise exception 'Not allowed'; end if;
  if new.deleted_at is distinct from old.deleted_at then raise exception 'Not allowed'; end if;

  return new;
end;
$$;

create table if not exists public.customer_notes (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.barbershops (id) on delete cascade,
  customer_profile_id uuid not null references public.profiles (id) on delete cascade,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, customer_profile_id)
);

alter table public.customer_notes enable row level security;

drop policy if exists "customer_notes_read_shop_owner" on public.customer_notes;
create policy "customer_notes_read_shop_owner"
on public.customer_notes
for select
to authenticated
using (public.is_admin() or public.is_shop_owner(shop_id));

drop policy if exists "customer_notes_write_shop_owner" on public.customer_notes;
create policy "customer_notes_write_shop_owner"
on public.customer_notes
for all
to authenticated
using (public.is_admin() or public.is_shop_owner(shop_id))
with check (public.is_admin() or public.is_shop_owner(shop_id));

drop trigger if exists customer_notes_set_updated_at on public.customer_notes;
create trigger customer_notes_set_updated_at
before update on public.customer_notes
for each row execute function public.set_updated_at();

commit;

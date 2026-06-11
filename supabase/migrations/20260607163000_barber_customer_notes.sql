begin;

create table if not exists public.barber_customer_notes (
  id uuid primary key default gen_random_uuid(),
  barber_id uuid not null references public.barbers (id) on delete cascade,
  customer_profile_id uuid not null references public.profiles (id) on delete cascade,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (barber_id, customer_profile_id)
);

alter table public.barber_customer_notes enable row level security;

drop policy if exists "barber_customer_notes_read" on public.barber_customer_notes;
create policy "barber_customer_notes_read"
on public.barber_customer_notes
for select
to authenticated
using (public.is_admin() or public.is_barber_owner(barber_id));

drop policy if exists "barber_customer_notes_write" on public.barber_customer_notes;
create policy "barber_customer_notes_write"
on public.barber_customer_notes
for all
to authenticated
using (public.is_admin() or public.is_barber_owner(barber_id))
with check (public.is_admin() or public.is_barber_owner(barber_id));

drop trigger if exists barber_customer_notes_set_updated_at on public.barber_customer_notes;
create trigger barber_customer_notes_set_updated_at
before update on public.barber_customer_notes
for each row execute function public.set_updated_at();

commit;


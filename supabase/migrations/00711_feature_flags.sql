create table if not exists public.feature_flags (
  id uuid primary key default gen_random_uuid(),
  flag_key text not null unique,
  flag_name text not null,
  enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

create index if not exists feature_flags_enabled_idx on public.feature_flags (enabled);

alter table public.feature_flags enable row level security;

drop policy if exists "feature_flags_public_read" on public.feature_flags;
create policy "feature_flags_public_read"
on public.feature_flags
for select
to anon, authenticated
using (true);

drop policy if exists "feature_flags_admin_all" on public.feature_flags;
create policy "feature_flags_admin_all"
on public.feature_flags
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop trigger if exists feature_flags_set_updated_at on public.feature_flags;
create trigger feature_flags_set_updated_at
before update on public.feature_flags
for each row execute function public.set_updated_at();

insert into public.feature_flags (flag_key, flag_name, enabled)
values
  ('ai_haircut_studio', 'AI Haircut Studio', false),
  ('gift_cards', 'Gift Cards', false),
  ('home_service', 'Home Service', false),
  ('hallaq_city', 'Hallaq City', false),
  ('awards', 'Awards', false),
  ('waitlist', 'Waitlist', false),
  ('reception_mode', 'Reception Mode', false),
  ('customer_notes', 'Customer Notes', false),
  ('advanced_analytics', 'Advanced Analytics', false),
  ('referral_program', 'Referral Program', false)
on conflict (flag_key) do update
set flag_name = excluded.flag_name;

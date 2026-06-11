create table if not exists public.reel_hides (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  reel_id uuid not null references public.reels (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (profile_id, reel_id)
);

alter table public.reel_hides enable row level security;

drop policy if exists "reel_hides_read_own" on public.reel_hides;
create policy "reel_hides_read_own"
on public.reel_hides
for select
to authenticated
using (profile_id = auth.uid());

drop policy if exists "reel_hides_insert_own" on public.reel_hides;
create policy "reel_hides_insert_own"
on public.reel_hides
for insert
to authenticated
with check (profile_id = auth.uid());

drop policy if exists "reel_hides_delete_own" on public.reel_hides;
create policy "reel_hides_delete_own"
on public.reel_hides
for delete
to authenticated
using (profile_id = auth.uid());

create index if not exists reel_hides_profile_idx on public.reel_hides (profile_id, created_at desc);
create index if not exists reel_hides_reel_idx on public.reel_hides (reel_id);


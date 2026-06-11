create table if not exists public.reel_saves (
  id uuid primary key default gen_random_uuid(),
  reel_id uuid not null references public.reels (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (reel_id, profile_id)
);

create index if not exists reel_saves_profile_created_idx on public.reel_saves (profile_id, created_at desc);
create index if not exists reel_saves_reel_created_idx on public.reel_saves (reel_id, created_at desc);

alter table public.reel_saves enable row level security;

drop policy if exists "saves_public_read" on public.reel_saves;
create policy "saves_public_read"
on public.reel_saves
for select
to anon, authenticated
using (true);

drop policy if exists "saves_insert_own" on public.reel_saves;
create policy "saves_insert_own"
on public.reel_saves
for insert
to authenticated
with check (profile_id = auth.uid());

drop policy if exists "saves_delete_own" on public.reel_saves;
create policy "saves_delete_own"
on public.reel_saves
for delete
to authenticated
using (profile_id = auth.uid());

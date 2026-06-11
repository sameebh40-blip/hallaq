begin;

create table if not exists public.saved_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  item_type text not null check (item_type in ('barber','shop','reel')),
  item_id uuid not null,
  created_at timestamptz not null default now(),
  unique (user_id, item_type, item_id)
);

alter table public.saved_items enable row level security;

drop policy if exists "saved_items_read_own" on public.saved_items;
create policy "saved_items_read_own"
on public.saved_items
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "saved_items_write_own" on public.saved_items;
create policy "saved_items_write_own"
on public.saved_items
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create index if not exists saved_items_user_type_created_idx on public.saved_items (user_id, item_type, created_at desc);

do $$
begin
  if to_regclass('public.reel_saves') is not null then
    insert into public.saved_items (user_id, item_type, item_id, created_at)
    select profile_id, 'reel', reel_id, created_at
    from public.reel_saves
    on conflict (user_id, item_type, item_id) do nothing;
  end if;
end;
$$;

commit;


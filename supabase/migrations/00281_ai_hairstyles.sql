begin;

create table if not exists public.ai_style_requests (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  input_image_url text not null,
  status text not null default 'pending' check (status in ('pending','processing','succeeded','failed')),
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ai_style_requests_profile_created_idx on public.ai_style_requests (profile_id, created_at desc);

drop trigger if exists ai_style_requests_set_updated_at on public.ai_style_requests;
create trigger ai_style_requests_set_updated_at
before update on public.ai_style_requests
for each row execute function public.set_updated_at();

alter table public.ai_style_requests enable row level security;

drop policy if exists "ai_style_requests_read_own" on public.ai_style_requests;
create policy "ai_style_requests_read_own"
on public.ai_style_requests
for select
to authenticated
using (profile_id = auth.uid() or public.is_admin());

drop policy if exists "ai_style_requests_insert_own" on public.ai_style_requests;
create policy "ai_style_requests_insert_own"
on public.ai_style_requests
for insert
to authenticated
with check (profile_id = auth.uid());

drop policy if exists "ai_style_requests_update_own" on public.ai_style_requests;
create policy "ai_style_requests_update_own"
on public.ai_style_requests
for update
to authenticated
using (profile_id = auth.uid() or public.is_admin())
with check (profile_id = auth.uid() or public.is_admin());

create table if not exists public.ai_style_results (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.ai_style_requests (id) on delete cascade,
  style_key text not null,
  output_image_url text not null,
  created_at timestamptz not null default now(),
  unique (request_id, style_key)
);

create index if not exists ai_style_results_request_idx on public.ai_style_results (request_id, created_at desc);

alter table public.ai_style_results enable row level security;

drop policy if exists "ai_style_results_read_own" on public.ai_style_results;
create policy "ai_style_results_read_own"
on public.ai_style_results
for select
to authenticated
using (
  exists (select 1 from public.ai_style_requests r where r.id = request_id and (r.profile_id = auth.uid() or public.is_admin()))
);

drop policy if exists "ai_style_results_insert_admin" on public.ai_style_results;
create policy "ai_style_results_insert_admin"
on public.ai_style_results
for insert
to authenticated
with check (public.is_admin());

create table if not exists public.ai_style_saves (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  request_id uuid references public.ai_style_requests (id) on delete set null,
  style_key text not null,
  image_url text not null,
  barber_id uuid references public.barbers (id) on delete set null,
  shop_id uuid references public.barbershops (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists ai_style_saves_profile_created_idx on public.ai_style_saves (profile_id, created_at desc);

alter table public.ai_style_saves enable row level security;

drop policy if exists "ai_style_saves_read_own" on public.ai_style_saves;
create policy "ai_style_saves_read_own"
on public.ai_style_saves
for select
to authenticated
using (profile_id = auth.uid() or public.is_admin());

drop policy if exists "ai_style_saves_write_own" on public.ai_style_saves;
create policy "ai_style_saves_write_own"
on public.ai_style_saves
for all
to authenticated
using (profile_id = auth.uid() or public.is_admin())
with check (profile_id = auth.uid() or public.is_admin());

do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values ('ai-style', 'ai-style', true)
    on conflict (id) do nothing;
  end if;

  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_public_read" on storage.objects;
    create policy "storage_public_read"
    on storage.objects
    for select
    to anon, authenticated
    using (bucket_id in ('avatars','portfolio','reels-media','review-photos','haircut-history','service-images','shop-images','barber-images','post-media','review-images','products','ai-style'));

    drop policy if exists "storage_ai_style_write_own" on storage.objects;
    create policy "storage_ai_style_write_own"
    on storage.objects
    for insert
    to authenticated
    with check (
      bucket_id = 'ai-style'
      and split_part(name, '/', 1) = auth.uid()::text
    );

    drop policy if exists "storage_ai_style_update_own" on storage.objects;
    create policy "storage_ai_style_update_own"
    on storage.objects
    for update
    to authenticated
    using (
      bucket_id = 'ai-style'
      and split_part(name, '/', 1) = auth.uid()::text
    )
    with check (
      bucket_id = 'ai-style'
      and split_part(name, '/', 1) = auth.uid()::text
    );

    drop policy if exists "storage_ai_style_delete_own" on storage.objects;
    create policy "storage_ai_style_delete_own"
    on storage.objects
    for delete
    to authenticated
    using (
      bucket_id = 'ai-style'
      and split_part(name, '/', 1) = auth.uid()::text
    );

    drop policy if exists "storage_ai_style_admin_all" on storage.objects;
    create policy "storage_ai_style_admin_all"
    on storage.objects
    for all
    to authenticated
    using (bucket_id = 'ai-style' and public.is_admin())
    with check (bucket_id = 'ai-style' and public.is_admin());
  end if;
end;
$$;

commit;

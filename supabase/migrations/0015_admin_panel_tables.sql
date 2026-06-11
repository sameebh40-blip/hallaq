alter table public.reels
add column if not exists status text not null default 'approved' check (status in ('pending','approved','rejected')),
add column if not exists approved_by uuid references public.profiles (id),
add column if not exists approved_at timestamptz,
add column if not exists rejected_by uuid references public.profiles (id),
add column if not exists rejected_at timestamptz,
add column if not exists rejection_reason text,
add column if not exists is_featured boolean not null default false,
add column if not exists is_sponsored boolean not null default false,
add column if not exists hashtags text[] not null default '{}'::text[],
add column if not exists location text;

create index if not exists reels_status_created_idx on public.reels (status, created_at desc);
create index if not exists reels_featured_idx on public.reels (is_featured, created_at desc);
create index if not exists reels_sponsored_idx on public.reels (is_sponsored, created_at desc);

create table if not exists public.award_categories (
  id uuid primary key default gen_random_uuid(),
  name_en text not null,
  name_ar text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.awards (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.award_categories (id) on delete cascade,
  year int not null,
  target_type text not null check (target_type in ('barber','shop')),
  target_id uuid not null,
  created_at timestamptz not null default now(),
  unique (category_id, year, target_type, target_id)
);

create index if not exists awards_year_idx on public.awards (year desc);

create table if not exists public.admin_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles (id)
);

create table if not exists public.admin_activity_logs (
  id uuid primary key default gen_random_uuid(),
  actor_profile_id uuid references public.profiles (id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists admin_activity_logs_created_idx on public.admin_activity_logs (created_at desc);
create index if not exists admin_activity_logs_entity_idx on public.admin_activity_logs (entity_type, entity_id);

alter table public.award_categories enable row level security;
alter table public.awards enable row level security;
alter table public.admin_settings enable row level security;
alter table public.admin_activity_logs enable row level security;

drop policy if exists "award_categories_admin_all" on public.award_categories;
create policy "award_categories_admin_all"
on public.award_categories
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "awards_admin_all" on public.awards;
create policy "awards_admin_all"
on public.awards
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "admin_settings_admin_all" on public.admin_settings;
create policy "admin_settings_admin_all"
on public.admin_settings
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "admin_activity_logs_admin_all" on public.admin_activity_logs;
create policy "admin_activity_logs_admin_all"
on public.admin_activity_logs
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

do $$
begin
  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_reels_admin_insert" on storage.objects;
    create policy "storage_reels_admin_insert"
    on storage.objects
    for insert
    to authenticated
    with check (bucket_id = 'reels-media' and public.is_admin());

    drop policy if exists "storage_reels_admin_update" on storage.objects;
    create policy "storage_reels_admin_update"
    on storage.objects
    for update
    to authenticated
    using (bucket_id = 'reels-media' and public.is_admin())
    with check (bucket_id = 'reels-media' and public.is_admin());

    drop policy if exists "storage_reels_admin_delete" on storage.objects;
    create policy "storage_reels_admin_delete"
    on storage.objects
    for delete
    to authenticated
    using (bucket_id = 'reels-media' and public.is_admin());
  end if;
end;
$$;

create or replace function public.notify_admins(
  n_type text,
  n_title text,
  n_body text,
  n_data jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
as $$
begin
  insert into public.notifications (profile_id, type, title, body, data)
  select p.id, n_type, n_title, n_body, coalesce(n_data, '{}'::jsonb)
  from public.profiles p
  where p.role = 'admin';
end;
$$;

create or replace function public.notify_admins_on_role_request()
returns trigger
language plpgsql
as $$
begin
  perform public.notify_admins(
    'role_request',
    'New role request',
    coalesce(new.requested_role, 'role') || ' requested',
    jsonb_build_object('role_request_id', new.id, 'profile_id', new.profile_id, 'requested_role', new.requested_role)
  );
  return new;
end;
$$;

drop trigger if exists role_requests_notify_admins on public.role_requests;
create trigger role_requests_notify_admins
after insert on public.role_requests
for each row execute function public.notify_admins_on_role_request();

create or replace function public.notify_admins_on_reel_pending()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'pending' then
    perform public.notify_admins(
      'reel_pending',
      'New reel pending approval',
      coalesce(left(new.caption, 90), 'New reel upload'),
      jsonb_build_object('reel_id', new.id, 'barber_id', new.barber_id, 'shop_id', new.shop_id)
    );
  end if;
  return new;
end;
$$;

drop trigger if exists reels_notify_admins_pending on public.reels;
create trigger reels_notify_admins_pending
after insert on public.reels
for each row execute function public.notify_admins_on_reel_pending();

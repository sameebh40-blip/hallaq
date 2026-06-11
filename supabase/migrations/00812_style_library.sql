begin;

create table if not exists public.style_library (
  id uuid primary key default gen_random_uuid(),
  slug text not null,
  name_en text not null,
  name_ar text not null default '',
  description_en text,
  description_ar text,
  category text,
  ai_style_key text,
  cover_url text,
  cover_path text,
  views_count bigint not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (slug)
);

create index if not exists style_library_active_idx on public.style_library (is_active, created_at desc);
create index if not exists style_library_views_idx on public.style_library (views_count desc);

alter table public.style_library enable row level security;

drop policy if exists "style_library_read_public_active" on public.style_library;
create policy "style_library_read_public_active"
on public.style_library
for select
to anon, authenticated
using (is_active = true);

drop policy if exists "style_library_admin_all" on public.style_library;
create policy "style_library_admin_all"
on public.style_library
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop trigger if exists style_library_set_updated_at on public.style_library;
create trigger style_library_set_updated_at
before update on public.style_library
for each row execute function public.set_updated_at();

create table if not exists public.style_media (
  id uuid primary key default gen_random_uuid(),
  style_id uuid not null references public.style_library (id) on delete cascade,
  media_type text not null check (media_type in ('image','post')),
  image_url text,
  image_path text,
  post_id uuid references public.reels (id) on delete set null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists style_media_style_order_idx on public.style_media (style_id, sort_order asc, created_at desc);

alter table public.style_media enable row level security;

drop policy if exists "style_media_read_public" on public.style_media;
create policy "style_media_read_public"
on public.style_media
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.style_library s
    where s.id = style_media.style_id and s.is_active = true
  )
);

drop policy if exists "style_media_admin_all" on public.style_media;
create policy "style_media_admin_all"
on public.style_media
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create table if not exists public.style_barbers (
  id uuid primary key default gen_random_uuid(),
  style_id uuid not null references public.style_library (id) on delete cascade,
  barber_id uuid not null references public.barbers (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (style_id, barber_id)
);

create index if not exists style_barbers_style_idx on public.style_barbers (style_id, created_at desc);
create index if not exists style_barbers_barber_idx on public.style_barbers (barber_id, created_at desc);

alter table public.style_barbers enable row level security;

drop policy if exists "style_barbers_read_public" on public.style_barbers;
create policy "style_barbers_read_public"
on public.style_barbers
for select
to anon, authenticated
using (true);

drop policy if exists "style_barbers_write_owner" on public.style_barbers;
create policy "style_barbers_write_owner"
on public.style_barbers
for all
to authenticated
using (public.is_admin() or public.is_barber_owner(barber_id))
with check (public.is_admin() or public.is_barber_owner(barber_id));

create table if not exists public.style_shops (
  id uuid primary key default gen_random_uuid(),
  style_id uuid not null references public.style_library (id) on delete cascade,
  shop_id uuid not null references public.barbershops (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (style_id, shop_id)
);

create index if not exists style_shops_style_idx on public.style_shops (style_id, created_at desc);
create index if not exists style_shops_shop_idx on public.style_shops (shop_id, created_at desc);

alter table public.style_shops enable row level security;

drop policy if exists "style_shops_read_public" on public.style_shops;
create policy "style_shops_read_public"
on public.style_shops
for select
to anon, authenticated
using (true);

drop policy if exists "style_shops_write_owner" on public.style_shops;
create policy "style_shops_write_owner"
on public.style_shops
for all
to authenticated
using (public.is_admin() or public.is_shop_owner(shop_id))
with check (public.is_admin() or public.is_shop_owner(shop_id));

do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values ('style-library', 'style-library', true)
    on conflict (id) do update set public = excluded.public;
  end if;

  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_public_read_hallaq_master" on storage.objects;
    create policy "storage_public_read_hallaq_master"
    on storage.objects
    for select
    to anon, authenticated
    using (
      bucket_id in (
        'avatars',
        'profile-covers',
        'shop-images',
        'barber-images',
        'service-images',
        'products',
        'product-images',
        'portfolio',
        'reels',
        'reels-media',
        'post-media',
        'offer-images',
        'awards',
        'style-library'
      )
    );
  end if;
end;
$$;

commit;


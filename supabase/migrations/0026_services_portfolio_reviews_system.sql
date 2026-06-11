begin;

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid references public.barbershops (id) on delete set null,
  barber_id uuid references public.barbers (id) on delete set null,
  name_en text,
  name_ar text,
  description_en text,
  description_ar text,
  price_bhd numeric(10,3) not null default 0,
  duration_minutes int not null default 30,
  image_url text,
  category text,
  is_popular boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  owner_type text,
  owner_id uuid,
  name text,
  description text,
  price numeric(10,3),
  duration_min int,
  active boolean,
  deleted_at timestamptz
);

alter table public.services add column if not exists shop_id uuid references public.barbershops (id) on delete set null;
alter table public.services add column if not exists barber_id uuid references public.barbers (id) on delete set null;
alter table public.services add column if not exists name_en text;
alter table public.services add column if not exists name_ar text;
alter table public.services add column if not exists description_en text;
alter table public.services add column if not exists description_ar text;
alter table public.services add column if not exists price_bhd numeric(10,3) not null default 0;
alter table public.services add column if not exists duration_minutes int not null default 30;
alter table public.services add column if not exists image_url text;
alter table public.services add column if not exists category text;
alter table public.services add column if not exists is_popular boolean not null default false;
alter table public.services add column if not exists is_active boolean not null default true;
alter table public.services add column if not exists created_at timestamptz not null default now();
alter table public.services add column if not exists owner_type text;
alter table public.services add column if not exists owner_id uuid;
alter table public.services add column if not exists name text;
alter table public.services add column if not exists description text;
alter table public.services add column if not exists price numeric(10,3);
alter table public.services add column if not exists duration_min int;
alter table public.services add column if not exists active boolean;
alter table public.services add column if not exists deleted_at timestamptz;

update public.services
set
  shop_id = case when shop_id is null and owner_type = 'shop' then owner_id else shop_id end,
  barber_id = case when barber_id is null and owner_type = 'barber' then owner_id else barber_id end,
  is_active = coalesce(is_active, active, true),
  active = coalesce(active, is_active, true),
  price_bhd = coalesce(price_bhd, price, 0),
  price = coalesce(price, price_bhd, 0),
  duration_minutes = coalesce(duration_minutes, duration_min, 30),
  duration_min = coalesce(duration_min, duration_minutes, 30),
  name_en = case when coalesce(name_en, '') = '' and coalesce(name, '') <> '' then name else name_en end,
  name = case when coalesce(name, '') = '' and coalesce(name_en, '') <> '' then name_en else name end,
  description_en = case when coalesce(description_en, '') = '' and coalesce(description, '') <> '' then description else description_en end,
  description = case when coalesce(description, '') = '' and coalesce(description_en, '') <> '' then description_en else description end
where true;

update public.services
set is_active = false, active = false, deleted_at = coalesce(deleted_at, now())
where shop_id is null and barber_id is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'services_owner_check'
      and conrelid = 'public.services'::regclass
  ) then
    alter table public.services
    add constraint services_owner_check
    check (shop_id is not null or barber_id is not null) not valid;
  end if;
end $$;

create index if not exists services_shop_active_idx on public.services (shop_id, is_active, created_at desc);
create index if not exists services_barber_active_idx on public.services (barber_id, is_active, created_at desc);
create index if not exists services_popular_idx on public.services (is_popular, created_at desc);

create or replace function public.services_sync_legacy()
returns trigger
language plpgsql
as $$
begin
  if new.is_active is null and new.active is not null then
    new.is_active := new.active;
  end if;
  if new.active is null and new.is_active is not null then
    new.active := new.is_active;
  end if;

  if new.price_bhd is null and new.price is not null then
    new.price_bhd := new.price;
  end if;
  if new.price is null and new.price_bhd is not null then
    new.price := new.price_bhd;
  end if;

  if new.duration_minutes is null and new.duration_min is not null then
    new.duration_minutes := new.duration_min;
  end if;
  if new.duration_min is null and new.duration_minutes is not null then
    new.duration_min := new.duration_minutes;
  end if;

  if (new.name_en is null or btrim(new.name_en) = '') and new.name is not null and btrim(new.name) <> '' then
    new.name_en := new.name;
  end if;
  if (new.name is null or btrim(new.name) = '') and new.name_en is not null and btrim(new.name_en) <> '' then
    new.name := new.name_en;
  end if;

  if (new.description_en is null or btrim(new.description_en) = '') and new.description is not null and btrim(new.description) <> '' then
    new.description_en := new.description;
  end if;
  if (new.description is null or btrim(new.description) = '') and new.description_en is not null and btrim(new.description_en) <> '' then
    new.description := new.description_en;
  end if;

  if new.owner_type is null or btrim(new.owner_type) = '' then
    if new.barber_id is not null then
      new.owner_type := 'barber';
      new.owner_id := new.barber_id;
    elsif new.shop_id is not null then
      new.owner_type := 'shop';
      new.owner_id := new.shop_id;
    end if;
  end if;

  if new.owner_id is null and new.owner_type = 'barber' and new.barber_id is not null then
    new.owner_id := new.barber_id;
  end if;
  if new.owner_id is null and new.owner_type = 'shop' and new.shop_id is not null then
    new.owner_id := new.shop_id;
  end if;

  if new.shop_id is null and new.owner_type = 'shop' and new.owner_id is not null then
    new.shop_id := new.owner_id;
  end if;
  if new.barber_id is null and new.owner_type = 'barber' and new.owner_id is not null then
    new.barber_id := new.owner_id;
  end if;

  if new.is_active is null then
    new.is_active := true;
  end if;
  if new.active is null then
    new.active := new.is_active;
  end if;

  return new;
end;
$$;

drop trigger if exists services_sync_legacy on public.services;
create trigger services_sync_legacy
before insert or update on public.services
for each row execute function public.services_sync_legacy();

alter table public.services enable row level security;

drop policy if exists "services_public_read_active" on public.services;
create policy "services_public_read_active"
on public.services
for select
to anon, authenticated
using (is_active = true and deleted_at is null);

drop policy if exists "services_admin_all" on public.services;
create policy "services_admin_all"
on public.services
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "services_write_shop_owner" on public.services;
create policy "services_write_shop_owner"
on public.services
for all
to authenticated
using (
  shop_id is not null
  and public.is_shop_owner(shop_id)
  and (barber_id is null or exists (select 1 from public.barbers b where b.id = barber_id and b.shop_id = shop_id))
)
with check (
  shop_id is not null
  and public.is_shop_owner(shop_id)
  and (barber_id is null or exists (select 1 from public.barbers b where b.id = barber_id and b.shop_id = shop_id))
);

drop policy if exists "services_write_independent_barber" on public.services;
create policy "services_write_independent_barber"
on public.services
for all
to authenticated
using (
  barber_id is not null
  and exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid() and b.shop_id is null)
)
with check (
  barber_id is not null
  and exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid() and b.shop_id is null)
);

alter table public.portfolio_items add column if not exists barber_id uuid references public.barbers (id) on delete cascade;
alter table public.portfolio_items add column if not exists shop_id uuid references public.barbershops (id) on delete set null;
alter table public.portfolio_items add column if not exists image_url text;
alter table public.portfolio_items add column if not exists caption_en text;
alter table public.portfolio_items add column if not exists caption_ar text;
alter table public.portfolio_items add column if not exists category text;
alter table public.portfolio_items add column if not exists is_featured boolean not null default false;

create index if not exists portfolio_items_barber_featured_idx on public.portfolio_items (barber_id, is_featured desc, created_at desc);
create index if not exists portfolio_items_shop_featured_idx on public.portfolio_items (shop_id, is_featured desc, created_at desc);

create or replace function public.portfolio_items_sync_legacy()
returns trigger
language plpgsql
as $$
begin
  if new.barber_id is null and new.owner_type = 'barber' then
    new.barber_id := new.owner_id;
  end if;
  if new.shop_id is null and new.owner_type = 'shop' then
    new.shop_id := new.owner_id;
  end if;

  if new.owner_type is null or btrim(new.owner_type) = '' then
    if new.barber_id is not null then
      new.owner_type := 'barber';
      new.owner_id := new.barber_id;
    elsif new.shop_id is not null then
      new.owner_type := 'shop';
      new.owner_id := new.shop_id;
    end if;
  end if;

  if new.image_url is null and new.media_url is not null then
    new.image_url := new.media_url;
  end if;
  if new.media_url is null and new.image_url is not null then
    new.media_url := new.image_url;
  end if;

  if new.caption_en is null and new.caption is not null then
    new.caption_en := new.caption;
  end if;
  if new.caption is null and new.caption_en is not null then
    new.caption := new.caption_en;
  end if;

  if new.media_type is null then
    new.media_type := 'image';
  end if;

  return new;
end;
$$;

drop trigger if exists portfolio_items_sync_legacy on public.portfolio_items;
create trigger portfolio_items_sync_legacy
before insert or update on public.portfolio_items
for each row execute function public.portfolio_items_sync_legacy();

alter table public.reviews add column if not exists customer_profile_id uuid;
alter table public.reviews add column if not exists booking_id uuid references public.bookings (id) on delete set null;
alter table public.reviews add column if not exists target_type text;
alter table public.reviews add column if not exists target_id uuid;
alter table public.reviews add column if not exists rating int;
alter table public.reviews add column if not exists text text;
alter table public.reviews add column if not exists photo_url text;
alter table public.reviews add column if not exists created_at timestamptz not null default now();
alter table public.reviews add column if not exists customer_id uuid;
alter table public.reviews add column if not exists shop_id uuid references public.barbershops (id) on delete set null;
alter table public.reviews add column if not exists barber_id uuid references public.barbers (id) on delete set null;
alter table public.reviews add column if not exists comment text;
alter table public.reviews add column if not exists image_url text;
alter table public.reviews add column if not exists status text not null default 'published';

update public.reviews
set status = 'published'
where status is null;

create index if not exists reviews_barber_created_at_idx on public.reviews (barber_id, created_at desc);
create index if not exists reviews_shop_created_at_idx on public.reviews (shop_id, created_at desc);

create or replace function public.reviews_sync_targets()
returns trigger
language plpgsql
as $$
begin
  if new.customer_id is null and new.customer_profile_id is not null then
    new.customer_id := new.customer_profile_id;
  end if;
  if new.customer_profile_id is null and new.customer_id is not null then
    new.customer_profile_id := new.customer_id;
  end if;

  if new.barber_id is null and new.target_type = 'barber' and new.target_id is not null then
    new.barber_id := new.target_id;
  end if;
  if new.shop_id is null and new.target_type = 'shop' and new.target_id is not null then
    new.shop_id := new.target_id;
  end if;

  if (new.target_type is null or btrim(new.target_type) = '') or new.target_id is null then
    if new.barber_id is not null then
      new.target_type := 'barber';
      new.target_id := new.barber_id;
    elsif new.shop_id is not null then
      new.target_type := 'shop';
      new.target_id := new.shop_id;
    end if;
  end if;

  if new.comment is null and new.text is not null then
    new.comment := new.text;
  end if;
  if new.text is null and new.comment is not null then
    new.text := new.comment;
  end if;

  if new.image_url is null and new.photo_url is not null then
    new.image_url := new.photo_url;
  end if;
  if new.photo_url is null and new.image_url is not null then
    new.photo_url := new.image_url;
  end if;

  return new;
end;
$$;

drop trigger if exists reviews_sync_targets on public.reviews;
create trigger reviews_sync_targets
before insert or update on public.reviews
for each row execute function public.reviews_sync_targets();

drop policy if exists "reviews_customer_insert_after_booking" on public.reviews;
create policy "reviews_customer_insert_after_booking"
on public.reviews
for insert
to authenticated
with check (
  (customer_profile_id = auth.uid())
  and exists (
    select 1
    from public.bookings bk
    where bk.customer_profile_id = auth.uid()
      and (
        (barber_id is not null and bk.barber_id = barber_id)
        or (shop_id is not null and bk.shop_id = shop_id)
      )
      and bk.status in ('confirmed','completed')
  )
);

drop policy if exists "reviews_public_read" on public.reviews;
create policy "reviews_public_read"
on public.reviews
for select
to anon, authenticated
using (status = 'published' or public.is_admin());

do $$
begin
  if to_regclass('storage.buckets') is not null then
insert into storage.buckets (id, name, public)
values ('service-images', 'service-images', true)
on conflict (id) do nothing;
  end if;

  if to_regclass('storage.objects') is not null then

drop policy if exists "storage_public_read" on storage.objects;
create policy "storage_public_read"
on storage.objects
for select
to anon, authenticated
using (bucket_id in ('avatars','portfolio','reels-media','review-photos','haircut-history','service-images','shop-images','review-images'));

drop policy if exists "storage_service_images_write_shop_owner" on storage.objects;
create policy "storage_service_images_write_shop_owner"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'service-images'
  and split_part(name, '/', 1) = 'shops'
  and public.is_shop_owner((split_part(name, '/', 2))::uuid)
);

drop policy if exists "storage_service_images_update_shop_owner" on storage.objects;
create policy "storage_service_images_update_shop_owner"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'service-images'
  and split_part(name, '/', 1) = 'shops'
  and public.is_shop_owner((split_part(name, '/', 2))::uuid)
)
with check (
  bucket_id = 'service-images'
  and split_part(name, '/', 1) = 'shops'
  and public.is_shop_owner((split_part(name, '/', 2))::uuid)
);

drop policy if exists "storage_service_images_delete_shop_owner" on storage.objects;
create policy "storage_service_images_delete_shop_owner"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'service-images'
  and split_part(name, '/', 1) = 'shops'
  and public.is_shop_owner((split_part(name, '/', 2))::uuid)
);

drop policy if exists "storage_service_images_write_barber_owner" on storage.objects;
create policy "storage_service_images_write_barber_owner"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'service-images'
  and split_part(name, '/', 1) = 'barbers'
  and public.is_barber_owner((split_part(name, '/', 2))::uuid)
);

drop policy if exists "storage_service_images_update_barber_owner" on storage.objects;
create policy "storage_service_images_update_barber_owner"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'service-images'
  and split_part(name, '/', 1) = 'barbers'
  and public.is_barber_owner((split_part(name, '/', 2))::uuid)
)
with check (
  bucket_id = 'service-images'
  and split_part(name, '/', 1) = 'barbers'
  and public.is_barber_owner((split_part(name, '/', 2))::uuid)
);

drop policy if exists "storage_service_images_delete_barber_owner" on storage.objects;
create policy "storage_service_images_delete_barber_owner"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'service-images'
  and split_part(name, '/', 1) = 'barbers'
  and public.is_barber_owner((split_part(name, '/', 2))::uuid)
);

drop policy if exists "storage_service_images_admin_all" on storage.objects;
create policy "storage_service_images_admin_all"
on storage.objects
for all
to authenticated
using (bucket_id = 'service-images' and public.is_admin())
with check (bucket_id = 'service-images' and public.is_admin());
  end if;
end;
$$;

alter table public.bookings add column if not exists price_bhd numeric(10,3);
alter table public.bookings add column if not exists duration_minutes int;

do $$
declare
  default_names_en text[] := array[
    'Haircut',
    'Skin Fade',
    'Beard Trim',
    'Hair Wash',
    'Hair Styling',
    'Hot Towel Shave',
    'Beard Styling',
    'Facial Treatment',
    'Hair + Beard Package',
    'VIP Grooming Package',
    'Kids Haircut',
    'Kids Fade'
  ];
  default_names_ar text[] := array[
    'قص شعر',
    'تدرج سكن فيد',
    'تهذيب لحية',
    'غسيل شعر',
    'تصفيف شعر',
    'حلاقة بالمنشفة الحارة',
    'ترتيب لحية',
    'تنظيف وجه',
    'باقة شعر ولحية',
    'باقة VIP',
    'قص أطفال',
    'فيد أطفال'
  ];
  default_prices numeric[] := array[5,7,3,2,2,5,4,8,10,15,4,5];
  default_durations int[] := array[30,45,20,15,15,30,25,40,60,75,25,35];
begin
  insert into public.services (shop_id, barber_id, name_en, name_ar, price_bhd, duration_minutes, category, is_popular, is_active)
  select
    null,
    b.id,
    default_names_en[i],
    default_names_ar[i],
    default_prices[i],
    default_durations[i],
    'Default',
    (i <= 3),
    true
  from public.barbers b
  cross join generate_subscripts(default_names_en, 1) as i
  where not exists (select 1 from public.services s where s.barber_id = b.id and s.deleted_at is null);

  insert into public.services (shop_id, barber_id, name_en, name_ar, price_bhd, duration_minutes, category, is_popular, is_active)
  select
    s.id,
    null,
    default_names_en[i],
    default_names_ar[i],
    default_prices[i],
    default_durations[i],
    'Default',
    (i <= 3),
    true
  from public.barbershops s
  cross join generate_subscripts(default_names_en, 1) as i
  where not exists (select 1 from public.services sv where sv.shop_id = s.id and sv.barber_id is null and sv.deleted_at is null);
end $$;

do $$
declare
  demo_categories text[] := array['Fade','Beard','Kids','VIP','Before After','Hair Styling'];
  demo_customers uuid;
  has_status boolean;
begin
  if (select count(*) from public.portfolio_items) = 0 then
    insert into public.portfolio_items (owner_type, owner_id, barber_id, media_type, media_url, image_url, caption, caption_en, caption_ar, category, is_featured)
    select
      'barber',
      b.id,
      b.id,
      'image',
      'https://placehold.co/900x900/png?text=Hallaq',
      'https://placehold.co/900x900/png?text=Hallaq',
      'Premium cut',
      'Premium cut',
      'قصة فاخرة',
      demo_categories[((gs - 1) % array_length(demo_categories, 1)) + 1],
      (gs = 1)
    from (select id from public.barbers order by created_at desc limit 5) b
    cross join generate_series(1, 4) as gs;
  end if;

  if (select count(*) from public.reviews) = 0 then
    select p.id into demo_customers from public.profiles p where p.role = 'customer' order by p.created_at desc limit 1;
    if demo_customers is null then
      select p.id into demo_customers from public.profiles p order by p.created_at desc limit 1;
    end if;

    if demo_customers is not null then
      select exists (
        select 1
        from information_schema.columns
        where table_schema = 'public' and table_name = 'reviews' and column_name = 'status'
      ) into has_status;

      if has_status then
        insert into public.reviews (customer_profile_id, customer_id, target_type, target_id, barber_id, rating, text, comment, status)
        select
          demo_customers,
          demo_customers,
          'barber',
          b.id,
          b.id,
          5,
          'Excellent service, clean fade, and premium finish.',
          'Excellent service, clean fade, and premium finish.',
          'published'
        from (select id from public.barbers order by created_at desc limit 10) b
        cross join generate_series(1, 2) as gs;
      else
        insert into public.reviews (customer_profile_id, customer_id, target_type, target_id, barber_id, rating, text, comment)
        select
          demo_customers,
          demo_customers,
          'barber',
          b.id,
          b.id,
          5,
          'Excellent service, clean fade, and premium finish.',
          'Excellent service, clean fade, and premium finish.'
        from (select id from public.barbers order by created_at desc limit 10) b
        cross join generate_series(1, 2) as gs;
      end if;
    end if;
  end if;
end $$;

commit;

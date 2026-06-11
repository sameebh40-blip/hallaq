begin;

alter table public.barbershops add column if not exists phone text;
alter table public.barbershops add column if not exists whatsapp text;
alter table public.barbershops add column if not exists instagram text;
alter table public.barbershops add column if not exists is_verified boolean not null default false;
alter table public.barbershops add column if not exists is_featured boolean not null default false;
alter table public.barbershops add column if not exists opening_hours jsonb not null default '{}'::jsonb;

update public.barbershops
set
  is_verified = badge_verified,
  is_featured = badge_elite
where is_verified is distinct from badge_verified
   or is_featured is distinct from badge_elite;

create or replace function public.barbershops_sync_badges_from_flags()
returns trigger
language plpgsql
as $$
begin
  new.badge_verified := new.is_verified;
  new.badge_elite := new.is_featured;
  return new;
end;
$$;

drop trigger if exists barbershops_sync_badges_from_flags on public.barbershops;
create trigger barbershops_sync_badges_from_flags
before insert or update of is_verified, is_featured
on public.barbershops
for each row execute function public.barbershops_sync_badges_from_flags();

alter table public.barbers add column if not exists cover_url text;
alter table public.barbers add column if not exists specialty text;
alter table public.barbers add column if not exists address text;
alter table public.barbers add column if not exists lat double precision;
alter table public.barbers add column if not exists lng double precision;
alter table public.barbers add column if not exists is_independent boolean not null default false;
alter table public.barbers add column if not exists is_verified boolean not null default false;
alter table public.barbers add column if not exists is_hallaq_certified boolean not null default false;
alter table public.barbers add column if not exists followers_count int not null default 0;
alter table public.barbers add column if not exists reviews_count int not null default 0;

update public.barbers
set
  is_independent = (shop_id is null),
  is_verified = badge_verified,
  is_hallaq_certified = badge_certified;

alter table public.barbers drop constraint if exists barbers_independent_consistency;
alter table public.barbers add constraint barbers_independent_consistency
check (
  (shop_id is null and is_independent = true)
  or
  (shop_id is not null and is_independent = false)
);

create or replace function public.barbers_sync_flags()
returns trigger
language plpgsql
as $$
begin
  new.is_independent := (new.shop_id is null);
  new.badge_verified := new.is_verified;
  new.badge_certified := new.is_hallaq_certified;
  return new;
end;
$$;

drop trigger if exists barbers_sync_flags on public.barbers;
create trigger barbers_sync_flags
before insert or update of shop_id, is_verified, is_hallaq_certified
on public.barbers
for each row execute function public.barbers_sync_flags();

do $do$
begin
  if exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'reels'
      and c.relkind = 'r'
  ) then
    alter table public.reels add column if not exists shop_id uuid references public.barbershops (id) on delete set null;
    alter table public.reels alter column barber_id drop not null;
    alter table public.reels add column if not exists image_url text;
    alter table public.reels add column if not exists video_url text;
    alter table public.reels add column if not exists saves_count int not null default 0;

    update public.reels
    set
      image_url = case when media_type = 'image' then media_url else image_url end,
      video_url = case when media_type = 'video' then media_url else video_url end
    where (image_url is null and media_type = 'image')
       or (video_url is null and media_type = 'video');

    alter table public.reels drop constraint if exists reels_author_check;
    alter table public.reels add constraint reels_author_check check (barber_id is not null or shop_id is not null);

    create index if not exists reels_shop_created_at_idx on public.reels (shop_id, created_at desc);

    drop policy if exists "reels_write_barber_owner" on public.reels;
    create policy "reels_write_owner"
    on public.reels
    for insert
    to authenticated
    with check (
      (
        barber_id is not null
        and exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid())
      )
      or
      (
        shop_id is not null
        and exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid())
      )
    );

    drop policy if exists "reels_update_barber_owner" on public.reels;
    create policy "reels_update_owner"
    on public.reels
    for update
    to authenticated
    using (
      (
        barber_id is not null
        and exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid())
      )
      or
      (
        shop_id is not null
        and exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid())
      )
    )
    with check (
      (
        barber_id is not null
        and exists (select 1 from public.barbers b where b.id = barber_id and b.profile_id = auth.uid())
      )
      or
      (
        shop_id is not null
        and exists (select 1 from public.barbershops s where s.id = shop_id and s.owner_profile_id = auth.uid())
      )
    );

    create or replace function public.sync_reel_counters()
    returns trigger
    language plpgsql
    as $fn$
    begin
      if tg_table_name = 'reel_likes' then
        if (tg_op = 'INSERT') then
          update public.reels set likes_count = likes_count + 1 where id = new.reel_id;
          return new;
        end if;
        if (tg_op = 'DELETE') then
          update public.reels set likes_count = greatest(likes_count - 1, 0) where id = old.reel_id;
          return old;
        end if;
      end if;

      if tg_table_name = 'reel_comments' then
        if (tg_op = 'INSERT') then
          update public.reels set comments_count = comments_count + 1 where id = new.reel_id;
          return new;
        end if;
        if (tg_op = 'DELETE') then
          update public.reels set comments_count = greatest(comments_count - 1, 0) where id = old.reel_id;
          return old;
        end if;
      end if;

      if tg_table_name = 'reel_saves' then
        if (tg_op = 'INSERT') then
          update public.reels set saves_count = saves_count + 1 where id = new.reel_id;
          return new;
        end if;
        if (tg_op = 'DELETE') then
          update public.reels set saves_count = greatest(saves_count - 1, 0) where id = old.reel_id;
          return old;
        end if;
      end if;

      return null;
    end;
    $fn$;

    drop trigger if exists reel_saves_sync_counter on public.reel_saves;
    create trigger reel_saves_sync_counter
    after insert or delete on public.reel_saves
    for each row execute function public.sync_reel_counters();
  end if;
end;
$do$;

do $$
begin
  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_reels_write_owner" on storage.objects;
    create policy "storage_reels_write_owner"
    on storage.objects
    for insert
    to authenticated
    with check (
      bucket_id = 'reels-media'
      and (
        (
          split_part(name, '/', 1) = 'barbers'
          and public.is_barber_owner((split_part(name, '/', 2))::uuid)
        )
        or
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner((split_part(name, '/', 2))::uuid)
        )
      )
    );

    drop policy if exists "storage_reels_update_owner" on storage.objects;
    create policy "storage_reels_update_owner"
    on storage.objects
    for update
    to authenticated
    using (
      bucket_id = 'reels-media'
      and (
        (
          split_part(name, '/', 1) = 'barbers'
          and public.is_barber_owner((split_part(name, '/', 2))::uuid)
        )
        or
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner((split_part(name, '/', 2))::uuid)
        )
      )
    )
    with check (
      bucket_id = 'reels-media'
      and (
        (
          split_part(name, '/', 1) = 'barbers'
          and public.is_barber_owner((split_part(name, '/', 2))::uuid)
        )
        or
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner((split_part(name, '/', 2))::uuid)
        )
      )
    );

    drop policy if exists "storage_reels_delete_owner" on storage.objects;
    create policy "storage_reels_delete_owner"
    on storage.objects
    for delete
    to authenticated
    using (
      bucket_id = 'reels-media'
      and (
        (
          split_part(name, '/', 1) = 'barbers'
          and public.is_barber_owner((split_part(name, '/', 2))::uuid)
        )
        or
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner((split_part(name, '/', 2))::uuid)
        )
      )
    );
  end if;
end;
$$;

create or replace view public.shops with (security_invoker = true) as
select
  id,
  name,
  logo_url,
  cover_url,
  description,
  area,
  address,
  lat as latitude,
  lng as longitude,
  phone,
  whatsapp,
  instagram,
  is_verified,
  is_featured,
  opening_hours,
  created_at
from public.barbershops;

create or replace view public.appointments with (security_invoker = true) as
select
  id,
  customer_profile_id as customer_id,
  shop_id,
  barber_id,
  service_id,
  (start_at at time zone 'Asia/Bahrain')::date as appointment_date,
  (start_at at time zone 'Asia/Bahrain')::time as appointment_time,
  status,
  created_at
from public.bookings;

do $$
declare
  k "char";
begin
  select c.relkind into k
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'posts';

  if k is null then
    if exists (
      select 1
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = 'reels'
        and c.relkind = 'r'
    ) then
      create view public.posts with (security_invoker = true) as
      select
        id,
        shop_id,
        barber_id,
        image_url,
        video_url,
        caption,
        likes_count,
        comments_count,
        saves_count,
        created_at
      from public.reels;
    end if;
  elsif k = 'v' then
    if exists (
      select 1
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = 'reels'
        and c.relkind = 'r'
    ) then
      create or replace view public.posts with (security_invoker = true) as
      select
        id,
        shop_id,
        barber_id,
        image_url,
        video_url,
        caption,
        likes_count,
        comments_count,
        saves_count,
        created_at
      from public.reels;
    end if;
  end if;
end;
$$;

commit;

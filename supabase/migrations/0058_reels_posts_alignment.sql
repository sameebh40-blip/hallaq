begin;

alter table public.reels add column if not exists created_by uuid references public.profiles (id) on delete set null;
alter table public.reels add column if not exists owner_type text check (owner_type in ('admin','shop','barber'));
alter table public.reels add column if not exists shares_count int not null default 0;

update public.reels
set owner_type = case
  when barber_id is not null then 'barber'
  when shop_id is not null then 'shop'
  else 'admin'
end
where owner_type is null;

update public.reels r
set created_by = b.profile_id
from public.barbers b
where r.created_by is null
  and r.barber_id = b.id;

update public.reels r
set created_by = s.owner_profile_id
from public.barbershops s
where r.created_by is null
  and r.shop_id = s.id;

update public.reels
set created_by = approved_by
where created_by is null
  and approved_by is not null;

create or replace function public.reels_set_created_by()
returns trigger
language plpgsql
as $$
begin
  if new.created_by is null then
    new.created_by := auth.uid();
  end if;

  if new.owner_type is null then
    new.owner_type := case
      when new.barber_id is not null then 'barber'
      when new.shop_id is not null then 'shop'
      else 'admin'
    end;
  end if;

  return new;
end;
$$;

drop trigger if exists reels_set_created_by on public.reels;
create trigger reels_set_created_by
before insert on public.reels
for each row execute function public.reels_set_created_by();

drop policy if exists "reels_insert_shop_owner_for_barbers" on public.reels;
create policy "reels_insert_shop_owner_for_barbers"
on public.reels
for insert
to authenticated
with check (
  barber_id is not null
  and exists (
    select 1
    from public.barbers b
    join public.barbershops s on s.id = b.shop_id
    where b.id = barber_id and s.owner_profile_id = auth.uid()
  )
);

drop policy if exists "reels_update_shop_owner_for_barbers" on public.reels;
create policy "reels_update_shop_owner_for_barbers"
on public.reels
for update
to authenticated
using (
  barber_id is not null
  and exists (
    select 1
    from public.barbers b
    join public.barbershops s on s.id = b.shop_id
    where b.id = barber_id and s.owner_profile_id = auth.uid()
  )
)
with check (
  barber_id is not null
  and exists (
    select 1
    from public.barbers b
    join public.barbershops s on s.id = b.shop_id
    where b.id = barber_id and s.owner_profile_id = auth.uid()
  )
);

drop policy if exists "reels_delete_shop_owner_for_barbers" on public.reels;
create policy "reels_delete_shop_owner_for_barbers"
on public.reels
for delete
to authenticated
using (
  barber_id is not null
  and exists (
    select 1
    from public.barbers b
    join public.barbershops s on s.id = b.shop_id
    where b.id = barber_id and s.owner_profile_id = auth.uid()
  )
);

create or replace function public.increment_reel_share(reel uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  if auth.uid() is null then
    raise exception using message = 'FORBIDDEN';
  end if;

  update public.reels
  set shares_count = coalesce(shares_count, 0) + 1
  where id = reel
    and status = 'approved'
    and deleted_at is null
  returning shares_count into v_count;

  if v_count is null then
    raise exception using message = 'NOT_FOUND';
  end if;

  return v_count;
end;
$$;

do $$
begin
  if to_regprocedure('public.increment_reel_share(uuid)') is not null then
    revoke all on function public.increment_reel_share(uuid) from public;
  end if;

  if to_regprocedure('public.increment_reel_share(uuid)') is not null
     and exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.increment_reel_share(uuid) to authenticated;
  end if;
end;
$$;

do $$
begin
  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_reels_owner_insert" on storage.objects;
    create policy "storage_reels_owner_insert"
    on storage.objects
    for insert
    to authenticated
    with check (
      bucket_id = 'reels'
      and (
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner(split_part(name, '/', 2)::uuid)
        )
        or
        (
          split_part(name, '/', 1) = 'barbers'
          and (
            public.is_barber_owner(split_part(name, '/', 2)::uuid)
            or exists (
              select 1
              from public.barbers b
              join public.barbershops s on s.id = b.shop_id
              where b.id = split_part(name, '/', 2)::uuid and s.owner_profile_id = auth.uid()
            )
          )
        )
      )
    );

    drop policy if exists "storage_reels_owner_update" on storage.objects;
    create policy "storage_reels_owner_update"
    on storage.objects
    for update
    to authenticated
    using (
      bucket_id = 'reels'
      and (
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner(split_part(name, '/', 2)::uuid)
        )
        or
        (
          split_part(name, '/', 1) = 'barbers'
          and (
            public.is_barber_owner(split_part(name, '/', 2)::uuid)
            or exists (
              select 1
              from public.barbers b
              join public.barbershops s on s.id = b.shop_id
              where b.id = split_part(name, '/', 2)::uuid and s.owner_profile_id = auth.uid()
            )
          )
        )
      )
    )
    with check (
      bucket_id = 'reels'
      and (
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner(split_part(name, '/', 2)::uuid)
        )
        or
        (
          split_part(name, '/', 1) = 'barbers'
          and (
            public.is_barber_owner(split_part(name, '/', 2)::uuid)
            or exists (
              select 1
              from public.barbers b
              join public.barbershops s on s.id = b.shop_id
              where b.id = split_part(name, '/', 2)::uuid and s.owner_profile_id = auth.uid()
            )
          )
        )
      )
    );

    drop policy if exists "storage_reels_owner_delete" on storage.objects;
    create policy "storage_reels_owner_delete"
    on storage.objects
    for delete
    to authenticated
    using (
      bucket_id = 'reels'
      and (
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner(split_part(name, '/', 2)::uuid)
        )
        or
        (
          split_part(name, '/', 1) = 'barbers'
          and (
            public.is_barber_owner(split_part(name, '/', 2)::uuid)
            or exists (
              select 1
              from public.barbers b
              join public.barbershops s on s.id = b.shop_id
              where b.id = split_part(name, '/', 2)::uuid and s.owner_profile_id = auth.uid()
            )
          )
        )
      )
    );
  end if;
end;
$$;

drop view if exists public.posts cascade;
drop view if exists public.post_likes cascade;
drop view if exists public.post_saves cascade;
drop view if exists public.post_comments cascade;
drop view if exists public.follows_v2 cascade;

create view public.posts as
select
  r.id,
  r.created_by,
  r.owner_type,
  r.shop_id,
  r.barber_id,
  r.media_url,
  r.thumbnail_url,
  r.media_type,
  r.caption,
  r.hashtags,
  r.location,
  r.status,
  r.likes_count,
  r.comments_count,
  r.saves_count,
  r.shares_count,
  r.created_at
from public.reels r;

create view public.post_likes as
select id, reel_id as post_id, profile_id as user_id, created_at
from public.reel_likes;

create view public.post_saves as
select id, reel_id as post_id, profile_id as user_id, created_at
from public.reel_saves;

create view public.post_comments as
select id, reel_id as post_id, profile_id as user_id, text as comment, created_at
from public.reel_comments;

create view public.follows_v2 as
select
  id,
  profile_id as follower_id,
  case when target_type = 'shop' then target_id else null end as shop_id,
  case when target_type = 'barber' then target_id else null end as barber_id,
  created_at
from public.follows;

commit;

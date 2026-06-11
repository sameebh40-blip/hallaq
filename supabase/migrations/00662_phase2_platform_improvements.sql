begin;

create table if not exists public.shop_claim_requests (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.barbershops (id) on delete cascade,
  requester_profile_id uuid not null references public.profiles (id) on delete cascade,
  name text not null default '',
  phone text,
  email text,
  proof_text text,
  proof_image_path text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  decided_by_profile_id uuid references public.profiles (id) on delete set null,
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, requester_profile_id, status)
);

create index if not exists shop_claim_requests_shop_idx on public.shop_claim_requests (shop_id, created_at desc);
create index if not exists shop_claim_requests_requester_idx on public.shop_claim_requests (requester_profile_id, created_at desc);

alter table public.shop_claim_requests enable row level security;

drop policy if exists "shop_claim_requests_insert_own" on public.shop_claim_requests;
create policy "shop_claim_requests_insert_own"
on public.shop_claim_requests
for insert
to authenticated
with check (
  requester_profile_id = auth.uid()
  and status = 'pending'
);

drop policy if exists "shop_claim_requests_read_own_or_admin" on public.shop_claim_requests;
create policy "shop_claim_requests_read_own_or_admin"
on public.shop_claim_requests
for select
to authenticated
using (requester_profile_id = auth.uid() or public.is_admin());

drop policy if exists "shop_claim_requests_update_admin" on public.shop_claim_requests;
create policy "shop_claim_requests_update_admin"
on public.shop_claim_requests
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop trigger if exists shop_claim_requests_set_updated_at on public.shop_claim_requests;
create trigger shop_claim_requests_set_updated_at
before update on public.shop_claim_requests
for each row execute function public.set_updated_at();

create or replace function public.approve_shop_claim_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop_id uuid;
  v_requester uuid;
begin
  if not public.is_admin() then
    raise exception 'not_allowed';
  end if;

  select r.shop_id, r.requester_profile_id
  into v_shop_id, v_requester
  from public.shop_claim_requests r
  where r.id = p_request_id
  for update;

  if v_shop_id is null then
    raise exception 'not_found';
  end if;

  update public.shop_claim_requests
  set status = 'approved',
      decided_by_profile_id = auth.uid(),
      decided_at = now()
  where id = p_request_id
    and status = 'pending';

  update public.barbershops
  set owner_profile_id = v_requester
  where id = v_shop_id;

  update public.profiles
  set role = 'shop_owner'
  where id = v_requester
    and role in ('customer','barber');

  insert into public.notifications (profile_id, type, title, body, data)
  values (
    v_requester,
    'claim_approved',
    'Shop claim approved',
    'Your shop claim has been approved.',
    jsonb_build_object('shop_id', v_shop_id, 'request_id', p_request_id)
  );
end;
$$;

create or replace function public.reject_shop_claim_request(p_request_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop_id uuid;
  v_requester uuid;
begin
  if not public.is_admin() then
    raise exception 'not_allowed';
  end if;

  select r.shop_id, r.requester_profile_id
  into v_shop_id, v_requester
  from public.shop_claim_requests r
  where r.id = p_request_id
  for update;

  if v_shop_id is null then
    raise exception 'not_found';
  end if;

  update public.shop_claim_requests
  set status = 'rejected',
      decided_by_profile_id = auth.uid(),
      decided_at = now()
  where id = p_request_id
    and status = 'pending';

  insert into public.notifications (profile_id, type, title, body, data)
  values (
    v_requester,
    'claim_rejected',
    'Shop claim rejected',
    coalesce(nullif(trim(p_reason), ''), 'Your shop claim has been rejected.'),
    jsonb_build_object('shop_id', v_shop_id, 'request_id', p_request_id)
  );
end;
$$;

create or replace function public.admin_create_shop(
  p_name text,
  p_area text default null,
  p_address text default null,
  p_phone text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if not public.is_admin() then
    raise exception 'not_allowed';
  end if;

  insert into public.barbershops (owner_profile_id, name, area, address, phone)
  values (auth.uid(), coalesce(p_name, ''), nullif(trim(p_area), ''), nullif(trim(p_address), ''), nullif(trim(p_phone), ''))
  returning id into v_id;

  return v_id;
end;
$$;

alter table public.barbershops
add column if not exists about_us text,
add column if not exists story text,
add column if not exists years_in_business int,
add column if not exists specialties text[] not null default '{}'::text[],
add column if not exists awards text[] not null default '{}'::text[],
add column if not exists languages text[] not null default '{}'::text[];

create or replace function public.enforce_shop_owner_shop_update()
returns trigger
language plpgsql
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if old.owner_profile_id = auth.uid() then
    if new.owner_profile_id is distinct from old.owner_profile_id then raise exception 'Not allowed'; end if;
    if new.rating_avg is distinct from old.rating_avg then raise exception 'Not allowed'; end if;
    if new.rating_count is distinct from old.rating_count then raise exception 'Not allowed'; end if;
    if new.badge_verified is distinct from old.badge_verified then raise exception 'Not allowed'; end if;
    if new.badge_elite is distinct from old.badge_elite then raise exception 'Not allowed'; end if;
    if new.badge_trending is distinct from old.badge_trending then raise exception 'Not allowed'; end if;
    if new.badge_top_rated is distinct from old.badge_top_rated then raise exception 'Not allowed'; end if;
    if new.badge_certified is distinct from old.badge_certified then raise exception 'Not allowed'; end if;
    if new.deleted_at is distinct from old.deleted_at then raise exception 'Not allowed'; end if;
    return new;
  end if;

  raise exception 'Not allowed';
end;
$$;

drop trigger if exists barbershops_shop_owner_update_guard on public.barbershops;
create trigger barbershops_shop_owner_update_guard
before update on public.barbershops
for each row
execute function public.enforce_shop_owner_shop_update();

alter table public.offers
add column if not exists offer_type text not null default 'percentage' check (offer_type in ('percentage','fixed','package')),
add column if not exists discount_amount numeric(10,3),
add column if not exists package_details jsonb not null default '{}'::jsonb,
add column if not exists banner_path text,
add column if not exists banner_url text;

alter table public.favorites
drop constraint if exists favorites_target_type_check;

alter table public.favorites
add constraint favorites_target_type_check check (target_type in ('barber','shop','offer'));

create table if not exists public.before_after_items (
  id uuid primary key default gen_random_uuid(),
  barber_id uuid references public.barbers (id) on delete set null,
  shop_id uuid references public.barbershops (id) on delete set null,
  created_by_profile_id uuid references public.profiles (id) on delete set null,
  before_image_path text not null,
  after_image_path text not null,
  caption text,
  category text,
  approved_by uuid references public.profiles (id),
  approved_at timestamptz,
  rejected_by uuid references public.profiles (id),
  rejected_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists before_after_items_barber_idx on public.before_after_items (barber_id, created_at desc);
create index if not exists before_after_items_shop_idx on public.before_after_items (shop_id, created_at desc);

alter table public.before_after_items enable row level security;

drop policy if exists "before_after_items_read_public_approved" on public.before_after_items;
create policy "before_after_items_read_public_approved"
on public.before_after_items
for select
to anon, authenticated
using (approved_at is not null and rejected_at is null);

drop policy if exists "before_after_items_read_owner" on public.before_after_items;
create policy "before_after_items_read_owner"
on public.before_after_items
for select
to authenticated
using (
  public.is_admin()
  or (barber_id is not null and public.is_barber_owner(barber_id))
  or (shop_id is not null and public.is_shop_owner(shop_id))
  or (
    barber_id is not null
    and exists (
      select 1
      from public.barbers b
      join public.barbershops s on s.id = b.shop_id
      where b.id = barber_id
        and s.owner_profile_id = auth.uid()
    )
  )
);

drop policy if exists "before_after_items_write_owner" on public.before_after_items;
create policy "before_after_items_write_owner"
on public.before_after_items
for insert
to authenticated
with check (
  public.is_admin()
  or (barber_id is not null and public.is_barber_owner(barber_id))
  or (shop_id is not null and public.is_shop_owner(shop_id))
  or (
    barber_id is not null
    and exists (
      select 1
      from public.barbers b
      join public.barbershops s on s.id = b.shop_id
      where b.id = barber_id
        and s.owner_profile_id = auth.uid()
    )
  )
);

drop policy if exists "before_after_items_update_owner" on public.before_after_items;
create policy "before_after_items_update_owner"
on public.before_after_items
for update
to authenticated
using (
  public.is_admin()
  or (barber_id is not null and public.is_barber_owner(barber_id))
  or (shop_id is not null and public.is_shop_owner(shop_id))
  or (
    barber_id is not null
    and exists (
      select 1
      from public.barbers b
      join public.barbershops s on s.id = b.shop_id
      where b.id = barber_id
        and s.owner_profile_id = auth.uid()
    )
  )
)
with check (
  public.is_admin()
  or (barber_id is not null and public.is_barber_owner(barber_id))
  or (shop_id is not null and public.is_shop_owner(shop_id))
  or (
    barber_id is not null
    and exists (
      select 1
      from public.barbers b
      join public.barbershops s on s.id = b.shop_id
      where b.id = barber_id
        and s.owner_profile_id = auth.uid()
    )
  )
);

drop policy if exists "before_after_items_delete_owner" on public.before_after_items;
create policy "before_after_items_delete_owner"
on public.before_after_items
for delete
to authenticated
using (
  public.is_admin()
  or (barber_id is not null and public.is_barber_owner(barber_id))
  or (shop_id is not null and public.is_shop_owner(shop_id))
  or (
    barber_id is not null
    and exists (
      select 1
      from public.barbers b
      join public.barbershops s on s.id = b.shop_id
      where b.id = barber_id
        and s.owner_profile_id = auth.uid()
    )
  )
);

drop trigger if exists before_after_items_set_updated_at on public.before_after_items;
create trigger before_after_items_set_updated_at
before update on public.before_after_items
for each row execute function public.set_updated_at();

create table if not exists public.reel_view_events (
  id uuid primary key default gen_random_uuid(),
  reel_id uuid not null references public.reels (id) on delete cascade,
  viewer_profile_id uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists reel_view_events_reel_idx on public.reel_view_events (reel_id, created_at desc);
create index if not exists reel_view_events_viewer_idx on public.reel_view_events (viewer_profile_id, created_at desc);

alter table public.reel_view_events enable row level security;

drop policy if exists "reel_view_events_insert_authed" on public.reel_view_events;
create policy "reel_view_events_insert_authed"
on public.reel_view_events
for insert
to authenticated
with check (viewer_profile_id = auth.uid());

drop policy if exists "reel_view_events_read_public" on public.reel_view_events;
create policy "reel_view_events_read_public"
on public.reel_view_events
for select
to anon, authenticated
using (true);

create or replace view public.barber_public_stats as
with booking_counts as (
  select
    b.barber_id,
    count(*) filter (where b.status in ('confirmed','completed')) as total_bookings,
    count(*) filter (where b.status = 'completed') as completed_bookings,
    count(*) filter (where b.status = 'cancelled') as cancelled_bookings
  from public.bookings b
  where b.barber_id is not null
  group by b.barber_id
),
portfolio_counts as (
  select
    p.barber_id,
    count(*) as portfolio_count
  from public.portfolio_items p
  where p.barber_id is not null
    and coalesce(p.approved_at, now()) is not null
    and p.rejected_at is null
  group by p.barber_id
),
before_after_counts as (
  select
    i.barber_id,
    count(*) as before_after_count
  from public.before_after_items i
  where i.barber_id is not null
    and i.approved_at is not null
    and i.rejected_at is null
  group by i.barber_id
),
reel_views as (
  select
    r.barber_id,
    count(v.*) as reel_views
  from public.reels r
  join public.reel_view_events v on v.reel_id = r.id
  where r.barber_id is not null
  group by r.barber_id
)
select
  br.id as barber_id,
  floor(extract(epoch from (now() - br.created_at)) / (365.25 * 24 * 60 * 60))::int as years_experience,
  coalesce(bc.total_bookings, 0)::int as total_bookings,
  br.rating_avg::numeric(10,2) as average_rating,
  coalesce(rt.avg_minutes, null) as response_time_minutes,
  case
    when (coalesce(bc.completed_bookings, 0) + coalesce(bc.cancelled_bookings, 0)) = 0 then null
    else (coalesce(bc.completed_bookings, 0)::numeric / (coalesce(bc.completed_bookings, 0) + coalesce(bc.cancelled_bookings, 0))::numeric)::numeric(10,4)
  end as completion_rate,
  br.followers_count::int as followers,
  (coalesce(pc.portfolio_count, 0) + coalesce(bac.before_after_count, 0))::int as portfolio_count,
  coalesce(rv.reel_views, 0)::int as reel_views
from public.barbers br
left join booking_counts bc on bc.barber_id = br.id
left join public.barber_response_time_minutes rt on rt.barber_id = br.id
left join portfolio_counts pc on pc.barber_id = br.id
left join before_after_counts bac on bac.barber_id = br.id
left join reel_views rv on rv.barber_id = br.id;

create or replace view public.trending_this_week as
with week as (
  select now() - interval '7 days' as start_at
),
most_booked_barber as (
  select
    b.barber_id as entity_id,
    count(*)::bigint as score
  from public.bookings b, week
  where b.barber_id is not null
    and b.start_at >= week.start_at
    and b.status in ('confirmed','completed')
  group by b.barber_id
  order by score desc
  limit 1
),
most_viewed_reel as (
  select
    v.reel_id as entity_id,
    count(*)::bigint as score
  from public.reel_view_events v, week
  where v.created_at >= week.start_at
  group by v.reel_id
  order by score desc
  limit 1
),
fastest_growing_barber as (
  select
    f.target_id as entity_id,
    count(*)::bigint as score
  from public.follows f, week
  where f.target_type = 'barber'
    and f.created_at >= week.start_at
  group by f.target_id
  order by score desc
  limit 1
),
most_followed_barber as (
  select
    b.id as entity_id,
    b.followers_count::bigint as score
  from public.barbers b
  order by b.followers_count desc
  limit 1
),
top_rated_shop as (
  select
    s.id as entity_id,
    (s.rating_avg::numeric * greatest(s.rating_count, 1)::numeric)::bigint as score
  from public.barbershops s
  where s.rating_count >= 5
  order by s.rating_avg desc, s.rating_count desc
  limit 1
),
top_rated_barber as (
  select
    b.id as entity_id,
    (b.rating_avg::numeric * greatest(b.rating_count, 1)::numeric)::bigint as score
  from public.barbers b
  where b.rating_count >= 5
  order by b.rating_avg desc, b.rating_count desc
  limit 1
)
select 'most_booked_barber'::text as kind, entity_id, score from most_booked_barber
union all
select 'most_viewed_reel'::text as kind, entity_id, score from most_viewed_reel
union all
select 'fastest_growing_barber'::text as kind, entity_id, score from fastest_growing_barber
union all
select 'most_followed_barber'::text as kind, entity_id, score from most_followed_barber
union all
select 'top_rated_shop'::text as kind, entity_id, score from top_rated_shop
union all
select 'top_rated_barber'::text as kind, entity_id, score from top_rated_barber;

do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values
      ('claim-proofs', 'claim-proofs', false),
      ('offer-images', 'offer-images', true),
      ('before-after', 'before-after', true)
    on conflict (id) do nothing;
  end if;

  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_public_read" on storage.objects;
    create policy "storage_public_read"
    on storage.objects
    for select
    to anon, authenticated
    using (bucket_id in ('avatars','portfolio','reels-media','review-photos','haircut-history','service-images','shop-images','barber-images','post-media','review-images','products','ai-style','offer-images','before-after'));

    drop policy if exists "storage_claim_proofs_read_own" on storage.objects;
    create policy "storage_claim_proofs_read_own"
    on storage.objects
    for select
    to authenticated
    using (
      bucket_id = 'claim-proofs'
      and (split_part(name, '/', 1) = auth.uid()::text or public.is_admin())
    );

    drop policy if exists "storage_claim_proofs_write_own" on storage.objects;
    create policy "storage_claim_proofs_write_own"
    on storage.objects
    for insert
    to authenticated
    with check (
      bucket_id = 'claim-proofs'
      and split_part(name, '/', 1) = auth.uid()::text
    );

    drop policy if exists "storage_claim_proofs_update_own" on storage.objects;
    create policy "storage_claim_proofs_update_own"
    on storage.objects
    for update
    to authenticated
    using (
      bucket_id = 'claim-proofs'
      and split_part(name, '/', 1) = auth.uid()::text
    )
    with check (
      bucket_id = 'claim-proofs'
      and split_part(name, '/', 1) = auth.uid()::text
    );

    drop policy if exists "storage_claim_proofs_delete_own" on storage.objects;
    create policy "storage_claim_proofs_delete_own"
    on storage.objects
    for delete
    to authenticated
    using (
      bucket_id = 'claim-proofs'
      and split_part(name, '/', 1) = auth.uid()::text
    );

    drop policy if exists "storage_offer_images_owner_insert" on storage.objects;
    create policy "storage_offer_images_owner_insert"
    on storage.objects
    for insert
    to authenticated
    with check (
      bucket_id = 'offer-images'
      and split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner(split_part(name, '/', 2)::uuid)
    );

    drop policy if exists "storage_offer_images_owner_update" on storage.objects;
    create policy "storage_offer_images_owner_update"
    on storage.objects
    for update
    to authenticated
    using (
      bucket_id = 'offer-images'
      and split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner(split_part(name, '/', 2)::uuid)
    )
    with check (
      bucket_id = 'offer-images'
      and split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner(split_part(name, '/', 2)::uuid)
    );

    drop policy if exists "storage_offer_images_owner_delete" on storage.objects;
    create policy "storage_offer_images_owner_delete"
    on storage.objects
    for delete
    to authenticated
    using (
      bucket_id = 'offer-images'
      and split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner(split_part(name, '/', 2)::uuid)
    );

    drop policy if exists "storage_before_after_owner_insert" on storage.objects;
    create policy "storage_before_after_owner_insert"
    on storage.objects
    for insert
    to authenticated
    with check (
      bucket_id = 'before-after'
      and (
        (
          split_part(name, '/', 1) = 'barbers'
          and (
            public.is_barber_owner(split_part(name, '/', 2)::uuid)
            or exists (
              select 1
              from public.barbers b
              join public.barbershops s on s.id = b.shop_id
              where b.id = split_part(name, '/', 2)::uuid
                and s.owner_profile_id = auth.uid()
            )
          )
        )
        or
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner(split_part(name, '/', 2)::uuid)
        )
        or public.is_admin()
      )
    );

    drop policy if exists "storage_before_after_owner_update" on storage.objects;
    create policy "storage_before_after_owner_update"
    on storage.objects
    for update
    to authenticated
    using (
      bucket_id = 'before-after'
      and (
        (
          split_part(name, '/', 1) = 'barbers'
          and (
            public.is_barber_owner(split_part(name, '/', 2)::uuid)
            or exists (
              select 1
              from public.barbers b
              join public.barbershops s on s.id = b.shop_id
              where b.id = split_part(name, '/', 2)::uuid
                and s.owner_profile_id = auth.uid()
            )
          )
        )
        or
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner(split_part(name, '/', 2)::uuid)
        )
        or public.is_admin()
      )
    )
    with check (
      bucket_id = 'before-after'
      and (
        (
          split_part(name, '/', 1) = 'barbers'
          and (
            public.is_barber_owner(split_part(name, '/', 2)::uuid)
            or exists (
              select 1
              from public.barbers b
              join public.barbershops s on s.id = b.shop_id
              where b.id = split_part(name, '/', 2)::uuid
                and s.owner_profile_id = auth.uid()
            )
          )
        )
        or
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner(split_part(name, '/', 2)::uuid)
        )
        or public.is_admin()
      )
    );

    drop policy if exists "storage_before_after_owner_delete" on storage.objects;
    create policy "storage_before_after_owner_delete"
    on storage.objects
    for delete
    to authenticated
    using (
      bucket_id = 'before-after'
      and (
        (
          split_part(name, '/', 1) = 'barbers'
          and (
            public.is_barber_owner(split_part(name, '/', 2)::uuid)
            or exists (
              select 1
              from public.barbers b
              join public.barbershops s on s.id = b.shop_id
              where b.id = split_part(name, '/', 2)::uuid
                and s.owner_profile_id = auth.uid()
            )
          )
        )
        or
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner(split_part(name, '/', 2)::uuid)
        )
        or public.is_admin()
      )
    );
  end if;
end;
$$;

commit;

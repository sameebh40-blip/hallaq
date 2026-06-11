begin;

create or replace function public.admin_data_integrity_scan(p_limit int default 50)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  out jsonb;
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;

  out := jsonb_build_object(
    'generated_at', now(),

    'orphan_services', (
      select jsonb_agg(jsonb_build_object('id', s.id, 'shop_id', s.shop_id, 'barber_id', s.barber_id))
      from (
        select id, shop_id, barber_id
        from public.services
        where deleted_at is null
          and shop_id is null
          and barber_id is null
        order by created_at desc
        limit p_limit
      ) s
    ),

    'services_without_owner', (
      select jsonb_agg(jsonb_build_object('id', s.id, 'owner_type', s.owner_type, 'owner_id', s.owner_id))
      from (
        select id, owner_type, owner_id
        from public.services
        where deleted_at is null
          and (owner_type is null or btrim(owner_type) = '' or owner_id is null)
        order by created_at desc
        limit p_limit
      ) s
    ),

    'products_without_shop', (
      select jsonb_agg(jsonb_build_object('id', p.id, 'shop_id', p.shop_id))
      from (
        select id, shop_id
        from public.products
        where deleted_at is null
          and shop_id is null
        order by created_at desc
        limit p_limit
      ) p
    ),

    'reels_without_media', (
      select jsonb_agg(jsonb_build_object('id', r.id, 'media_type', r.media_type, 'media_path', r.media_path, 'media_url', r.media_url))
      from (
        select id, media_type, media_path, media_url
        from public.reels
        where deleted_at is null
          and (media_path is null or btrim(media_path) = '')
          and (media_url is null or btrim(media_url) = '')
        order by created_at desc
        limit p_limit
      ) r
    ),

    'broken_saved_items', (
      select jsonb_agg(jsonb_build_object('id', s.id, 'user_id', s.user_id, 'item_type', s.item_type, 'item_id', s.item_id))
      from (
        select id, user_id, item_type, item_id
        from public.saved_items
        where not (
          (item_type = 'shop' and exists (select 1 from public.barbershops sh where sh.id::text = item_id))
          or (item_type = 'barber' and exists (select 1 from public.barbers b where b.id::text = item_id))
          or (item_type = 'reel' and exists (select 1 from public.reels r where r.id::text = item_id))
        )
        order by created_at desc
        limit p_limit
      ) s
    ),

    'duplicate_emails', (
      select jsonb_agg(jsonb_build_object('email', x.email, 'count', x.cnt))
      from (
        select lower(btrim(email)) as email, count(*) as cnt
        from public.profiles
        where email is not null and btrim(email) <> ''
        group by lower(btrim(email))
        having count(*) > 1
        order by cnt desc, email asc
        limit p_limit
      ) x
    ),

    'duplicate_phone_numbers', (
      select jsonb_agg(jsonb_build_object('phone', x.phone, 'count', x.cnt))
      from (
        select btrim(phone) as phone, count(*) as cnt
        from public.profiles
        where phone is not null and btrim(phone) <> ''
        group by btrim(phone)
        having count(*) > 1
        order by cnt desc, phone asc
        limit p_limit
      ) x
    )
  );

  return coalesce(out, '{}'::jsonb);
end;
$$;

create or replace function public.admin_fix_broken_saved_items(p_limit int default 200)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count int;
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;

  with targets as (
    select id
    from public.saved_items
    where not (
      (item_type = 'shop' and exists (select 1 from public.barbershops sh where sh.id::text = item_id))
      or (item_type = 'barber' and exists (select 1 from public.barbers b where b.id::text = item_id))
      or (item_type = 'reel' and exists (select 1 from public.reels r where r.id::text = item_id))
    )
    order by created_at desc
    limit p_limit
  ),
  del as (
    delete from public.saved_items s
    using targets t
    where s.id = t.id
    returning 1
  )
  select count(*) into deleted_count from del;

  return coalesce(deleted_count, 0);
end;
$$;

do $$
begin
  if to_regprocedure('public.admin_data_integrity_scan(int)') is not null then
    revoke all on function public.admin_data_integrity_scan(int) from public;
  end if;

  if to_regprocedure('public.admin_fix_broken_saved_items(int)') is not null then
    revoke all on function public.admin_fix_broken_saved_items(int) from public;
  end if;
end;
$$;

commit;

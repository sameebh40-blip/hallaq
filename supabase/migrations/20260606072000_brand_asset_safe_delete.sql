begin;

create or replace function public.brand_asset_usage(p_asset_key text)
returns table (entity text, field text, usage_count bigint)
language plpgsql
security definer
as $$
declare
  v_url text;
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;

  select b.asset_url
  into v_url
  from public.brand_assets b
  where b.asset_key = p_asset_key
    and b.asset_url is not null;

  v_url := coalesce(trim(v_url), '');
  if v_url = '' then
    return;
  end if;

  return query select 'profiles'::text, 'avatar_url'::text, count(*)::bigint from public.profiles where avatar_url = v_url;
  return query select 'profiles'::text, 'cover_url'::text, count(*)::bigint from public.profiles where cover_url = v_url;

  return query
  select 'barbershops'::text, 'logo_url'::text, count(*)::bigint
  from public.barbershops
  where deleted_at is null and logo_url = v_url;

  return query
  select 'barbershops'::text, 'cover_url'::text, count(*)::bigint
  from public.barbershops
  where deleted_at is null and cover_url = v_url;

  return query
  select 'barbers'::text, 'avatar_url'::text, count(*)::bigint
  from public.barbers
  where deleted_at is null and avatar_url = v_url;

  return query
  select 'barbers'::text, 'cover_url'::text, count(*)::bigint
  from public.barbers
  where deleted_at is null and cover_url = v_url;

  return query
  select 'services'::text, 'image_url'::text, count(*)::bigint
  from public.services
  where deleted_at is null and image_url = v_url;

  return query
  select 'products'::text, 'image_url'::text, count(*)::bigint
  from public.products
  where deleted_at is null and image_url = v_url;

  if to_regclass('public.reels') is not null then
    return query
    select 'reels'::text, 'thumbnail_url'::text, count(*)::bigint
    from public.reels
    where deleted_at is null and thumbnail_url = v_url;
  end if;

  if to_regclass('public.posts') is not null then
    return query
    select 'posts'::text, 'thumbnail_url'::text, count(*)::bigint
    from public.posts
    where deleted_at is null and thumbnail_url = v_url;
  end if;
end;
$$;

revoke all on function public.brand_asset_usage(text) from public;
grant execute on function public.brand_asset_usage(text) to authenticated;

commit;


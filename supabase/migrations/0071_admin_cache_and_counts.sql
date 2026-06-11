begin;

create or replace function public.admin_refresh_availability_cache(
  p_days_ahead int default 62,
  p_max_barbers int default 400,
  p_slot_minutes int default 30
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before int;
  v_after int;
begin
  if not public.is_admin() then
    raise exception using message = 'FORBIDDEN';
  end if;

  select count(*) into v_before from public.availability_cache_days;

  perform public.cleanup_availability_cache_days(p_days_ahead);
  perform public.warm_availability_cache_all(p_days_ahead, p_max_barbers, p_slot_minutes);

  select count(*) into v_after from public.availability_cache_days;

  return jsonb_build_object(
    'before', v_before,
    'after', v_after,
    'days_ahead', p_days_ahead,
    'max_barbers', p_max_barbers,
    'slot_minutes', p_slot_minutes
  );
end;
$$;

create or replace function public.admin_rebuild_social_counts()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reels int;
  v_barbers int;
  v_shops int;
  v_has_saves boolean;
begin
  if not public.is_admin() then
    raise exception using message = 'FORBIDDEN';
  end if;

  update public.reels r
  set likes_count = coalesce(x.c, 0)
  from (
    select reel_id, count(*)::int as c
    from public.reel_likes
    group by reel_id
  ) x
  where r.id = x.reel_id;

  update public.reels
  set likes_count = 0
  where likes_count <> 0
    and id not in (select reel_id from public.reel_likes);

  update public.reels r
  set comments_count = coalesce(x.c, 0)
  from (
    select reel_id, count(*)::int as c
    from public.reel_comments
    group by reel_id
  ) x
  where r.id = x.reel_id;

  update public.reels
  set comments_count = 0
  where comments_count <> 0
    and id not in (select reel_id from public.reel_comments);

  v_has_saves := to_regclass('public.reel_saves') is not null;
  if v_has_saves then
    execute $q$
      update public.reels r
      set saves_count = coalesce(x.c, 0)
      from (
        select reel_id, count(*)::int as c
        from public.reel_saves
        group by reel_id
      ) x
      where r.id = x.reel_id
    $q$;

    execute $q$
      update public.reels
      set saves_count = 0
      where saves_count <> 0
        and id not in (select reel_id from public.reel_saves)
    $q$;
  end if;

  update public.barbers b
  set followers_count = coalesce(x.c, 0)
  from (
    select target_id, count(*)::int as c
    from public.follows
    where target_type = 'barber'
    group by target_id
  ) x
  where b.id = x.target_id;

  update public.barbers
  set followers_count = 0
  where followers_count <> 0
    and id not in (select target_id from public.follows where target_type = 'barber');

  update public.barbershops s
  set followers_count = coalesce(x.c, 0)
  from (
    select target_id, count(*)::int as c
    from public.follows
    where target_type = 'shop'
    group by target_id
  ) x
  where s.id = x.target_id;

  update public.barbershops
  set followers_count = 0
  where followers_count <> 0
    and id not in (select target_id from public.follows where target_type = 'shop');

  select count(*)::int into v_reels from public.reels;
  select count(*)::int into v_barbers from public.barbers;
  select count(*)::int into v_shops from public.barbershops;

  return jsonb_build_object(
    'reels', v_reels,
    'barbers', v_barbers,
    'shops', v_shops,
    'has_reel_saves', v_has_saves
  );
end;
$$;

do $$
begin
  if to_regprocedure('public.admin_refresh_availability_cache(int,int,int)') is not null then
    revoke all on function public.admin_refresh_availability_cache(int,int,int) from public;
  end if;
  if to_regprocedure('public.admin_refresh_availability_cache(int,int,int)') is not null
     and exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.admin_refresh_availability_cache(int,int,int) to authenticated;
  end if;

  if to_regprocedure('public.admin_rebuild_social_counts()') is not null then
    revoke all on function public.admin_rebuild_social_counts() from public;
  end if;
  if to_regprocedure('public.admin_rebuild_social_counts()') is not null
     and exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.admin_rebuild_social_counts() to authenticated;
  end if;
end;
$$;

commit;


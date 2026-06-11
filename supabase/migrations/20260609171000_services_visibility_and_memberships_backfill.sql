begin;

do $$
declare
  v_has_shop_memberships boolean := to_regclass('public.shop_memberships') is not null;
  v_has_shop_branches boolean := to_regclass('public.shop_branches') is not null;
  v_has_shop_staff boolean := to_regclass('public.shop_staff') is not null;
  v_has_services boolean := to_regclass('public.services') is not null;
  v_has_is_active boolean := false;
  v_has_active boolean := false;
  v_has_status boolean := false;
  v_has_deleted_at boolean := false;
  v_has_ensure_branch boolean := to_regprocedure('public.ensure_shop_default_branch(uuid)') is not null;
  v_shop_id uuid;
  v_sql text;
begin
  if v_has_services then
    select exists (
      select 1
      from information_schema.columns
      where table_schema = 'public' and table_name = 'services' and column_name = 'is_active'
    ) into v_has_is_active;

    select exists (
      select 1
      from information_schema.columns
      where table_schema = 'public' and table_name = 'services' and column_name = 'active'
    ) into v_has_active;

    select exists (
      select 1
      from information_schema.columns
      where table_schema = 'public' and table_name = 'services' and column_name = 'status'
    ) into v_has_status;

    select exists (
      select 1
      from information_schema.columns
      where table_schema = 'public' and table_name = 'services' and column_name = 'deleted_at'
    ) into v_has_deleted_at;

    if v_has_is_active and v_has_active then
      execute $sql$
        update public.services
        set is_active = active
        where is_active is null
          and active is not null
      $sql$;
    end if;

    if v_has_status then
      v_sql := 'update public.services set status = ''approved'' where coalesce(trim(status), '''') = '''' and (shop_id is not null or barber_id is not null)';

      if v_has_deleted_at then
        v_sql := v_sql || ' and deleted_at is null';
      end if;

      if v_has_is_active and v_has_active then
        v_sql := v_sql || ' and coalesce(is_active, active, true) = true';
      elsif v_has_is_active then
        v_sql := v_sql || ' and coalesce(is_active, true) = true';
      elsif v_has_active then
        v_sql := v_sql || ' and coalesce(active, true) = true';
      end if;

      execute v_sql;
    end if;
  end if;

  if v_has_shop_branches and v_has_ensure_branch then
    for v_shop_id in
      select id from public.barbershops
    loop
      perform public.ensure_shop_default_branch(v_shop_id);
    end loop;

    update public.barbers
    set branch_id = public.ensure_shop_default_branch(shop_id)
    where shop_id is not null
      and branch_id is null;
  end if;

  if v_has_shop_memberships and v_has_ensure_branch then
    insert into public.shop_memberships (profile_id, shop_id, branch_id, membership_role, is_primary)
    select
      s.owner_profile_id,
      s.id,
      public.ensure_shop_default_branch(s.id),
      'owner',
      true
    from public.barbershops s
    where s.owner_profile_id is not null
    on conflict (profile_id, shop_id, branch_id, membership_role) do update
    set is_primary = excluded.is_primary,
        updated_at = now();

    insert into public.shop_memberships (profile_id, shop_id, branch_id, membership_role, is_primary)
    select
      b.profile_id,
      b.shop_id,
      coalesce(b.branch_id, public.ensure_shop_default_branch(b.shop_id)),
      'barber',
      true
    from public.barbers b
    where b.profile_id is not null
      and b.shop_id is not null
    on conflict (profile_id, shop_id, branch_id, membership_role) do update
    set is_primary = excluded.is_primary,
        updated_at = now();

    if v_has_shop_staff then
      insert into public.shop_memberships (profile_id, shop_id, branch_id, membership_role, is_primary)
      select
        ss.profile_id,
        ss.shop_id,
        ss.branch_id,
        'receptionist',
        true
      from public.shop_staff ss
      where ss.profile_id is not null
      on conflict (profile_id, shop_id, branch_id, membership_role) do update
      set is_primary = excluded.is_primary,
          updated_at = now();
    end if;
  end if;
end
$$;

commit;

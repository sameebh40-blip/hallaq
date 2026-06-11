begin;

do $$
declare
  c int;
begin
  select count(*)
  into c
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'create_booking';
  if c <> 1 then
    raise exception 'duplicate_function_create_booking_%', c;
  end if;

  select count(*)
  into c
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'create_booking_with_hold';
  if c <> 1 then
    raise exception 'duplicate_function_create_booking_with_hold_%', c;
  end if;

  select count(*)
  into c
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'hold_booking_slot';
  if c <> 1 then
    raise exception 'duplicate_function_hold_booking_slot_%', c;
  end if;

  select count(*)
  into c
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_available_times';
  if c <> 1 then
    raise exception 'duplicate_function_get_available_times_%', c;
  end if;
end
$$;

do $$
declare
  owner_profile uuid;
  barber_profile uuid;
  customer_profile uuid;
  customer2_profile uuid;
  v_has_service_barbers boolean := to_regclass('public.service_barbers') is not null;

  v_shop_id uuid;
  v_barber_id uuid;
  v_service_id uuid;

  v_start_at timestamptz;
  v_hold_id uuid;
  v_hold2_id uuid;
  v_hold3_id uuid;
  v_hold4_id uuid;

  v_booking1_id uuid;
  v_booking2_id uuid;
  v_booking3_id uuid;
  v_booking4_id uuid;

  c int;
  v_status text;
begin
  begin
    select p.id
    into owner_profile
    from public.profiles p
    where p.role = 'shop_owner'
      and not exists (
        select 1
        from public.barbers bx
        where bx.profile_id = p.id
      )
    order by p.created_at asc
    limit 1;

    if owner_profile is null then
      select p.id
      into owner_profile
      from public.profiles p
      where p.role <> 'admin'
        and not exists (
          select 1
          from public.barbers bx
          where bx.profile_id = p.id
        )
    order by p.created_at asc
    limit 1;
    end if;

    select b.profile_id
    into barber_profile
    from public.barbers b
    join public.profiles p on p.id = b.profile_id
    where p.role <> 'admin'
      and b.profile_id <> owner_profile
      and not exists (
        select 1
        from public.barbershops s
        where s.owner_profile_id = b.profile_id
      )
    order by p.created_at asc
    limit 1;

    if barber_profile is null then
      select p.id
      into barber_profile
      from public.profiles p
      where p.role <> 'admin'
        and p.id <> owner_profile
        and not exists (
          select 1
          from public.barbershops s
          where s.owner_profile_id = p.id
        )
      order by p.created_at asc
      limit 1;
    end if;

    select p.id
    into customer_profile
    from public.profiles p
    where p.role <> 'admin'
      and p.id <> owner_profile
      and p.id <> barber_profile
    order by p.created_at asc
    limit 1;

    select p.id
    into customer2_profile
    from public.profiles p
    where p.role <> 'admin'
      and p.id <> owner_profile
      and p.id <> barber_profile
      and p.id <> customer_profile
    order by p.created_at asc
    limit 1;

    customer2_profile := coalesce(customer2_profile, owner_profile);

    if owner_profile is null or barber_profile is null or customer_profile is null then
      raise exception 'Need 3 usable non-admin profiles (shop owner + barber + customer). Create users then re-run.';
    end if;

    select id
    into v_shop_id
    from public.barbershops
    where owner_profile_id = owner_profile
    order by created_at asc
    limit 1;

    if v_shop_id is null then
      insert into public.barbershops (owner_profile_id, name, status, is_active)
      values (owner_profile, 'Booking Regression Shop', 'approved', true)
      returning id into v_shop_id;
    else
      update public.barbershops
      set status = 'approved',
          is_active = true,
          deleted_at = null
      where id = v_shop_id;
    end if;

    select id into v_barber_id from public.barbers where profile_id = barber_profile order by created_at asc limit 1;
    if v_barber_id is null then
      insert into public.barbers (profile_id, shop_id, branch_id, display_name, is_independent, status, is_active)
      values (barber_profile, v_shop_id, public.ensure_shop_default_branch(v_shop_id), 'Booking Regression Barber', false, 'approved', true)
      returning id into v_barber_id;
    else
      execute 'update public.barbers set shop_id = $1, branch_id = public.ensure_shop_default_branch($1), is_independent = false, status = ''approved'', is_active = true, deleted_at = null where id = $2'
      using v_shop_id, v_barber_id;
    end if;

    insert into public.services (
      shop_id,
      barber_id,
      name_en,
      name_ar,
      price_bhd,
      duration_minutes,
      is_active,
      status,
      owner_type,
      owner_id,
      name,
      price,
      duration_min,
      active
    )
    values (
      v_shop_id,
      case when v_has_service_barbers then null else v_barber_id end,
      'Booking Regression Service',
      'Booking Regression Service',
      5,
      30,
      true,
      'approved',
      case when v_has_service_barbers then 'shop' else 'barber' end,
      case when v_has_service_barbers then v_shop_id else v_barber_id end,
      'Booking Regression Service',
      5,
      30,
      true
    )
    returning id into v_service_id;

    update public.services
    set deleted_at = null,
        is_active = true,
        status = 'approved'
    where id = v_service_id;

    if v_has_service_barbers then
      insert into public.service_barbers (service_id, barber_id)
      values (v_service_id, v_barber_id)
      on conflict do nothing;
    end if;

    perform set_config('request.jwt.claim.role', 'authenticated', true);
    execute 'set role authenticated';

    v_start_at := date_trunc('hour', now()) + interval '10 days';

    perform set_config('request.jwt.claim.sub', customer_profile::text, true);

    select t.hold_id into v_hold_id
    from public.hold_booking_slot(v_service_id, v_start_at, v_barber_id, v_shop_id, 5) as t;

    select b.id into v_booking1_id
    from public.create_booking_with_hold(
      v_service_id,
      v_start_at,
      v_barber_id,
      v_hold_id,
      v_shop_id,
      null::text,
      'cash'::text,
      null::uuid,
      'regression'::text,
      null::uuid,
      null::uuid,
      0::numeric
    ) as b;

    select count(*) into c from public.bookings where id = v_booking1_id;
    if c <> 1 then
      raise exception 'booking1 not created';
    end if;

    begin
      perform set_config('request.jwt.claim.sub', customer2_profile::text, true);
      perform public.hold_booking_slot(v_service_id, v_start_at, v_barber_id, v_shop_id, 5);
      raise exception 'Expected BOOKING_OVERLAP or SLOT_HELD for double booking';
    exception when others then
      if position('booking_overlap' in lower(sqlerrm)) = 0 and position('slot_held' in lower(sqlerrm)) = 0 then
        raise;
      end if;
    end;

    perform set_config('request.jwt.claim.sub', customer_profile::text, true);
    select t.hold_id into v_hold2_id
    from public.hold_booking_slot(v_service_id, v_start_at + interval '4 hours', v_barber_id, v_shop_id, 5) as t;

    update public.booking_slot_holds
    set expires_at = now() - interval '1 minute'
    where id = v_hold2_id;

    begin
      perform public.create_booking_with_hold(
        v_service_id,
        v_start_at + interval '4 hours',
        v_barber_id,
        v_hold2_id,
        v_shop_id,
        null::text,
        'cash'::text,
        null::uuid,
        'regression'::text,
        null::uuid,
        null::uuid,
        0::numeric
      );
      raise exception 'Expected HOLD_NOT_FOUND for expired hold';
    exception when others then
      if position('hold_not_found' in lower(sqlerrm)) = 0 then
        raise;
      end if;
    end;

    select t.hold_id into v_hold3_id
    from public.hold_booking_slot(v_service_id, v_start_at + interval '1 hour', v_barber_id, v_shop_id, 5) as t;

    select b.id into v_booking2_id
    from public.create_booking_with_hold(
      v_service_id,
      v_start_at + interval '1 hour',
      v_barber_id,
      v_hold3_id,
      v_shop_id,
      null::text,
      'cash'::text,
      null::uuid,
      'regression'::text,
      null::uuid,
      null::uuid,
      0::numeric
    ) as b;

    begin
      perform public.reschedule_booking(v_booking2_id, v_start_at + interval '15 minutes');
      raise exception 'Expected BOOKING_OVERLAP for reschedule overlap';
    exception when others then
      if position('booking_overlap' in lower(sqlerrm)) = 0 then
        raise;
      end if;
    end;

    select t.hold_id into v_hold4_id
    from public.hold_booking_slot(v_service_id, v_start_at + interval '2 hours', v_barber_id, v_shop_id, 5) as t;

    select b.id into v_booking3_id
    from public.create_booking_with_hold(
      v_service_id,
      v_start_at + interval '2 hours',
      v_barber_id,
      v_hold4_id,
      v_shop_id,
      null::text,
      'cash'::text,
      null::uuid,
      'regression'::text,
      null::uuid,
      null::uuid,
      0::numeric
    ) as b;

    perform set_config('request.jwt.claim.sub', owner_profile::text, true);
    perform public.mark_booking_no_show(v_booking3_id);
    select b.status into v_status from public.bookings b where b.id = v_booking3_id;
    if v_status <> 'no_show' then
      raise exception 'mark_booking_no_show failed';
    end if;

    begin
      perform public.complete_booking(v_booking3_id);
      raise exception 'Expected BOOKING_NOT_COMPLETABLE after no_show';
    exception when others then
      if position('booking_not_completable' in lower(sqlerrm)) = 0 then
        raise;
      end if;
    end;

    perform set_config('request.jwt.claim.sub', customer_profile::text, true);

    select t.hold_id into v_hold4_id
    from public.hold_booking_slot(v_service_id, v_start_at + interval '3 hours', v_barber_id, v_shop_id, 5) as t;

    select b.id into v_booking4_id
    from public.create_booking_with_hold(
      v_service_id,
      v_start_at + interval '3 hours',
      v_barber_id,
      v_hold4_id,
      v_shop_id,
      null::text,
      'cash'::text,
      null::uuid,
      'regression'::text,
      null::uuid,
      null::uuid,
      0::numeric
    ) as b;

    perform public.cancel_booking(v_booking4_id, 'regression');
    select b.status into v_status from public.bookings b where b.id = v_booking4_id;
    if v_status <> 'cancelled' then
      raise exception 'cancel_booking failed';
    end if;

    begin
      perform set_config('request.jwt.claim.sub', owner_profile::text, true);
      perform public.start_booking(v_booking4_id);
      raise exception 'Expected BOOKING_NOT_STARTABLE after cancel';
    exception when others then
      if position('booking_not_startable' in lower(sqlerrm)) = 0 then
        raise;
      end if;
    end;

    execute 'reset role';
  exception when others then
    execute 'reset role';
    raise;
  end;

  raise notice 'Booking regression test passed (rolled back).';
end
$$;

rollback;

begin;

do $$
declare
  owner_profile uuid;
  barber_profile uuid;
  customer_profile uuid;
  v_shop_id uuid;
  v_branch_id uuid;
  v_barber_id uuid;
  v_service_id uuid;
  v_hold_id uuid;
  v_start_at timestamptz;
  v_booking_id uuid;
  v_rescheduled_start_at timestamptz;
  v_status text;
  c int;
begin
  begin
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

    if owner_profile is null or barber_profile is null or customer_profile is null then
      raise exception 'Need 3 usable non-admin profiles (shop owner + barber + customer). Create users then re-run.';
    end if;

    select id into v_shop_id from public.barbershops where owner_profile_id = owner_profile order by created_at asc limit 1;
    if v_shop_id is null then
      insert into public.barbershops (owner_profile_id, name)
      values (owner_profile, 'Onboarding E2E Shop')
      returning id into v_shop_id;
    end if;

    update public.barbershops
    set is_active = true,
        status = 'approved',
        deleted_at = null
    where id = v_shop_id;

    select sb.id into v_branch_id
    from public.shop_branches sb
    where sb.shop_id = v_shop_id
    order by sb.created_at asc
    limit 1;

    if v_branch_id is null then
      raise exception 'shop_branches missing for shop';
    end if;

    select id into v_barber_id from public.barbers where profile_id = barber_profile order by created_at asc limit 1;
    if v_barber_id is null then
      insert into public.barbers (profile_id, shop_id, branch_id, display_name, is_independent, status, is_active)
      values (barber_profile, v_shop_id, public.ensure_shop_default_branch(v_shop_id), 'Onboarding E2E Barber', false, 'approved', true)
      returning id into v_barber_id;
    else
      update public.barbers
      set shop_id = v_shop_id,
          branch_id = public.ensure_shop_default_branch(v_shop_id),
          is_independent = false
      where id = v_barber_id;
    end if;

    update public.barbers
    set is_active = true,
        status = 'approved',
        deleted_at = null
    where id = v_barber_id;

    select count(*) into c
    from public.barbers b
    join public.shop_branches sb on sb.id = b.branch_id
    where b.id = v_barber_id
      and b.shop_id = v_shop_id
      and sb.shop_id = v_shop_id;

    if c <> 1 then
      raise exception 'barber branch linkage invalid';
    end if;

    insert into public.services (
      shop_id,
      barber_id,
      name_en,
      name_ar,
      price_bhd,
      duration_minutes,
      is_active,
      owner_type,
      owner_id,
      name,
      price,
      duration_min,
      active
    )
    values (
      v_shop_id,
      v_barber_id,
      'Onboarding E2E Service',
      'Onboarding E2E Service',
      5,
      30,
      true,
      'barber',
      v_barber_id,
      'Onboarding E2E Service',
      5,
      30,
      true
    )
    returning id into v_service_id;

    update public.services
    set is_active = true,
        status = 'approved',
        deleted_at = null
    where id = v_service_id;

    perform set_config('request.jwt.claim.role', 'authenticated', true);
    execute 'set role authenticated';
    perform set_config('request.jwt.claim.sub', customer_profile::text, true);

    select count(*) into c
    from public.get_available_times(v_barber_id, (now() + interval '10 days')::date, 30, 30);

    if c < 1 then
      raise exception 'get_available_times returned no slots';
    end if;

    v_start_at := date_trunc('hour', now()) + interval '10 days';

    select t.hold_id into v_hold_id
    from public.hold_booking_slot(v_service_id, v_start_at, v_barber_id, v_shop_id, 5) as t;

    if v_hold_id is null then
      raise exception 'hold_booking_slot did not return hold_id';
    end if;

    select b.id into v_booking_id
    from public.create_booking_with_hold(
      v_service_id,
      v_start_at,
      v_barber_id,
      v_hold_id,
      v_shop_id,
      null::text,
      'cash'::text,
      null::uuid,
      'onboarding_test'::text,
      null::uuid,
      null::uuid,
      0::numeric
    ) as b;

    if v_booking_id is null then
      raise exception 'create_booking_with_hold did not return booking id';
    end if;

    select count(*) into c from public.bookings where id = v_booking_id;
    if c <> 1 then
      raise exception 'booking not created';
    end if;

    v_rescheduled_start_at := v_start_at + interval '2 hours';
    perform public.reschedule_booking(v_booking_id, v_rescheduled_start_at);

    select count(*) into c
    from public.bookings b
    where b.id = v_booking_id
      and b.start_at = v_rescheduled_start_at
      and b.rescheduled_at is not null;

    if c <> 1 then
      raise exception 'booking was not rescheduled';
    end if;

    perform set_config('request.jwt.claim.sub', owner_profile::text, true);
    perform public.start_booking(v_booking_id);
    select b.status into v_status from public.bookings b where b.id = v_booking_id;
    if v_status <> 'in_progress' then
      raise exception 'booking was not started';
    end if;

    perform public.complete_booking(v_booking_id);
    select b.status into v_status from public.bookings b where b.id = v_booking_id;
    if v_status <> 'completed' then
      raise exception 'booking was not completed';
    end if;

    execute 'reset role';
  exception when others then
    execute 'reset role';
    raise;
  end;

  raise notice 'Onboarding+Booking E2E test passed (rolled back).';
end
$$;

rollback;

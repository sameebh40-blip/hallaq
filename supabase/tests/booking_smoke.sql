begin;

do $$
declare
  owner_profile uuid;
  barber_profile uuid;
  customer_profile uuid;
  other_barber_profile uuid;
  booking_profile uuid;
  v_has_service_barbers boolean := to_regclass('public.service_barbers') is not null;
  v_shop_id uuid;
  v_barber_id uuid;
  v_other_barber_id uuid;
  v_service_id uuid;
  v_hold_id uuid;
  hold_expires timestamptz;
  v_start_at timestamptz;
  v_booking_id uuid;
  v_no_show_booking_id uuid;
  v_cancel_booking_id uuid;
  v_payment_id uuid;
  v_payment_status text;
  v_rescheduled_start_at timestamptz;
  v_deposit_required numeric(10,3);
  c int;
  v_status text;
begin
  begin
    select p.id into owner_profile
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
      select p.id into owner_profile
      from public.profiles p
      where p.role = 'customer'
        and not exists (
          select 1
          from public.barbers bx
          where bx.profile_id = p.id
        )
      order by p.created_at asc
      limit 1;
    end if;

    if owner_profile is null then
      select p.id into owner_profile
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

    select b.profile_id into barber_profile
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
      select p.id into barber_profile
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

    select p.id into customer_profile
    from public.profiles p
    where p.role <> 'admin'
      and p.id <> owner_profile
      and p.id <> barber_profile
      and not exists (
        select 1
        from public.barbershops s
        where s.owner_profile_id = p.id
      )
    order by p.created_at asc
    limit 1;

    select p.id into other_barber_profile
    from public.profiles p
    where p.role <> 'admin'
      and p.id <> owner_profile
      and p.id <> barber_profile
      and p.id <> customer_profile
      and not exists (
        select 1
        from public.barbershops s
        where s.owner_profile_id = p.id
      )
    order by p.created_at asc
    limit 1;

    other_barber_profile := coalesce(other_barber_profile, customer_profile);
    booking_profile := case when other_barber_profile = customer_profile then owner_profile else customer_profile end;

    if owner_profile is null or barber_profile is null or customer_profile is null then
      raise exception 'Need 3 usable non-admin profiles (shop owner + barber + customer). Create users then re-run.';
    end if;

    select id into v_shop_id from public.barbershops where owner_profile_id = owner_profile order by created_at asc limit 1;
    if v_shop_id is null then
      insert into public.barbershops (owner_profile_id, name, status, is_active)
      values (owner_profile, 'Booking Smoke Shop', 'approved', true)
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
      values (barber_profile, v_shop_id, public.ensure_shop_default_branch(v_shop_id), 'Booking Smoke Barber', false, 'approved', true)
      returning id into v_barber_id;
    else
      execute 'update public.barbers set shop_id = $1, branch_id = public.ensure_shop_default_branch($1), is_independent = false, status = ''approved'', is_active = true, deleted_at = null where id = $2'
      using v_shop_id, v_barber_id;
    end if;

    select id into v_other_barber_id from public.barbers where profile_id = other_barber_profile order by created_at asc limit 1;
    if v_other_barber_id is null then
      insert into public.barbers (profile_id, shop_id, branch_id, display_name, is_independent, status, is_active)
      values (other_barber_profile, v_shop_id, public.ensure_shop_default_branch(v_shop_id), 'Booking Smoke Other Barber', false, 'approved', true)
      returning id into v_other_barber_id;
    else
      execute 'update public.barbers set shop_id = $1, branch_id = public.ensure_shop_default_branch($1), is_independent = false, status = ''approved'', is_active = true, deleted_at = null where id = $2'
      using v_shop_id, v_other_barber_id;
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
      'Booking Smoke Service',
      'Booking Smoke Service',
      5,
      30,
      true,
      'approved',
      case when v_has_service_barbers then 'shop' else 'barber' end,
      case when v_has_service_barbers then v_shop_id else v_barber_id end,
      'Booking Smoke Service',
      5,
      30,
      true
    )
    returning id into v_service_id;

    update public.services
    set deleted_at = null,
        is_active = true,
        status = 'approved',
        deposit_type = 'fixed',
        deposit_value = 2
    where id = v_service_id;

    if v_has_service_barbers then
      insert into public.service_barbers (service_id, barber_id)
      values (v_service_id, v_barber_id)
      on conflict do nothing;
    end if;

    perform set_config('request.jwt.claim.role', 'authenticated', true);
    execute 'set role authenticated';

    perform set_config('request.jwt.claim.sub', booking_profile::text, true);

    v_start_at := date_trunc('hour', now()) + interval '10 days';

    begin
      perform public.hold_booking_slot(v_service_id, v_start_at - interval '1 day', v_other_barber_id, v_shop_id, 5);
      raise exception 'Expected SERVICE_NOT_FOR_BARBER for unmapped barber';
    exception when others then
      if position('service_not_for_barber' in lower(sqlerrm)) = 0 then
        raise;
      end if;
    end;

    select t.hold_id, t.expires_at into v_hold_id, hold_expires
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
      'smoke_test'::text,
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

    perform set_config('request.jwt.claim.sub', owner_profile::text, true);
    select count(*) into c from public.bookings where id = v_booking_id;
    if c <> 1 then
      raise exception 'provider should be able to read booking';
    end if;

    select count(*) into c
    from public.notifications n
    where n.profile_id in (owner_profile, barber_profile)
      and n.type = 'booking_created'
      and n.data->>'booking_id' = v_booking_id::text; 

    if c < 1 then
      raise exception 'missing provider notification booking_created';
    end if;

    select b.status into v_status from public.bookings b where b.id = v_booking_id;
    if v_status <> 'confirmed' then
      raise exception 'booking was not auto-confirmed';
    end if;

    select b.deposit_required_amount, b.payment_status
    into v_deposit_required, v_payment_status
    from public.bookings b
    where b.id = v_booking_id;

    if coalesce(v_deposit_required, 0) <> 2 then
      raise exception 'deposit amount was not applied to booking';
    end if;

    if coalesce(v_payment_status, '') <> 'pending' then
      raise exception 'booking payment_status should start as pending when deposit is required';
    end if;

    select p.id into v_payment_id
    from public.payments p
    where p.booking_id = v_booking_id
      and p.purpose = 'deposit'
    order by p.created_at desc
    limit 1;

    if v_payment_id is null then
      raise exception 'deposit payment row missing';
    end if;

    perform public.mark_payment_succeeded(v_payment_id);

    select b.payment_status into v_payment_status
    from public.bookings b
    where b.id = v_booking_id;

    if v_payment_status <> 'paid' then
      raise exception 'booking payment_status was not synced to paid';
    end if;

    v_rescheduled_start_at := v_start_at + interval '2 hours';
    perform public.reschedule_booking(v_booking_id, v_rescheduled_start_at);

    select b.start_at, b.rescheduled_at into v_start_at, hold_expires
    from public.bookings b
    where b.id = v_booking_id;

    if v_start_at <> v_rescheduled_start_at or hold_expires is null then
      raise exception 'booking was not rescheduled correctly';
    end if;

    perform public.start_booking(v_booking_id);
    select b.status into v_status from public.bookings b where b.id = v_booking_id;
    if v_status <> 'in_progress' then
      raise exception 'start_booking did not start';
    end if;

    perform public.complete_booking(v_booking_id);
    select b.status into v_status from public.bookings b where b.id = v_booking_id;
    if v_status <> 'completed' then
      raise exception 'booking not completed';
    end if;

    execute 'reset role';
    insert into public.refunds (payment_id, amount, currency, provider, provider_reference, status, reason)
    values (v_payment_id, 2, 'BHD', 'manual', concat('booking_smoke_refund_', v_payment_id::text), 'succeeded', 'smoke test');
    perform set_config('request.jwt.claim.role', 'authenticated', true);
    execute 'set role authenticated';
    perform set_config('request.jwt.claim.sub', owner_profile::text, true);

    select b.payment_status into v_payment_status
    from public.bookings b
    where b.id = v_booking_id;

    if v_payment_status <> 'refunded' then
      raise exception 'booking payment_status was not synced to refunded';
    end if;

    perform set_config('request.jwt.claim.sub', booking_profile::text, true);

    select t.hold_id into v_hold_id
    from public.hold_booking_slot(v_service_id, v_rescheduled_start_at + interval '1 day', v_barber_id, v_shop_id, 5) as t;

    select b.id into v_no_show_booking_id
    from public.create_booking_with_hold(
      v_service_id,
      v_rescheduled_start_at + interval '1 day',
      v_barber_id,
      v_hold_id,
      v_shop_id,
      null::text,
      'cash'::text,
      null::uuid,
      'smoke_no_show'::text,
      null::uuid,
      null::uuid,
      0::numeric
    ) as b;

    perform set_config('request.jwt.claim.sub', owner_profile::text, true);
    perform public.mark_booking_no_show(v_no_show_booking_id);
    select b.status into v_status from public.bookings b where b.id = v_no_show_booking_id;
    if v_status <> 'no_show' then
      raise exception 'mark_booking_no_show did not set no_show';
    end if;

    perform set_config('request.jwt.claim.sub', booking_profile::text, true);

    select t.hold_id into v_hold_id
    from public.hold_booking_slot(v_service_id, v_rescheduled_start_at + interval '2 days', v_barber_id, v_shop_id, 5) as t;

    select b.id into v_cancel_booking_id
    from public.create_booking_with_hold(
      v_service_id,
      v_rescheduled_start_at + interval '2 days',
      v_barber_id,
      v_hold_id,
      v_shop_id,
      null::text,
      'cash'::text,
      null::uuid,
      'smoke_cancel'::text,
      null::uuid,
      null::uuid,
      0::numeric
    ) as b;

    perform public.cancel_booking(v_cancel_booking_id, 'smoke cancel');
    select b.status, b.cancelled_at into v_status, hold_expires from public.bookings b where b.id = v_cancel_booking_id;
    if v_status <> 'cancelled' or hold_expires is null then
      raise exception 'cancel_booking did not set cancelled state';
    end if;

    begin
      update public.bookings set status = 'pending' where id = v_booking_id;
      raise exception 'invalid transition should fail';
    exception when others then
      null;
    end;

    begin
      insert into public.notifications (profile_id, type, title, body, data)
      values (owner_profile, 'spoof', 'x', 'y', '{}'::jsonb);
      raise exception 'notifications spoof insert should fail';
    exception when others then
      null;
    end;

    execute 'reset role';
  exception when others then
    execute 'reset role';
    raise;
  end;

  raise notice 'Booking smoke test passed (rolled back).';
end
$$;

rollback;

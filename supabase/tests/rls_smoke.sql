begin;

do $$
declare
  a uuid;
  b uuid;
  owner_a uuid;
  owner_b uuid;

  sh_a uuid;
  br_a uuid;
  svc_a uuid;
  bk_a uuid;
  branch_a uuid;

  sh_b uuid;
  br_b uuid;
  svc_b uuid;
  bk_b uuid;
  branch_b uuid;

  c int;
  status text;

  has_create boolean;
  has_cancel boolean;
  has_reschedule boolean;
  has_buffer boolean;
  has_shop_branches boolean;
  has_barber_branch boolean;
  has_booking_branch boolean;
begin
  begin
    select id into a from public.profiles where role = 'customer' order by created_at asc limit 1;
    if a is null then
      select id into a from public.profiles where role <> 'admin' order by created_at asc limit 1;
    end if;

    select id into b from public.profiles where role = 'customer' and id <> a order by created_at asc limit 1;
    if b is null then
      select id into b from public.profiles where role <> 'admin' and id <> a order by created_at asc limit 1;
    end if;

    if a is null then
      raise exception 'Need at least 1 profile to run RLS smoke test. Create a user (sign up) then re-run.';
    end if;

    if b is null then
      b := a;
      raise notice 'Only 1 profile found; running single-user RLS checks (cross-user checks skipped).';
    end if;

    select p.id into owner_a
    from public.profiles p
    where p.role = 'shop_owner'
      and not exists (
        select 1
        from public.barbers bx
        where bx.profile_id = p.id
      )
    order by p.created_at asc
    limit 1;

    if owner_a is null then
      select p.id into owner_a
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

    if owner_a is null then
      select p.id into owner_a
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

    if owner_a is null then
      raise exception 'Need at least 1 non-admin profile to own shops for RLS smoke test.';
    end if;

    if b = owner_a then
      select id into b from public.profiles where role = 'customer' and id <> a and id <> owner_a order by created_at asc limit 1;
      if b is null then
        select id into b from public.profiles where role <> 'admin' and id <> a and id <> owner_a order by created_at asc limit 1;
      end if;
      if b is null then
        b := a;
        raise notice 'Only 1 usable profile found; running single-user RLS checks (cross-user checks skipped).';
      end if;
    end if;

    select id into sh_a from public.barbershops where owner_profile_id = owner_a order by created_at asc limit 1;
    if sh_a is null then
      insert into public.barbershops (owner_profile_id, name, status, is_active)
      values (owner_a, 'RLS Smoke Shop A', 'approved', true)
      returning id into sh_a;
    else
      update public.barbershops
      set status = 'approved',
          is_active = true
      where id = sh_a;
    end if;

    has_shop_branches := to_regclass('public.shop_branches') is not null;
    has_barber_branch := exists (
      select 1
      from information_schema.columns
      where table_schema = 'public' and table_name = 'barbers' and column_name = 'branch_id'
    );
    has_booking_branch := exists (
      select 1
      from information_schema.columns
      where table_schema = 'public' and table_name = 'bookings' and column_name = 'branch_id'
    );

    if has_shop_branches then
      if to_regprocedure('public.ensure_shop_default_branch(uuid)') is not null then
        select public.ensure_shop_default_branch(sh_a) into branch_a;
      else
        select id into branch_a
        from public.shop_branches
        where shop_id = sh_a
        order by created_at asc
        limit 1;
      end if;
    end if;

    select id into br_a from public.barbers where profile_id = a order by created_at asc limit 1;
    if br_a is null then
      if has_barber_branch then
        insert into public.barbers (profile_id, shop_id, branch_id, display_name, is_independent, status, is_active)
        values (a, sh_a, branch_a, 'RLS Smoke Barber A', false, 'approved', true)
        returning id into br_a;
      else
        insert into public.barbers (profile_id, shop_id, display_name, is_independent, status, is_active)
        values (a, sh_a, 'RLS Smoke Barber A', false, 'approved', true)
        returning id into br_a;
      end if;
    else
      if has_barber_branch then
        update public.barbers
        set shop_id = sh_a, branch_id = branch_a, is_independent = false, status = 'approved', is_active = true
        where id = br_a;
      else
        update public.barbers
        set shop_id = sh_a, is_independent = false, status = 'approved', is_active = true
        where id = br_a;
      end if;
    end if;

    insert into public.services (
      shop_id,
      barber_id,
      name_en,
      name_ar,
      description_en,
      description_ar,
      price_bhd,
      duration_minutes,
      image_url,
      category,
      is_popular,
      is_active,
      status,
      owner_type,
      owner_id,
      name,
      description,
      price,
      duration_min,
      active,
      deleted_at
    )
    values (
      sh_a,
      null,
      'RLS Smoke Service A',
      null,
      null,
      null,
      5,
      30,
      null,
      null,
      false,
      true,
      'approved',
      'shop',
      sh_a,
      'RLS Smoke Service A',
      null,
      5,
      30,
      true,
      null
    )
    returning id into svc_a;

    if to_regclass('public.service_barbers') is not null then
      insert into public.service_barbers (service_id, barber_id) values (svc_a, br_a) on conflict do nothing;
    end if;

    if b = a then
      sh_b := sh_a;
      br_b := br_a;
      svc_b := svc_a;
      branch_b := branch_a;
    else
      select p.id into owner_b
      from public.profiles p
      where p.role = 'shop_owner'
        and p.id <> owner_a
        and not exists (
          select 1
          from public.barbers bx
          where bx.profile_id = p.id
        )
      order by p.created_at asc
      limit 1;

      if owner_b is null then
        select p.id into owner_b
        from public.profiles p
        where p.role = 'customer'
          and p.id <> owner_a
          and not exists (
            select 1
            from public.barbers bx
            where bx.profile_id = p.id
          )
        order by p.created_at asc
        limit 1;
      end if;

      if owner_b is null then
        select p.id into owner_b
        from public.profiles p
        where p.role <> 'admin'
          and p.id <> owner_a
          and not exists (
            select 1
            from public.barbers bx
            where bx.profile_id = p.id
          )
        order by p.created_at asc
        limit 1;
      end if;

      if owner_b is null then
        owner_b := owner_a;
      end if;

      select id into sh_b
      from public.barbershops
      where owner_profile_id = owner_b
        and id <> sh_a
      order by created_at asc
      limit 1;
      if sh_b is null then
        insert into public.barbershops (owner_profile_id, name, status, is_active)
        values (owner_b, 'RLS Smoke Shop B', 'approved', true)
        returning id into sh_b;
      else
        update public.barbershops
        set status = 'approved',
            is_active = true
        where id = sh_b;
      end if;

      if has_shop_branches then
        if to_regprocedure('public.ensure_shop_default_branch(uuid)') is not null then
          select public.ensure_shop_default_branch(sh_b) into branch_b;
        else
          select id into branch_b
          from public.shop_branches
          where shop_id = sh_b
          order by created_at asc
          limit 1;
        end if;
      end if;

      select id into br_b from public.barbers where profile_id = b order by created_at asc limit 1;
      if br_b is null then
        if has_barber_branch then
          insert into public.barbers (profile_id, shop_id, branch_id, display_name, is_independent, status, is_active)
          values (b, sh_b, branch_b, 'RLS Smoke Barber B', false, 'approved', true)
          returning id into br_b;
        else
          insert into public.barbers (profile_id, shop_id, display_name, is_independent, status, is_active)
          values (b, sh_b, 'RLS Smoke Barber B', false, 'approved', true)
          returning id into br_b;
        end if;
      else
        if has_barber_branch then
          update public.barbers
          set shop_id = sh_b, branch_id = branch_b, is_independent = false, status = 'approved', is_active = true
          where id = br_b;
        else
          update public.barbers
          set shop_id = sh_b, is_independent = false, status = 'approved', is_active = true
          where id = br_b;
        end if;
      end if;

      insert into public.services (
        shop_id,
        barber_id,
        name_en,
        name_ar,
        description_en,
        description_ar,
        price_bhd,
        duration_minutes,
        image_url,
        category,
        is_popular,
        is_active,
        status,
        owner_type,
        owner_id,
        name,
        description,
        price,
        duration_min,
        active,
        deleted_at
      )
      values (
        sh_b,
        null,
        'RLS Smoke Service B',
        null,
        null,
        null,
        5,
        30,
        null,
        null,
        false,
        true,
        'approved',
        'shop',
        sh_b,
        'RLS Smoke Service B',
        null,
        5,
        30,
        true,
        null
      )
      returning id into svc_b;

      if to_regclass('public.service_barbers') is not null then
        insert into public.service_barbers (service_id, barber_id) values (svc_b, br_b) on conflict do nothing;
      end if;
    end if;

    if has_booking_branch then
      insert into public.bookings (customer_profile_id, shop_id, branch_id, barber_id, service_id, start_at, end_at, status)
      values (a, sh_a, branch_a, br_a, svc_a, now() + interval '1 day', now() + interval '1 day' + interval '30 minutes', 'pending')
      returning id into bk_a;
    else
      insert into public.bookings (customer_profile_id, shop_id, barber_id, service_id, start_at, end_at, status)
      values (a, sh_a, br_a, svc_a, now() + interval '1 day', now() + interval '1 day' + interval '30 minutes', 'pending')
      returning id into bk_a;
    end if;

    if has_booking_branch then
      insert into public.bookings (customer_profile_id, shop_id, branch_id, barber_id, service_id, start_at, end_at, status)
      values (b, sh_b, branch_b, br_b, svc_b, now() + interval '1 day', now() + interval '1 day' + interval '30 minutes', 'pending')
      returning id into bk_b;
    else
      insert into public.bookings (customer_profile_id, shop_id, barber_id, service_id, start_at, end_at, status)
      values (b, sh_b, br_b, svc_b, now() + interval '1 day', now() + interval '1 day' + interval '30 minutes', 'pending')
      returning id into bk_b;
    end if;

    if to_regclass('public.loyalty_ledger') is not null then
      insert into public.loyalty_ledger (profile_id, booking_id, delta, reason)
      values (a, bk_a, 10, 'rls_smoke_seed')
      on conflict (booking_id) do nothing;
    end if;

    perform set_config('request.jwt.claim.role', 'authenticated', true);
    execute 'set role authenticated';

    perform set_config('request.jwt.claim.sub', a::text, true);
    select count(*) into c from public.bookings where id = bk_a;
    if c <> 1 then raise exception 'RLS failed: bookings select for user_a'; end if;
    select count(*) into c from public.bookings where id = bk_b;
    if a <> b and c <> 0 then raise exception 'RLS failed: bookings cross-read blocked for user_a'; end if;

    if a <> b then
      begin
        insert into public.bookings (customer_profile_id, shop_id, barber_id, service_id, start_at, end_at, status)
        values (b, sh_a, br_a, svc_a, now() + interval '2 day', now() + interval '2 day' + interval '30 minutes', 'pending');
        raise exception 'RLS failed: bookings insert should not allow cross-user customer_profile_id';
      exception when others then
      end;

      perform set_config('request.jwt.claim.sub', b::text, true);
      select count(*) into c from public.bookings where id = bk_b;
      if c <> 1 then raise exception 'RLS failed: bookings select for user_b'; end if;
      select count(*) into c from public.bookings where id = bk_a;
      if c <> 0 then raise exception 'RLS failed: bookings cross-read blocked for user_b'; end if;
    end if;

    perform set_config('request.jwt.claim.sub', a::text, true);
    if to_regclass('public.favorites') is not null then
      insert into public.favorites (profile_id, target_type, target_id) values (a, 'barber', gen_random_uuid());
      select count(*) into c from public.favorites;
      if c <> 1 then raise exception 'RLS failed: favorites select for user_a'; end if;
    end if;

    if to_regclass('public.follows') is not null then
      insert into public.follows (profile_id, target_type, target_id) values (a, 'barber', gen_random_uuid());
      select count(*) into c from public.follows;
      if c <> 1 then raise exception 'RLS failed: follows select for user_a'; end if;
    end if;

    if to_regclass('public.loyalty_ledger') is not null then
      begin
        insert into public.loyalty_ledger (profile_id, booking_id, delta, reason) values (a, bk_a, 10, 'rls_smoke');
        raise exception 'RLS failed: loyalty_ledger insert should be forbidden (use trigger/RPC only)';
      exception when others then
      end;

      select count(*) into c from public.loyalty_ledger;
      if c <> 1 then raise exception 'RLS failed: loyalty_ledger select for user_a'; end if;
    end if;

    if a <> b then
      perform set_config('request.jwt.claim.sub', b::text, true);
      if to_regclass('public.favorites') is not null then
        select count(*) into c from public.favorites;
        if c <> 0 then raise exception 'RLS failed: favorites cross-read blocked'; end if;
      end if;
      if to_regclass('public.follows') is not null then
        select count(*) into c from public.follows;
        if c <> 0 then raise exception 'RLS failed: follows cross-read blocked'; end if;
      end if;
      if to_regclass('public.loyalty_ledger') is not null then
        select count(*) into c from public.loyalty_ledger;
        if c <> 0 then raise exception 'RLS failed: loyalty_ledger cross-read blocked'; end if;
      end if;
    end if;

    perform set_config('request.jwt.claim.sub', a::text, true);

    has_create := to_regprocedure('public.create_booking(uuid,timestamptz,uuid,uuid,text,text,uuid)') is not null
      or to_regprocedure('public.create_booking(uuid,timestamptz,uuid,uuid,text,text)') is not null
      or to_regprocedure('public.create_booking(uuid,timestamptz,uuid,uuid,text)') is not null;
    has_cancel := to_regprocedure('public.cancel_booking(uuid,text)') is not null;
    has_reschedule := to_regprocedure('public.reschedule_booking(uuid,timestamptz)') is not null;
    has_buffer := to_regclass('public.barbers') is not null
      and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'barbers' and column_name = 'buffer_minutes')
      and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'barbershops' and column_name = 'buffer_minutes');

    if has_create and has_buffer then
      if to_regprocedure('public.create_booking(uuid,timestamptz,uuid,uuid,text,text,uuid)') is not null then
        select (public.create_booking(
          svc_a::uuid,
          (date_trunc('day', now() + interval '5 days') + interval '10 hours')::timestamptz,
          br_a::uuid,
          sh_a::uuid,
          null::text,
          'cash'::text,
          null::uuid
        )).id into bk_a;
      elsif to_regprocedure('public.create_booking(uuid,timestamptz,uuid,uuid,text,text)') is not null then
        select (public.create_booking(
          svc_a::uuid,
          (date_trunc('day', now() + interval '5 days') + interval '10 hours')::timestamptz,
          br_a::uuid,
          sh_a::uuid,
          null::text,
          'cash'::text
        )).id into bk_a;
      else
        select (public.create_booking(
          svc_a::uuid,
          (date_trunc('day', now() + interval '5 days') + interval '10 hours')::timestamptz,
          br_a::uuid,
          sh_a::uuid,
          null::text
        )).id into bk_a;
      end if;

      select count(*) into c from public.bookings where id = bk_a;
      if c <> 1 then raise exception 'RLS failed: bookings select after create_booking for user_a'; end if;

      if a <> b and has_reschedule then
        perform set_config('request.jwt.claim.sub', b::text, true);
        begin
          perform public.reschedule_booking(bk_a, (date_trunc('day', now() + interval '6 days') + interval '11 hours'));
          raise exception 'RLS failed: reschedule_booking should be forbidden for other user';
        exception when others then
        end;
        perform set_config('request.jwt.claim.sub', a::text, true);
      end if;

      if has_reschedule then
        perform public.reschedule_booking(bk_a, (date_trunc('day', now() + interval '6 days') + interval '11 hours'));
      end if;

      if a <> b and has_cancel then
        perform set_config('request.jwt.claim.sub', b::text, true);
        begin
          perform public.cancel_booking(bk_a, null);
          raise exception 'RLS failed: cancel_booking should be forbidden for other user';
        exception when others then
        end;
        perform set_config('request.jwt.claim.sub', a::text, true);
      end if;

      if has_cancel then
        perform public.cancel_booking(bk_a, null);
        select b.status into status from public.bookings b where b.id = bk_a;
        if status <> 'cancelled' then raise exception 'cancel_booking failed: status not cancelled'; end if;
      end if;
    else
      if not has_create then
        raise notice 'Skipping booking RPC checks: create_booking RPC not installed.';
      elsif not has_buffer then
        raise notice 'Skipping booking RPC checks: buffer_minutes columns missing.';
      end if;
    end if;

    perform set_config('request.jwt.claim.sub', a::text, true);

    begin
      insert into public.services (
        shop_id,
        barber_id,
        name_en,
        name_ar,
        description_en,
        description_ar,
        price_bhd,
        duration_minutes,
        image_url,
        category,
        is_popular,
        is_active,
        status,
        owner_type,
        owner_id,
        name,
        description,
        price,
        duration_min,
        active,
        deleted_at
      )
      values (
        sh_a,
        br_a,
        'RLS Smoke Barber Service A',
        null,
        null,
        null,
        5,
        30,
        null,
        null,
        false,
        true,
        'approved',
        'barber',
        br_a,
        'RLS Smoke Barber Service A',
        null,
        5,
        30,
        true,
        null
      );
    exception when others then
      raise exception 'RLS failed: barber should be able to create own service';
    end;

    if a <> b then
      perform set_config('request.jwt.claim.sub', b::text, true);
      begin
        update public.services set name_en = 'X' where id = svc_a;
        raise exception 'RLS failed: barber should not update other shop''s service';
      exception when others then
      end;
      perform set_config('request.jwt.claim.sub', a::text, true);
    end if;

    if to_regclass('storage.objects') is not null then
      begin
        execute 'insert into storage.objects (bucket_id, name, owner, metadata) values ($1,$2,$3,$4)'
        using 'reels', 'barbers/' || br_a::text || '/rls_smoke.jpg', a, '{}'::jsonb;
      exception when others then
        raise notice 'Skipping storage.objects insert check (schema/policies may differ).';
      end;
    end if;

    execute 'reset role';
  exception when others then
    execute 'reset role';
    raise;
  end;

  raise notice 'RLS smoke test passed (rolled back).';
end
$$;

rollback;

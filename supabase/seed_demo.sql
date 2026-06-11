begin;

delete from auth.users where email like '%@hallaq.demo';

create or replace function public.prevent_profile_role_change()
returns trigger
language plpgsql
as $$
declare
  jwt_role text := current_setting('request.jwt.claim.role', true);
begin
  if new.role is distinct from old.role then
    if jwt_role = 'service_role' then
      return new;
    end if;
    if not public.is_admin() then
      raise exception 'role_change_not_allowed';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.enforce_shop_owner_barber_assignment()
returns trigger
language plpgsql
as $$
declare
  jwt_role text := current_setting('request.jwt.claim.role', true);
begin
  if jwt_role = 'service_role' then
    return new;
  end if;

  if public.is_admin() then
    return new;
  end if;

  if old.profile_id = auth.uid() then
    return new;
  end if;

  if not public.is_shop_owner(coalesce(new.shop_id, old.shop_id)) then
    raise exception 'Not allowed';
  end if;

  if new.profile_id is distinct from old.profile_id then raise exception 'Not allowed'; end if;
  if new.slug is distinct from old.slug then raise exception 'Not allowed'; end if;
  if new.display_name is distinct from old.display_name then raise exception 'Not allowed'; end if;
  if new.avatar_url is distinct from old.avatar_url then raise exception 'Not allowed'; end if;
  if new.cover_url is distinct from old.cover_url then raise exception 'Not allowed'; end if;
  if new.bio is distinct from old.bio then raise exception 'Not allowed'; end if;
  if new.specialty is distinct from old.specialty then raise exception 'Not allowed'; end if;
  if new.area is distinct from old.area then raise exception 'Not allowed'; end if;
  if new.address is distinct from old.address then raise exception 'Not allowed'; end if;
  if new.lat is distinct from old.lat then raise exception 'Not allowed'; end if;
  if new.lng is distinct from old.lng then raise exception 'Not allowed'; end if;
  if new.is_verified is distinct from old.is_verified then raise exception 'Not allowed'; end if;
  if new.is_hallaq_certified is distinct from old.is_hallaq_certified then raise exception 'Not allowed'; end if;
  if new.rating_avg is distinct from old.rating_avg then raise exception 'Not allowed'; end if;
  if new.rating_count is distinct from old.rating_count then raise exception 'Not allowed'; end if;
  if new.followers_count is distinct from old.followers_count then raise exception 'Not allowed'; end if;
  if new.reviews_count is distinct from old.reviews_count then raise exception 'Not allowed'; end if;
  if new.available_now is distinct from old.available_now then raise exception 'Not allowed'; end if;
  if new.waiting_time_min is distinct from old.waiting_time_min then raise exception 'Not allowed'; end if;
  if new.queue_length is distinct from old.queue_length then raise exception 'Not allowed'; end if;
  if new.badge_verified is distinct from old.badge_verified then raise exception 'Not allowed'; end if;
  if new.badge_elite is distinct from old.badge_elite then raise exception 'Not allowed'; end if;
  if new.badge_trending is distinct from old.badge_trending then raise exception 'Not allowed'; end if;
  if new.badge_top_rated is distinct from old.badge_top_rated then raise exception 'Not allowed'; end if;
  if new.badge_certified is distinct from old.badge_certified then raise exception 'Not allowed'; end if;
  if new.deleted_at is distinct from old.deleted_at then raise exception 'Not allowed'; end if;

  return new;
end;
$$;

create or replace function public.recompute_target_rating(p_target_type text, p_target_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_avg numeric(3,2);
  v_count int;
begin
  select coalesce(avg(r.rating),0)::numeric(3,2), count(*)::int
  into v_avg, v_count
  from public.reviews r
  where r.target_type = p_target_type
    and r.target_id = p_target_id
    and r.status = 'published'
    and r.is_verified = true;

  if p_target_type = 'barber' then
    update public.barbers
    set rating_avg = v_avg,
        rating_count = v_count,
        reviews_count = v_count
    where id = p_target_id;
  elsif p_target_type = 'shop' then
    update public.barbershops
    set rating_avg = v_avg,
        rating_count = v_count,
        reviews_count = v_count
    where id = p_target_id;
  end if;
end;
$$;

do $$
declare
  areas text[] := array['Manama','Seef','Juffair','Riffa','Muharraq','Saar','Budaiya','Isa Town','Hamad Town'];
  shop_owner_ids uuid[] := array[]::uuid[];
  shop_ids uuid[] := array[]::uuid[];
  barber_profile_ids uuid[] := array[]::uuid[];
  barber_ids uuid[] := array[]::uuid[];
  customer_ids uuid[] := array[]::uuid[];
  admin_id uuid;
  v_id uuid;
  v_shop_id uuid;
  branch_id uuid;
  barber_id uuid;
  customer_id uuid;
  svc_id uuid;
  shop_for_service uuid;
  start_ts timestamptz;
  end_ts timestamptz;
  day_offset int;
  hour_offset int;
  dur_min int;
  i int;
  a text;
  status_pick text;
  lat_val double precision;
  lng_val double precision;
begin
  perform set_config('request.jwt.claim.role', 'service_role', true);

  admin_id := gen_random_uuid();
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data, created_at, updated_at)
  values (
    admin_id,
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'admin@hallaq.demo',
    crypt('Passw0rd!', gen_salt('bf')),
    now(),
    jsonb_build_object('full_name','Hallaq Admin'),
    now(),
    now()
  );
  insert into auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
  values (
    gen_random_uuid(),
    admin_id,
    jsonb_build_object('sub', admin_id::text, 'email','admin@hallaq.demo'),
    'email',
    'admin@hallaq.demo',
    now(),
    now(),
    now()
  );

  update public.profiles p
  set role = 'admin', status = 'active'
  where p.id = admin_id;

  for i in 1..10 loop
    v_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data, created_at, updated_at)
    values (
      v_id,
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      format('shop%02s@hallaq.demo', i),
      crypt('Passw0rd!', gen_salt('bf')),
      now(),
      jsonb_build_object('full_name', format('Shop Owner %s', i)),
      now(),
      now()
    );
    insert into auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
    values (
      gen_random_uuid(),
      v_id,
      jsonb_build_object('sub', v_id::text, 'email', format('shop%02s@hallaq.demo', i)),
      'email',
      format('shop%02s@hallaq.demo', i),
      now(),
      now(),
      now()
    );
    update public.profiles p
    set role = 'shop_owner', status = 'active'
    where p.id = v_id;
    shop_owner_ids := array_append(shop_owner_ids, v_id);
  end loop;

  for i in 1..40 loop
    v_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data, created_at, updated_at)
    values (
      v_id,
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      format('barber%02s@hallaq.demo', i),
      crypt('Passw0rd!', gen_salt('bf')),
      now(),
      jsonb_build_object('full_name', format('Barber %s', i)),
      now(),
      now()
    );
    insert into auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
    values (
      gen_random_uuid(),
      v_id,
      jsonb_build_object('sub', v_id::text, 'email', format('barber%02s@hallaq.demo', i)),
      'email',
      format('barber%02s@hallaq.demo', i),
      now(),
      now(),
      now()
    );
    update public.profiles p
    set role = 'barber', status = 'active'
    where p.id = v_id;
    barber_profile_ids := array_append(barber_profile_ids, v_id);
  end loop;

  for i in 1..30 loop
    v_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data, created_at, updated_at)
    values (
      v_id,
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      format('customer%02s@hallaq.demo', i),
      crypt('Passw0rd!', gen_salt('bf')),
      now(),
      jsonb_build_object('full_name', format('Customer %s', i)),
      now(),
      now()
    );
    insert into auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
    values (
      gen_random_uuid(),
      v_id,
      jsonb_build_object('sub', v_id::text, 'email', format('customer%02s@hallaq.demo', i)),
      'email',
      format('customer%02s@hallaq.demo', i),
      now(),
      now(),
      now()
    );
    update public.profiles p
    set role = 'customer', status = 'active'
    where p.id = v_id;
    customer_ids := array_append(customer_ids, v_id);
  end loop;

  for i in 1..10 loop
    a := areas[((random() * (array_length(areas, 1) - 1))::int + 1)];
    v_id := shop_owner_ids[i];
    lat_val := 26.05 + (random() * 0.25);
    lng_val := 50.40 + (random() * 0.35);
    insert into public.barbershops (
      owner_profile_id,
      name,
      description,
      area,
      address,
      lat,
      lng,
      google_maps_url,
      logo_url,
      cover_url,
      phone,
      whatsapp,
      instagram,
      opening_hours,
      status,
      is_verified,
      is_featured
    )
    values (
      v_id,
      format('Hallaq Shop %s', i),
      'Premium grooming and modern cuts.',
      a,
      format('%s, Bahrain', a),
      lat_val,
      lng_val,
      format('https://www.google.com/maps?q=%s,%s', lat_val, lng_val),
      format('https://picsum.photos/seed/hallaq_shop_logo_%s/512/512', i),
      format('https://picsum.photos/seed/hallaq_shop_cover_%s/1400/800', i),
      '+973 3000 0000',
      '+973 3000 0000',
      format('@hallaq_shop_%s', i),
      jsonb_build_object('daily', '10:00-22:00'),
      'approved',
      true,
      i <= 3
    )
    returning public.barbershops.id into v_shop_id;
    shop_ids := array_append(shop_ids, v_shop_id);

    if to_regclass('public.shop_branches') is not null then
      insert into public.shop_branches (shop_id, name, area, address, lat, lng, opening_hours)
      values (v_shop_id, 'Main Branch', a, format('%s, Bahrain', a), lat_val, lng_val, jsonb_build_object('daily', '10:00-22:00'))
      on conflict (shop_id, name) do nothing;
    end if;
  end loop;

  for i in 1..40 loop
    v_shop_id := shop_ids[((i - 1) / 4) + 1];
    v_id := barber_profile_ids[i];
    a := areas[((random() * (array_length(areas, 1) - 1))::int + 1)];
    branch_id := null;
    if to_regclass('public.shop_branches') is not null then
      select sb.id
      into branch_id
      from public.shop_branches sb
      where sb.shop_id = v_shop_id
      order by (sb.name = 'Main Branch') desc, sb.created_at asc
      limit 1;
    end if;
    insert into public.barbers (profile_id, shop_id, branch_id, display_name, bio, area, available_now, is_verified)
    values (
      v_id,
      v_shop_id,
      branch_id,
      format('Barber %s', i),
      'Specialist in fades, beards, and classic cuts.',
      a,
      (random() > 0.7),
      true
    )
    returning public.barbers.id into barber_id;
    barber_ids := array_append(barber_ids, barber_id);
  end loop;

  for i in 1..30 loop
    v_shop_id := shop_ids[((random() * (array_length(shop_ids, 1) - 1))::int + 1)];
    insert into public.products (shop_id, name, description, price, currency, stock, images, active)
    values (
      v_shop_id,
      format('Demo Product %s', i),
      'Demo catalog item.',
      (1 + (random() * 9))::numeric(10,3),
      'BHD',
      (10 + (random() * 50))::int,
      array[format('https://picsum.photos/seed/hallaq_product_%s/900/900', i)],
      true
    );
  end loop;

  for i in 1..80 loop
    v_shop_id := shop_ids[((random() * (array_length(shop_ids, 1) - 1))::int + 1)];
    insert into public.services (shop_id, name_en, name, description_en, description, duration_minutes, duration_min, price_bhd, price, is_active, active, category, owner_type, owner_id)
    values (
      v_shop_id,
      case (i % 8)
        when 0 then 'Haircut'
        when 1 then 'Beard Trim'
        when 2 then 'Haircut + Beard'
        when 3 then 'Kids Cut'
        when 4 then 'Hot Towel Shave'
        when 5 then 'Hair Wash'
        when 6 then 'Facial'
        else 'Styling'
      end,
      case (i % 8)
        when 0 then 'Haircut'
        when 1 then 'Beard Trim'
        when 2 then 'Haircut + Beard'
        when 3 then 'Kids Cut'
        when 4 then 'Hot Towel Shave'
        when 5 then 'Hair Wash'
        when 6 then 'Facial'
        else 'Styling'
      end,
      'Professional service.',
      'Professional service.',
      case (i % 3)
        when 0 then 30
        when 1 then 45
        else 60
      end,
      case (i % 3)
        when 0 then 30
        when 1 then 45
        else 60
      end,
      case (i % 6)
        when 0 then 4.000
        when 1 then 5.000
        when 2 then 6.000
        when 3 then 7.000
        when 4 then 8.000
        else 10.000
      end,
      case (i % 6)
        when 0 then 4.000
        when 1 then 5.000
        when 2 then 6.000
        when 3 then 7.000
        when 4 then 8.000
        else 10.000
      end,
      true,
      true,
      'grooming',
      'shop',
      v_shop_id
    );
  end loop;

  for i in 1..100 loop
    if random() > 0.5 then
      v_shop_id := shop_ids[((random() * (array_length(shop_ids, 1) - 1))::int + 1)];
      insert into public.reels (shop_id, barber_id, media_type, media_url, caption, location, status, is_featured)
      values (
        v_shop_id,
        null,
        'image',
        format('https://picsum.photos/seed/hallaq_post_%s/900/1200', i),
        format('Fresh look %s', i),
        areas[((random() * (array_length(areas, 1) - 1))::int + 1)],
        'approved',
        i <= 10
      );
    else
      barber_id := barber_ids[((random() * (array_length(barber_ids, 1) - 1))::int + 1)];
      insert into public.reels (shop_id, barber_id, media_type, media_url, caption, location, status, is_featured)
      values (
        null,
        barber_id,
        'image',
        format('https://picsum.photos/seed/hallaq_post_%s/900/1200', i),
        format('Fade %s', i),
        areas[((random() * (array_length(areas, 1) - 1))::int + 1)],
        'approved',
        i <= 10
      );
    end if;
  end loop;

  for i in 1..100 loop
    customer_id := customer_ids[((random() * (array_length(customer_ids, 1) - 1))::int + 1)];
    select id, shop_id into svc_id, shop_for_service
    from public.services
    where shop_id is not null
    order by random()
    limit 1;

    select id into barber_id from public.barbers where shop_id = shop_for_service order by random() limit 1;
    branch_id := null;
    if to_regclass('public.shop_branches') is not null then
      select sb.id
      into branch_id
      from public.shop_branches sb
      where sb.shop_id = shop_for_service
      order by (sb.name = 'Main Branch') desc, sb.created_at asc
      limit 1;
    end if;

    status_pick := case
      when random() < 0.35 then 'pending'
      when random() < 0.75 then 'confirmed'
      when random() < 0.90 then 'completed'
      else 'cancelled'
    end;

    day_offset := (random() * 14)::int;
    hour_offset := 10 + (random() * 10)::int;
    dur_min := case
      when random() < 0.5 then 30
      when random() < 0.8 then 45
      else 60
    end;

    start_ts := now() + make_interval(days => day_offset, hours => hour_offset);
    end_ts := start_ts + make_interval(mins => dur_min);

    insert into public.bookings (customer_profile_id, shop_id, branch_id, barber_id, service_id, start_at, end_at, status, notes)
    values (
      customer_id,
      shop_for_service,
      branch_id,
      barber_id,
      svc_id,
      start_ts,
      end_ts,
      status_pick,
      null
    );
  end loop;

  for i in 1..200 loop
    customer_id := customer_ids[((random() * (array_length(customer_ids, 1) - 1))::int + 1)];
    if random() > 0.5 then
      barber_id := barber_ids[((random() * (array_length(barber_ids, 1) - 1))::int + 1)];
      insert into public.reviews (customer_profile_id, target_type, target_id, rating, text, status)
      values (
        customer_id,
        'barber',
        barber_id,
        ((random() * 4)::int + 1),
        'Great service.',
        'published'
      );
    else
      v_shop_id := shop_ids[((random() * (array_length(shop_ids, 1) - 1))::int + 1)];
      insert into public.reviews (customer_profile_id, target_type, target_id, rating, text, status)
      values (
        customer_id,
        'shop',
        v_shop_id,
        ((random() * 4)::int + 1),
        'Clean and professional.',
        'published'
      );
    end if;
  end loop;
end;
$$;

commit;

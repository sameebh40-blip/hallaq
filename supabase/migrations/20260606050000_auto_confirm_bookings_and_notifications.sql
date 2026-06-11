begin;

create or replace function public.create_booking(
  service_id uuid,
  start_at timestamptz,
  barber_id uuid,
  shop_id uuid default null,
  notes text default null
)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_barber_shop_id uuid;
  v_service record;
  v_shop_id uuid;
  v_branch_id uuid;
  v_duration int;
  v_price numeric(10,3);
  v_end_at timestamptz;
  v_buffer int := 0;
  v_booking public.bookings%rowtype;
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  if barber_id is null then
    raise exception using message = 'INVALID_BARBER';
  end if;

  select b.shop_id
  into v_barber_shop_id
  from public.barbers b
  where b.id = $3;

  if v_barber_shop_id is null and shop_id is not null then
    raise exception using message = 'INVALID_SHOP';
  end if;

  v_shop_id := coalesce(shop_id, v_barber_shop_id);

  select
    s.id,
    s.shop_id,
    s.barber_id,
    s.is_active,
    s.deleted_at,
    s.price_bhd,
    s.duration_minutes,
    s.price,
    s.duration_min
  into v_service
  from public.services s
  where s.id = $1
  limit 1;

  if v_service.id is null then
    raise exception using message = 'SERVICE_NOT_FOUND';
  end if;

  if v_service.deleted_at is not null or v_service.is_active is not true then
    raise exception using message = 'SERVICE_INACTIVE';
  end if;

  if v_service.barber_id is not null and v_service.barber_id <> $3 then
    raise exception using message = 'SERVICE_NOT_FOR_BARBER';
  end if;

  if v_service.shop_id is not null then
    v_shop_id := coalesce(v_shop_id, v_service.shop_id);
    if v_shop_id <> v_service.shop_id then
      raise exception using message = 'SERVICE_NOT_FOR_SHOP';
    end if;
    if v_barber_shop_id is distinct from v_service.shop_id then
      raise exception using message = 'BARBER_NOT_IN_SHOP';
    end if;
  end if;

  v_duration := coalesce(v_service.duration_minutes, v_service.duration_min, 30);
  if v_duration <= 0 then
    raise exception using message = 'INVALID_DURATION';
  end if;

  v_price := coalesce(v_service.price_bhd, v_service.price, 0)::numeric(10,3);
  v_end_at := $2 + make_interval(mins => v_duration);

  select coalesce(br.buffer_minutes, s.buffer_minutes, 0)
  into v_buffer
  from public.barbers br
  left join public.barbershops s on s.id = br.shop_id
  where br.id = $3;

  if exists (
    select 1
    from public.barber_time_off t
    where t.barber_id = $3
      and tstzrange(t.starts_at, t.ends_at, '[)') && tstzrange($2, v_end_at, '[)')
  ) then
    raise exception using message = 'BARBER_TIME_OFF';
  end if;

  if exists (
    select 1
    from public.bookings b
    where b.barber_id = $3
      and b.status in ('pending','confirmed')
      and tstzrange(b.start_at, b.end_at + make_interval(mins => v_buffer), '[)') && tstzrange($2, v_end_at, '[)')
  ) then
    raise exception using message = 'BOOKING_OVERLAP';
  end if;

  if v_shop_id is not null then
    v_branch_id := public.ensure_shop_default_branch(v_shop_id);
  end if;

  insert into public.bookings (
    customer_profile_id,
    shop_id,
    branch_id,
    barber_id,
    service_id,
    start_at,
    end_at,
    status,
    notes,
    total_price,
    currency,
    price_bhd,
    duration_minutes
  )
  values (
    v_user,
    v_shop_id,
    v_branch_id,
    $3,
    $1,
    $2,
    v_end_at,
    'confirmed',
    $5,
    v_price,
    'BHD',
    v_price,
    v_duration
  )
  returning * into v_booking;

  return v_booking;
end;
$$;

create or replace function public.on_booking_created_notify()
returns trigger
language plpgsql
as $$
declare
  barber_profile uuid;
  shop_profile uuid;
  actor_profile uuid;
  msg_title text;
  msg_body text;
begin
  actor_profile := auth.uid();

  barber_profile := null;
  if new.barber_id is not null then
    select b.profile_id into barber_profile from public.barbers b where b.id = new.barber_id;
  end if;

  shop_profile := null;
  if new.shop_id is not null then
    select s.owner_profile_id into shop_profile from public.barbershops s where s.id = new.shop_id;
  end if;

  if new.status = 'confirmed' then
    msg_title := 'New booking confirmed';
    msg_body := 'A new booking has been confirmed.';
  else
    msg_title := 'New booking request';
    msg_body := 'You received a new booking request.';
  end if;

  if barber_profile is not null and barber_profile <> actor_profile then
    perform public.notify(
      barber_profile,
      'booking_created',
      msg_title,
      msg_body,
      jsonb_build_object(
        'booking_id',
        new.id,
        'status',
        new.status,
        'start_at',
        new.start_at,
        'end_at',
        new.end_at,
        'service_id',
        new.service_id,
        'barber_id',
        new.barber_id,
        'shop_id',
        new.shop_id
      )
    );
  end if;

  if shop_profile is not null and shop_profile <> actor_profile and shop_profile <> barber_profile then
    perform public.notify(
      shop_profile,
      'booking_created',
      msg_title,
      msg_body,
      jsonb_build_object(
        'booking_id',
        new.id,
        'status',
        new.status,
        'start_at',
        new.start_at,
        'end_at',
        new.end_at,
        'service_id',
        new.service_id,
        'barber_id',
        new.barber_id,
        'shop_id',
        new.shop_id
      )
    );
  end if;

  return new;
end;
$$;

create or replace function public.on_booking_updated_notify()
returns trigger
language plpgsql
as $$
declare
  barber_profile uuid;
  shop_profile uuid;
  actor_profile uuid;
  cancelled_by text;
  msg_type text;
  msg_title text;
  msg_body text;
begin
  actor_profile := coalesce(new.cancelled_by_profile_id, auth.uid());

  barber_profile := null;
  if new.barber_id is not null then
    select b.profile_id into barber_profile from public.barbers b where b.id = new.barber_id;
  end if;

  shop_profile := null;
  if new.shop_id is not null then
    select s.owner_profile_id into shop_profile from public.barbershops s where s.id = new.shop_id;
  end if;

  cancelled_by := null;
  if actor_profile is not null and actor_profile = new.customer_profile_id then
    cancelled_by := 'customer';
  elsif actor_profile is not null and actor_profile = barber_profile then
    cancelled_by := 'barber';
  elsif actor_profile is not null and actor_profile = shop_profile then
    cancelled_by := 'shop';
  end if;

  if new.start_at is distinct from old.start_at then
    msg_type := 'booking_rescheduled';
    msg_title := 'Booking rescheduled';
    msg_body := 'Your booking time has been updated.';

    if new.customer_profile_id is not null and new.customer_profile_id <> actor_profile then
      perform public.notify(
        new.customer_profile_id,
        msg_type,
        msg_title,
        msg_body,
        jsonb_build_object(
          'booking_id',
          new.id,
          'start_at',
          new.start_at,
          'end_at',
          new.end_at,
          'service_id',
          new.service_id,
          'barber_id',
          new.barber_id,
          'shop_id',
          new.shop_id
        )
      );
    end if;

    if barber_profile is not null and barber_profile <> actor_profile then
      perform public.notify(
        barber_profile,
        msg_type,
        msg_title,
        msg_body,
        jsonb_build_object(
          'booking_id',
          new.id,
          'start_at',
          new.start_at,
          'end_at',
          new.end_at,
          'service_id',
          new.service_id,
          'barber_id',
          new.barber_id,
          'shop_id',
          new.shop_id
        )
      );
    end if;

    if shop_profile is not null and shop_profile <> actor_profile and shop_profile <> barber_profile then
      perform public.notify(
        shop_profile,
        msg_type,
        msg_title,
        msg_body,
        jsonb_build_object(
          'booking_id',
          new.id,
          'start_at',
          new.start_at,
          'end_at',
          new.end_at,
          'service_id',
          new.service_id,
          'barber_id',
          new.barber_id,
          'shop_id',
          new.shop_id
        )
      );
    end if;
  end if;

  if new.status is distinct from old.status then
    msg_type := null;
    msg_title := null;
    msg_body := null;

    if new.status = 'confirmed' then
      msg_type := 'booking_confirmed';
      msg_title := 'Booking confirmed';
      msg_body := 'Your booking is confirmed.';
    elsif new.status = 'completed' then
      msg_type := 'booking_completed';
      msg_title := 'Booking completed';
      msg_body := 'Your booking was marked as completed.';
    elsif new.status = 'cancelled' then
      msg_type := 'booking_cancelled';
      msg_title := 'Booking cancelled';
      if cancelled_by = 'barber' then
        msg_body := 'Your booking has been cancelled by the barber.';
      elsif cancelled_by = 'shop' then
        msg_body := 'Your booking has been cancelled by the shop.';
      elsif cancelled_by = 'customer' then
        msg_body := 'A booking was cancelled by the customer.';
      else
        msg_body := 'A booking was cancelled.';
      end if;
    end if;

    if msg_type is not null then
      if new.customer_profile_id is not null and new.customer_profile_id <> actor_profile then
        perform public.notify(
          new.customer_profile_id,
          msg_type,
          msg_title,
          msg_body,
          jsonb_build_object(
            'booking_id',
            new.id,
            'status',
            new.status,
            'start_at',
            new.start_at,
            'end_at',
            new.end_at,
            'service_id',
            new.service_id,
            'barber_id',
            new.barber_id,
            'shop_id',
            new.shop_id,
            'cancelled_by',
            cancelled_by,
            'cancel_reason',
            new.cancel_reason
          )
        );
      end if;

      if barber_profile is not null and barber_profile <> actor_profile then
        perform public.notify(
          barber_profile,
          msg_type,
          msg_title,
          msg_body,
          jsonb_build_object(
            'booking_id',
            new.id,
            'status',
            new.status,
            'start_at',
            new.start_at,
            'end_at',
            new.end_at,
            'service_id',
            new.service_id,
            'barber_id',
            new.barber_id,
            'shop_id',
            new.shop_id,
            'cancelled_by',
            cancelled_by,
            'cancel_reason',
            new.cancel_reason
          )
        );
      end if;

      if shop_profile is not null and shop_profile <> actor_profile and shop_profile <> barber_profile then
        perform public.notify(
          shop_profile,
          msg_type,
          msg_title,
          msg_body,
          jsonb_build_object(
            'booking_id',
            new.id,
            'status',
            new.status,
            'start_at',
            new.start_at,
            'end_at',
            new.end_at,
            'service_id',
            new.service_id,
            'barber_id',
            new.barber_id,
            'shop_id',
            new.shop_id,
            'cancelled_by',
            cancelled_by,
            'cancel_reason',
            new.cancel_reason
          )
        );
      end if;
    end if;
  end if;

  return new;
end;
$$;

commit;


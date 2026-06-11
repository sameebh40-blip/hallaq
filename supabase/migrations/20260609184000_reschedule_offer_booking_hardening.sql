begin;

create or replace function public.reschedule_booking(booking_id uuid, new_start_at timestamptz)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_booking public.bookings%rowtype;
  v_offer record;
  v_end_at timestamptz;
  v_buffer int := 0;
  v_offer_id uuid;
  v_discount_amount numeric(10,3);
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  select * into v_booking
  from public.bookings b
  where b.id = booking_id
  limit 1;

  if v_booking.id is null then
    raise exception using message = 'BOOKING_NOT_FOUND';
  end if;

  if not (
    v_booking.customer_profile_id = v_user
    or exists (select 1 from public.barbers br where br.id = v_booking.barber_id and br.profile_id = v_user)
    or exists (select 1 from public.barbershops s where s.id = v_booking.shop_id and s.owner_profile_id = v_user)
    or public.is_admin()
  ) then
    raise exception using message = 'FORBIDDEN';
  end if;

  if v_booking.status in ('cancelled', 'completed', 'in_progress', 'no_show') then
    raise exception using message = 'BOOKING_NOT_RESCHEDULABLE';
  end if;

  if v_booking.start_at <= now() or new_start_at <= now() then
    raise exception using message = 'TOO_LATE_TO_RESCHEDULE';
  end if;

  if v_booking.duration_minutes is null or v_booking.duration_minutes <= 0 then
    raise exception using message = 'INVALID_DURATION';
  end if;

  select coalesce(b.buffer_minutes, 0)
  into v_buffer
  from public.barbers br
  left join public.barbershops b on b.id = br.shop_id
  where br.id = v_booking.barber_id;

  v_end_at := new_start_at + make_interval(mins => v_booking.duration_minutes);

  if exists (
    select 1
    from public.barber_time_off t
    where t.barber_id = v_booking.barber_id
      and tstzrange(t.starts_at, t.ends_at, '[)') && tstzrange(new_start_at, v_end_at, '[)')
  ) then
    raise exception using message = 'BARBER_TIME_OFF';
  end if;

  if exists (
    select 1
    from public.bookings b
    where b.barber_id = v_booking.barber_id
      and b.id <> v_booking.id
      and b.status in ('pending', 'confirmed', 'rescheduled', 'in_progress')
      and tstzrange(b.start_at, b.end_at + make_interval(mins => v_buffer), '[)') && tstzrange(new_start_at, v_end_at, '[)')
  ) then
    raise exception using message = 'BOOKING_OVERLAP';
  end if;

  v_offer_id := v_booking.offer_id;
  v_discount_amount := coalesce(v_booking.discount_amount, 0)::numeric(10,3);

  if v_offer_id is not null then
    select id, shop_id, barber_id, active, is_active, status, valid_from, valid_to
    into v_offer
    from public.offers o
    where o.id = v_offer_id
    limit 1;

    if v_offer.id is null
      or coalesce(v_offer.active, true) is not true
      or coalesce(v_offer.is_active, true) is not true
      or v_offer.status <> 'approved'
      or (v_offer.valid_from is not null and v_offer.valid_from > new_start_at)
      or (v_offer.valid_to is not null and v_offer.valid_to < new_start_at)
      or (v_offer.barber_id is not null and v_offer.barber_id <> v_booking.barber_id)
      or (v_offer.shop_id is not null and v_offer.shop_id <> v_booking.shop_id) then
      v_offer_id := null;
      v_discount_amount := 0;
    end if;
  end if;

  update public.bookings
  set start_at = new_start_at,
      end_at = v_end_at,
      offer_id = v_offer_id,
      discount_amount = v_discount_amount,
      total_price = greatest(coalesce(v_booking.price_bhd, v_booking.total_price, 0)::numeric(10,3) - v_discount_amount, 0)::numeric(10,3),
      rescheduled_at = now(),
      rescheduled_by_profile_id = v_user,
      updated_at = now()
  where id = booking_id
  returning * into v_booking;

  return v_booking;
end;
$$;

do $$
begin
  if to_regprocedure('public.reschedule_booking(uuid, timestamptz)') is not null then
    revoke all on function public.reschedule_booking(uuid, timestamptz) from public;
  end if;

  if to_regprocedure('public.reschedule_booking(uuid, timestamptz)') is not null
     and exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.reschedule_booking(uuid, timestamptz) to authenticated;
  end if;
end;
$$;

commit;

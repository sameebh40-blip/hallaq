begin;

update public.bookings
set status = 'confirmed',
    rescheduled_at = coalesce(rescheduled_at, updated_at, created_at, now()),
    updated_at = now()
where status = 'rescheduled';

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'bookings_no_overlap_per_barber'
      and conrelid = 'public.bookings'::regclass
  ) then
    alter table public.bookings drop constraint bookings_no_overlap_per_barber;
  end if;

  alter table public.bookings
    add constraint bookings_no_overlap_per_barber
    exclude using gist (
      barber_id with =,
      tstzrange(start_at, end_at, '[)') with &&
    )
    where (status in ('pending', 'confirmed', 'in_progress', 'rescheduled'));
end $$;

create or replace function public.reschedule_booking(booking_id uuid, new_start_at timestamptz)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_booking public.bookings%rowtype;
  v_end_at timestamptz;
  v_buffer int := 0;
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
    or (v_booking.branch_id is not null and public.is_branch_staff(v_booking.branch_id))
    or public.is_admin()
  ) then
    raise exception using message = 'FORBIDDEN';
  end if;

  if v_booking.status in ('cancelled', 'completed', 'no_show') then
    raise exception using message = 'BOOKING_NOT_RESCHEDULABLE';
  end if;

  if v_booking.start_at <= now() then
    raise exception using message = 'TOO_LATE_TO_RESCHEDULE';
  end if;

  if v_booking.duration_minutes is null or v_booking.duration_minutes <= 0 then
    raise exception using message = 'INVALID_DURATION';
  end if;

  select coalesce(br.buffer_minutes, s.buffer_minutes, 0)
  into v_buffer
  from public.barbers br
  left join public.barbershops s on s.id = br.shop_id
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
      and b.status in ('pending', 'confirmed', 'in_progress', 'rescheduled')
      and tstzrange(b.start_at, b.end_at + make_interval(mins => v_buffer), '[)') && tstzrange(new_start_at, v_end_at, '[)')
  ) then
    raise exception using message = 'BOOKING_OVERLAP';
  end if;

  update public.bookings
  set start_at = new_start_at,
      end_at = v_end_at,
      rescheduled_at = now(),
      rescheduled_by_profile_id = v_user,
      updated_at = now()
  where id = booking_id
  returning * into v_booking;

  return v_booking;
end;
$$;

create or replace function public.start_booking(booking_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_booking public.bookings%rowtype;
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
    exists (select 1 from public.barbers br where br.id = v_booking.barber_id and br.profile_id = v_user)
    or exists (select 1 from public.barbershops s where s.id = v_booking.shop_id and s.owner_profile_id = v_user)
    or (v_booking.branch_id is not null and public.is_branch_staff(v_booking.branch_id))
    or public.is_admin()
  ) then
    raise exception using message = 'FORBIDDEN';
  end if;

  if v_booking.status not in ('confirmed', 'rescheduled') then
    raise exception using message = 'BOOKING_NOT_STARTABLE';
  end if;

  update public.bookings
  set status = 'in_progress',
      updated_at = now()
  where id = v_booking.id
  returning * into v_booking;

  return v_booking;
end;
$$;

create or replace function public.complete_booking(booking_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_booking public.bookings%rowtype;
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
    exists (select 1 from public.barbers br where br.id = v_booking.barber_id and br.profile_id = v_user)
    or exists (select 1 from public.barbershops s where s.id = v_booking.shop_id and s.owner_profile_id = v_user)
    or (v_booking.branch_id is not null and public.is_branch_staff(v_booking.branch_id))
    or public.is_admin()
  ) then
    raise exception using message = 'FORBIDDEN';
  end if;

  if v_booking.status not in ('confirmed', 'rescheduled', 'in_progress') then
    raise exception using message = 'BOOKING_NOT_COMPLETABLE';
  end if;

  update public.bookings
  set status = 'completed',
      updated_at = now()
  where id = v_booking.id
  returning * into v_booking;

  return v_booking;
end;
$$;

create or replace function public.mark_booking_no_show(booking_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_booking public.bookings%rowtype;
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
    exists (select 1 from public.barbers br where br.id = v_booking.barber_id and br.profile_id = v_user)
    or exists (select 1 from public.barbershops s where s.id = v_booking.shop_id and s.owner_profile_id = v_user)
    or (v_booking.branch_id is not null and public.is_branch_staff(v_booking.branch_id))
    or public.is_admin()
  ) then
    raise exception using message = 'FORBIDDEN';
  end if;

  if v_booking.status not in ('confirmed', 'rescheduled', 'in_progress') then
    raise exception using message = 'BOOKING_NOT_NO_SHOW';
  end if;

  update public.bookings
  set status = 'no_show',
      updated_at = now()
  where id = v_booking.id
  returning * into v_booking;

  return v_booking;
end;
$$;

commit;

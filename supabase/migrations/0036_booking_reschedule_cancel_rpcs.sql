begin;

alter table public.bookings add column if not exists cancelled_at timestamptz;
alter table public.bookings add column if not exists cancelled_by_profile_id uuid references public.profiles (id) on delete set null;
alter table public.bookings add column if not exists cancel_reason text;
alter table public.bookings add column if not exists rescheduled_at timestamptz;
alter table public.bookings add column if not exists rescheduled_by_profile_id uuid references public.profiles (id) on delete set null;

create or replace function public.cancel_booking(booking_id uuid, reason text default null)
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
    v_booking.customer_profile_id = v_user
    or exists (select 1 from public.barbers br where br.id = v_booking.barber_id and br.profile_id = v_user)
    or exists (select 1 from public.barbershops s where s.id = v_booking.shop_id and s.owner_profile_id = v_user)
    or public.is_admin()
  ) then
    raise exception using message = 'FORBIDDEN';
  end if;

  if v_booking.status in ('cancelled','completed') then
    return v_booking;
  end if;

  if v_booking.start_at <= now() then
    raise exception using message = 'TOO_LATE_TO_CANCEL';
  end if;

  update public.bookings
  set status = 'cancelled',
      cancelled_at = now(),
      cancelled_by_profile_id = v_user,
      cancel_reason = nullif(trim(reason), ''),
      updated_at = now()
  where id = booking_id
  returning * into v_booking;

  return v_booking;
end;
$$;

do $$
begin
  if to_regprocedure('public.cancel_booking(uuid, text)') is not null then
    revoke all on function public.cancel_booking(uuid, text) from public;
  end if;

  if to_regprocedure('public.cancel_booking(uuid, text)') is not null
     and exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.cancel_booking(uuid, text) to authenticated;
  end if;
end;
$$;

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
    or public.is_admin()
  ) then
    raise exception using message = 'FORBIDDEN';
  end if;

  if v_booking.status in ('cancelled','completed') then
    raise exception using message = 'BOOKING_NOT_RESCHEDULABLE';
  end if;

  if v_booking.start_at <= now() then
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
      and b.status in ('pending','confirmed')
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

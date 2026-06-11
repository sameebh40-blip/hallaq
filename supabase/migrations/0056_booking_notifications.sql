begin;

create or replace function public.on_booking_created_notify()
returns trigger
language plpgsql
as $$
declare
  barber_profile uuid;
  shop_profile uuid;
  actor_profile uuid;
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

  if barber_profile is not null and barber_profile <> actor_profile then
    perform public.notify(
      barber_profile,
      'booking_created',
      'New booking request',
      'You received a new booking request.',
      jsonb_build_object('booking_id', new.id, 'status', new.status, 'start_at', new.start_at)
    );
  end if;

  if shop_profile is not null and shop_profile <> actor_profile and shop_profile <> barber_profile then
    perform public.notify(
      shop_profile,
      'booking_created',
      'New booking request',
      'You received a new booking request.',
      jsonb_build_object('booking_id', new.id, 'status', new.status, 'start_at', new.start_at)
    );
  end if;

  return new;
end;
$$;

drop trigger if exists bookings_notify_created on public.bookings;
create trigger bookings_notify_created
after insert on public.bookings
for each row execute function public.on_booking_created_notify();

create or replace function public.on_booking_updated_notify()
returns trigger
language plpgsql
as $$
declare
  barber_profile uuid;
  shop_profile uuid;
  actor_profile uuid;
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
        jsonb_build_object('booking_id', new.id, 'start_at', new.start_at, 'end_at', new.end_at)
      );
    end if;

    if barber_profile is not null and barber_profile <> actor_profile then
      perform public.notify(
        barber_profile,
        msg_type,
        msg_title,
        msg_body,
        jsonb_build_object('booking_id', new.id, 'start_at', new.start_at, 'end_at', new.end_at)
      );
    end if;

    if shop_profile is not null and shop_profile <> actor_profile and shop_profile <> barber_profile then
      perform public.notify(
        shop_profile,
        msg_type,
        msg_title,
        msg_body,
        jsonb_build_object('booking_id', new.id, 'start_at', new.start_at, 'end_at', new.end_at)
      );
    end if;
  end if;

  if new.status is distinct from old.status then
    msg_type := null;
    msg_title := null;
    msg_body := null;

    if new.status = 'confirmed' then
      msg_type := 'booking_accepted';
      msg_title := 'Booking accepted';
      msg_body := 'Your booking was accepted.';
    elsif new.status = 'completed' then
      msg_type := 'booking_completed';
      msg_title := 'Booking completed';
      msg_body := 'Your booking was marked as completed.';
    elsif new.status = 'cancelled' then
      if actor_profile is not null and actor_profile = new.customer_profile_id then
        msg_type := 'booking_cancelled';
        msg_title := 'Booking cancelled';
        msg_body := 'A booking was cancelled by the customer.';
      else
        msg_type := 'booking_rejected';
        msg_title := 'Booking rejected';
        msg_body := 'Your booking request was rejected.';
      end if;
    end if;

    if msg_type is not null then
      if new.customer_profile_id is not null and new.customer_profile_id <> actor_profile then
        perform public.notify(
          new.customer_profile_id,
          msg_type,
          msg_title,
          msg_body,
          jsonb_build_object('booking_id', new.id, 'status', new.status, 'start_at', new.start_at)
        );
      end if;

      if barber_profile is not null and barber_profile <> actor_profile then
        perform public.notify(
          barber_profile,
          msg_type,
          msg_title,
          msg_body,
          jsonb_build_object('booking_id', new.id, 'status', new.status, 'start_at', new.start_at)
        );
      end if;

      if shop_profile is not null and shop_profile <> actor_profile and shop_profile <> barber_profile then
        perform public.notify(
          shop_profile,
          msg_type,
          msg_title,
          msg_body,
          jsonb_build_object('booking_id', new.id, 'status', new.status, 'start_at', new.start_at)
        );
      end if;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists bookings_notify_updated on public.bookings;
create trigger bookings_notify_updated
after update on public.bookings
for each row execute function public.on_booking_updated_notify();

commit;


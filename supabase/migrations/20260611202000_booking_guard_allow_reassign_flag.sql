begin;

create or replace function public.bookings_guard_update()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_minutes int;
  v_actor uuid;
  v_cancelled_by text;
  v_allow_reassign boolean := coalesce(nullif(current_setting('hallaq.allow_booking_reassign', true), ''), '') = '1';
begin
  if public.is_admin() then
    if new.source_post_id is null and new.reel_id is not null then
      new.source_post_id := new.reel_id;
    end if;
    if new.reel_id is null and new.source_post_id is not null then
      new.reel_id := new.source_post_id;
    end if;
    new.customer_id := new.customer_profile_id;
    new.date := ((new.start_at at time zone 'Asia/Bahrain')::date);
    new.start_time := ((new.start_at at time zone 'Asia/Bahrain')::time);
    new.end_time := ((new.end_at at time zone 'Asia/Bahrain')::time);
    if new.cancel_reason is null and new.cancelled_reason is not null then
      new.cancel_reason := new.cancelled_reason;
    end if;
    if new.cancelled_reason is null and new.cancel_reason is not null then
      new.cancelled_reason := new.cancel_reason;
    end if;
    return new;
  end if;

  if new.customer_profile_id is distinct from old.customer_profile_id then
    raise exception using message = 'BOOKING_CUSTOMER_IMMUTABLE';
  end if;
  if new.shop_id is distinct from old.shop_id then
    raise exception using message = 'BOOKING_SHOP_IMMUTABLE';
  end if;
  if new.barber_id is distinct from old.barber_id then
    if not v_allow_reassign then
      raise exception using message = 'BOOKING_BARBER_IMMUTABLE';
    end if;
  end if;
  if new.service_id is distinct from old.service_id then
    raise exception using message = 'BOOKING_SERVICE_IMMUTABLE';
  end if;
  if new.duration_minutes is distinct from old.duration_minutes then
    raise exception using message = 'BOOKING_DURATION_IMMUTABLE';
  end if;

  if new.status is distinct from old.status then
    if old.status = 'pending' and new.status in ('confirmed','cancelled') then
      null;
    elsif old.status = 'confirmed' and new.status in ('in_progress','completed','cancelled','no_show','rescheduled') then
      null;
    elsif old.status = 'in_progress' and new.status in ('completed','cancelled','no_show') then
      null;
    elsif old.status = 'rescheduled' and new.status in ('confirmed','in_progress','completed','cancelled','no_show') then
      null;
    else
      raise exception using message = 'INVALID_STATUS_TRANSITION';
    end if;

    v_actor := coalesce(new.cancelled_by_profile_id, auth.uid());

    if new.status = 'confirmed' and new.confirmed_at is null then
      new.confirmed_at := now();
    end if;
    if new.status = 'in_progress' and new.started_at is null then
      new.started_at := now();
    end if;
    if new.status = 'completed' and new.completed_at is null then
      new.completed_at := now();
    end if;
    if new.status = 'no_show' and new.no_show_at is null then
      new.no_show_at := now();
    end if;

    if new.status = 'cancelled' then
      if new.cancelled_at is null then new.cancelled_at := now(); end if;
      if new.cancelled_by_profile_id is null then new.cancelled_by_profile_id := v_actor; end if;
      if new.cancelled_reason is null and new.cancel_reason is not null then new.cancelled_reason := new.cancel_reason; end if;
      if new.cancel_reason is null and new.cancelled_reason is not null then new.cancel_reason := new.cancelled_reason; end if;

      if new.cancelled_by is null or new.cancelled_by = '' then
        if public.is_admin() then
          v_cancelled_by := 'admin';
        elsif v_actor = old.customer_profile_id then
          v_cancelled_by := 'customer';
        elsif old.barber_id is not null and public.is_barber_owner(old.barber_id) then
          v_cancelled_by := 'barber';
        elsif old.shop_id is not null and public.is_shop_owner(old.shop_id) then
          v_cancelled_by := 'shop';
        else
          v_cancelled_by := null;
        end if;
        new.cancelled_by := v_cancelled_by;
      end if;
    end if;

    if new.status = 'rescheduled' then
      if new.rescheduled_at is null then new.rescheduled_at := now(); end if;
      if new.rescheduled_by_profile_id is null then new.rescheduled_by_profile_id := v_actor; end if;
    end if;
  end if;

  if new.start_at is distinct from old.start_at then
    v_minutes := coalesce(new.duration_minutes, old.duration_minutes);
    if old.start_at <= now() then
      raise exception using message = 'TOO_LATE_TO_RESCHEDULE';
    end if;
    if v_minutes is null or v_minutes <= 0 then
      v_minutes := greatest(1, round(extract(epoch from (old.end_at - old.start_at)) / 60.0)::int);
    end if;
    if new.start_at <= now() then
      raise exception using message = 'BOOKING_PAST_TIME';
    end if;
    new.end_at := new.start_at + make_interval(mins => v_minutes);
  end if;

  if new.end_at <= new.start_at then
    raise exception using message = 'INVALID_TIME_RANGE';
  end if;

  if new.source_post_id is null and new.reel_id is not null then
    new.source_post_id := new.reel_id;
  end if;
  if new.reel_id is null and new.source_post_id is not null then
    new.reel_id := new.source_post_id;
  end if;

  new.customer_id := new.customer_profile_id;
  new.date := ((new.start_at at time zone 'Asia/Bahrain')::date);
  new.start_time := ((new.start_at at time zone 'Asia/Bahrain')::time);
  new.end_time := ((new.end_at at time zone 'Asia/Bahrain')::time);

  return new;
end;
$$;

commit;

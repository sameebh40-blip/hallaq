begin;

create or replace function public.bookings_guard_customer_updates()
returns trigger
language plpgsql
as $$
declare
  v_user uuid;
begin
  v_user := auth.uid();

  if v_user is not null and v_user = old.customer_profile_id and not public.is_admin() then
    if new.status = 'cancelled' then
      if new.customer_profile_id is distinct from old.customer_profile_id
        or new.shop_id is distinct from old.shop_id
        or new.branch_id is distinct from old.branch_id
        or new.barber_id is distinct from old.barber_id
        or new.service_id is distinct from old.service_id
        or new.start_at is distinct from old.start_at
        or new.end_at is distinct from old.end_at
        or new.total_price is distinct from old.total_price
        or new.currency is distinct from old.currency
        or new.price_bhd is distinct from old.price_bhd
        or new.duration_minutes is distinct from old.duration_minutes
        or new.rescheduled_at is distinct from old.rescheduled_at
        or new.rescheduled_by_profile_id is distinct from old.rescheduled_by_profile_id
      then
        raise exception using message = 'FORBIDDEN';
      end if;
      return new;
    end if;

    if new.status is distinct from old.status then
      raise exception using message = 'FORBIDDEN';
    end if;

    if new.rescheduled_by_profile_id = v_user and new.rescheduled_at is not null then
      if new.customer_profile_id is distinct from old.customer_profile_id
        or new.shop_id is distinct from old.shop_id
        or new.branch_id is distinct from old.branch_id
        or new.barber_id is distinct from old.barber_id
        or new.service_id is distinct from old.service_id
        or new.total_price is distinct from old.total_price
        or new.currency is distinct from old.currency
        or new.price_bhd is distinct from old.price_bhd
        or new.duration_minutes is distinct from old.duration_minutes
        or new.cancelled_at is distinct from old.cancelled_at
        or new.cancelled_by_profile_id is distinct from old.cancelled_by_profile_id
        or new.cancel_reason is distinct from old.cancel_reason
      then
        raise exception using message = 'FORBIDDEN';
      end if;
      return new;
    end if;

    raise exception using message = 'FORBIDDEN';
  end if;

  return new;
end;
$$;

commit;


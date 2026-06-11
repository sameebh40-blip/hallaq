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
    if new.status <> 'cancelled' then
      raise exception using message = 'FORBIDDEN';
    end if;

    if new.customer_profile_id is distinct from old.customer_profile_id
      or new.shop_id is distinct from old.shop_id
      or new.barber_id is distinct from old.barber_id
      or new.service_id is distinct from old.service_id
      or new.start_at is distinct from old.start_at
      or new.end_at is distinct from old.end_at
      or new.total_price is distinct from old.total_price
      or new.currency is distinct from old.currency
      or new.price_bhd is distinct from old.price_bhd
      or new.duration_minutes is distinct from old.duration_minutes
    then
      raise exception using message = 'FORBIDDEN';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists bookings_guard_customer_updates on public.bookings;
create trigger bookings_guard_customer_updates
before update on public.bookings
for each row execute function public.bookings_guard_customer_updates();

commit;


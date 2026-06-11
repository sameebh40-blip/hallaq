begin;

create or replace function public.notify(
  profile uuid,
  ntype text,
  title text,
  body text,
  payload jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  jwt_role text;
begin
  jwt_role := nullif(current_setting('request.jwt.claim.role', true), '');

  if pg_trigger_depth() = 0 and jwt_role is distinct from 'service_role' and current_user <> 'postgres' then
    raise exception using message = 'FORBIDDEN';
  end if;

  insert into public.notifications (profile_id, type, title, body, data)
  values (profile, ntype, title, body, payload);
end;
$$;

drop trigger if exists bookings_notify_insert on public.bookings;
drop trigger if exists bookings_notify_status on public.bookings;
drop function if exists public.on_booking_inserted();
drop function if exists public.on_booking_status_changed();

commit;

begin;

drop function if exists public.create_booking_with_hold(
  uuid,
  timestamptz,
  uuid,
  uuid,
  uuid,
  text,
  text,
  uuid
);

create or replace function public.create_booking_with_hold(
  service_id uuid,
  start_at timestamptz,
  barber_id uuid,
  hold_id uuid,
  shop_id uuid,
  notes text,
  payment_method text,
  source_post_id uuid
)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.create_booking_with_hold($1, $2, $3, $4, $5, $6);
end;
$$;

do $$
begin
  if to_regprocedure('public.create_booking_with_hold(uuid, timestamptz, uuid, uuid, uuid, text, text, uuid)') is not null then
    revoke all on function public.create_booking_with_hold(uuid, timestamptz, uuid, uuid, uuid, text, text, uuid) from public;
  end if;

  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    if to_regprocedure('public.create_booking_with_hold(uuid, timestamptz, uuid, uuid, uuid, text, text, uuid)') is not null then
      grant execute on function public.create_booking_with_hold(uuid, timestamptz, uuid, uuid, uuid, text, text, uuid) to authenticated;
    end if;
  end if;
end;
$$;

commit;

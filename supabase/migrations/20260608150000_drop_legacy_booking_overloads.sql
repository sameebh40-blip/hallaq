begin;

do $$
begin
  -- Keep the newer 7-arg create_booking overload and remove the legacy 5-arg version
  -- so Postgres stops treating calls with default arguments as ambiguous.
  if to_regprocedure('public.create_booking(uuid, timestamptz, uuid, uuid, text, text, uuid)') is not null
     and to_regprocedure('public.create_booking(uuid, timestamptz, uuid, uuid, text)') is not null then
    drop function public.create_booking(uuid, timestamptz, uuid, uuid, text);
  end if;

  -- Keep the newer 8-arg create_booking_with_hold overload and remove the legacy 6-arg version.
  if to_regprocedure('public.create_booking_with_hold(uuid, timestamptz, uuid, uuid, uuid, text, text, uuid)') is not null
     and to_regprocedure('public.create_booking_with_hold(uuid, timestamptz, uuid, uuid, uuid, text)') is not null then
    drop function public.create_booking_with_hold(uuid, timestamptz, uuid, uuid, uuid, text);
  end if;
end
$$;

commit;

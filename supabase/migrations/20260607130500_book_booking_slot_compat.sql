begin;

do $$
begin
  if to_regprocedure('public.book_booking_slot(uuid,timestamptz,uuid,uuid,int)') is null then
    create or replace function public.book_booking_slot(
      service_id uuid,
      start_at timestamptz,
      barber_id uuid,
      shop_id uuid default null,
      hold_minutes int default 5
    )
    returns public.bookings
    language plpgsql
    security definer
    set search_path = public
    as $f$
    declare
      v_hold record;
    begin
      select *
      into v_hold
      from public.hold_booking_slot($1, $2, $3, $4, $5);

      return public.create_booking_with_hold($1, $2, $3, v_hold.hold_id, $4, null);
    end;
    $f$;
  end if;
end;
$$;

commit;

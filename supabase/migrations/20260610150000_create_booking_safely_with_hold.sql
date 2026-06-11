begin;

drop function if exists public.create_booking_safely(
  uuid,
  timestamptz,
  uuid,
  uuid,
  text,
  text,
  uuid,
  text,
  uuid,
  uuid,
  numeric
);

create or replace function public.create_booking_safely(
  service_id uuid,
  start_at timestamptz,
  barber_id uuid,
  shop_id uuid default null,
  notes text default null,
  payment_method text default 'cash',
  source_post_id uuid default null,
  source text default 'unknown',
  reel_id uuid default null,
  offer_id uuid default null,
  discount_amount numeric(10,3) default 0,
  hold_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_hold public.booking_slot_holds%rowtype;
  v_booking public.bookings%rowtype;
begin
  if hold_id is not null then
    v_user := auth.uid();
    if v_user is null then
      return jsonb_build_object('ok', false, 'error', 'NOT_AUTHENTICATED');
    end if;

    select *
    into v_hold
    from public.booking_slot_holds h
    where h.id = hold_id
      and h.profile_id = v_user
      and h.consumed_at is null
      and h.expires_at > now()
    for update;

    if v_hold.id is null then
      return jsonb_build_object('ok', false, 'error', 'HOLD_NOT_FOUND');
    end if;

    if v_hold.service_id is distinct from service_id
      or v_hold.barber_id is distinct from barber_id
      or v_hold.start_at is distinct from start_at
      or (
        shop_id is not null
        and v_hold.shop_id is distinct from shop_id
      ) then
      return jsonb_build_object('ok', false, 'error', 'HOLD_MISMATCH');
    end if;
  end if;

  begin
    v_booking := public.create_booking(
      service_id,
      start_at,
      barber_id,
      shop_id,
      notes,
      payment_method,
      source_post_id,
      source,
      reel_id,
      offer_id,
      discount_amount
    );

    if hold_id is not null then
      update public.booking_slot_holds
      set consumed_at = now()
      where id = hold_id
        and consumed_at is null;
    end if;

    return jsonb_build_object('ok', true, 'booking', to_jsonb(v_booking));
  exception when others then
    return jsonb_build_object('ok', false, 'error', sqlerrm);
  end;
end;
$$;

revoke all on function public.create_booking_safely(uuid, timestamptz, uuid, uuid, text, text, uuid, text, uuid, uuid, numeric, uuid) from public;
grant execute on function public.create_booking_safely(uuid, timestamptz, uuid, uuid, text, text, uuid, text, uuid, uuid, numeric, uuid) to authenticated;

commit;

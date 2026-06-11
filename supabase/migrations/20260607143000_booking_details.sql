begin;

create or replace view public.booking_details as
select
  b.id,
  b.customer_profile_id,
  p.full_name as customer_name,
  p.phone as customer_phone,
  b.barber_id,
  br.display_name as barber_name,
  b.shop_id,
  sh.name as shop_name,
  b.service_id,
  s.name_en as service_name_en,
  s.name_ar as service_name_ar,
  b.start_at,
  b.end_at,
  b.status,
  b.notes,
  b.total_price,
  b.currency,
  b.created_at,
  b.updated_at
from public.bookings b
left join public.profiles p on p.id = b.customer_profile_id
left join public.services s on s.id = b.service_id
left join public.barbers br on br.id = b.barber_id
left join public.barbershops sh on sh.id = b.shop_id;

create or replace function public.get_booking_details(booking_id uuid)
returns table (
  id uuid,
  customer_profile_id uuid,
  customer_name text,
  customer_phone text,
  barber_id uuid,
  barber_name text,
  shop_id uuid,
  shop_name text,
  service_id uuid,
  service_name_en text,
  service_name_ar text,
  start_at timestamptz,
  end_at timestamptz,
  status text,
  notes text,
  total_price numeric,
  currency text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_user uuid;
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  if not (public.is_admin() or public.is_booking_participant(booking_id)) then
    raise exception using message = 'FORBIDDEN';
  end if;

  return query
  select
    bd.id,
    bd.customer_profile_id,
    bd.customer_name,
    bd.customer_phone,
    bd.barber_id,
    bd.barber_name,
    bd.shop_id,
    bd.shop_name,
    bd.service_id,
    bd.service_name_en,
    bd.service_name_ar,
    bd.start_at,
    bd.end_at,
    bd.status,
    bd.notes,
    bd.total_price,
    bd.currency,
    bd.created_at,
    bd.updated_at
  from public.booking_details bd
  where bd.id = booking_id;
end;
$$;

do $$
begin
  if to_regprocedure('public.get_booking_details(uuid)') is not null then
    revoke all on function public.get_booking_details(uuid) from public;
  end if;

  if to_regprocedure('public.get_booking_details(uuid)') is not null
     and exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.get_booking_details(uuid) to authenticated;
  end if;
end;
$$;

commit;


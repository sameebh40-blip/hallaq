begin;

create or replace view public.booking_details as
select
  b.id,
  b.customer_profile_id,
  coalesce(p.full_name, b.customer_name) as customer_name,
  coalesce(p.phone, b.customer_phone) as customer_phone,
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

commit;

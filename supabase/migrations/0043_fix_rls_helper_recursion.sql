begin;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
  );
$$;

create or replace function public.is_shop_owner(shop uuid)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.barbershops s
    where s.id = shop
      and s.owner_profile_id = auth.uid()
  );
$$;

create or replace function public.is_barber_owner(barber uuid)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.barbers b
    where b.id = barber
      and b.profile_id = auth.uid()
  );
$$;

create or replace function public.is_booking_participant(booking uuid)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.bookings bk
    left join public.barbers b on b.id = bk.barber_id
    left join public.barbershops s on s.id = bk.shop_id
    where bk.id = booking
      and (
        bk.customer_profile_id = auth.uid()
        or (b.profile_id = auth.uid())
        or (s.owner_profile_id = auth.uid())
      )
  );
$$;

commit;

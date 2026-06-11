create or replace function public.recompute_target_rating(target_type text, target_id uuid)
returns void
language plpgsql
as $$
declare
  avg_rating numeric(3,2);
  cnt int;
begin
  select coalesce(round(avg(r.rating)::numeric, 2), 0), coalesce(count(*), 0)
  into avg_rating, cnt
  from public.reviews r
  where r.target_type = target_type and r.target_id = target_id;

  if target_type = 'barber' then
    update public.barbers
    set rating_avg = avg_rating, rating_count = cnt
    where id = target_id;
  elsif target_type = 'shop' then
    update public.barbershops
    set rating_avg = avg_rating, rating_count = cnt
    where id = target_id;
  end if;
end;
$$;

create or replace function public.on_review_changed()
returns trigger
language plpgsql
as $$
begin
  if (tg_op = 'INSERT') then
    perform public.recompute_target_rating(new.target_type, new.target_id);
    return new;
  end if;
  if (tg_op = 'UPDATE') then
    if (old.target_type <> new.target_type or old.target_id <> new.target_id) then
      perform public.recompute_target_rating(old.target_type, old.target_id);
    end if;
    perform public.recompute_target_rating(new.target_type, new.target_id);
    return new;
  end if;
  if (tg_op = 'DELETE') then
    perform public.recompute_target_rating(old.target_type, old.target_id);
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists reviews_rating_sync on public.reviews;
create trigger reviews_rating_sync
after insert or update or delete on public.reviews
for each row execute function public.on_review_changed();

create or replace function public.notify(profile uuid, ntype text, title text, body text, payload jsonb default '{}'::jsonb)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.notifications (profile_id, type, title, body, data)
  values (profile, ntype, title, body, payload);
$$;

create or replace function public.on_booking_inserted()
returns trigger
language plpgsql
as $$
declare
  provider_profile uuid;
begin
  perform public.notify(new.customer_profile_id, 'booking_confirmation', 'Booking received', 'Your booking request was received', jsonb_build_object('booking_id', new.id));

  if new.barber_id is not null then
    select b.profile_id into provider_profile from public.barbers b where b.id = new.barber_id;
    if provider_profile is not null then
      perform public.notify(provider_profile, 'booking_new', 'New booking', 'You have a new booking request', jsonb_build_object('booking_id', new.id));
    end if;
  elsif new.shop_id is not null then
    select s.owner_profile_id into provider_profile from public.barbershops s where s.id = new.shop_id;
    if provider_profile is not null then
      perform public.notify(provider_profile, 'booking_new', 'New booking', 'You have a new booking request', jsonb_build_object('booking_id', new.id));
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists bookings_notify_insert on public.bookings;
create trigger bookings_notify_insert
after insert on public.bookings
for each row execute function public.on_booking_inserted();

create or replace function public.on_booking_status_changed()
returns trigger
language plpgsql
as $$
begin
  if old.status is distinct from new.status then
    perform public.notify(new.customer_profile_id, 'booking_status', 'Booking update', 'Your booking status changed to ' || new.status, jsonb_build_object('booking_id', new.id, 'status', new.status));
  end if;
  return new;
end;
$$;

drop trigger if exists bookings_notify_status on public.bookings;
create trigger bookings_notify_status
after update on public.bookings
for each row execute function public.on_booking_status_changed();

begin;

drop policy if exists "notifications_insert_own" on public.notifications;

create index if not exists bookings_shop_status_start_idx on public.bookings (shop_id, status, start_at desc);
create index if not exists bookings_barber_status_start_idx on public.bookings (barber_id, status, start_at desc);

do $$
declare
  t text;
begin
  for t in
    select unnest(ARRAY[
      'bookings',
      'booking_events',
      'notifications',
      'payments',
      'barbers',
      'barbershops',
      'services',
      'shop_barbers',
      'branches',
      'profiles'
    ]::text[])
  loop
    if to_regclass('public.' || t) is not null then
      execute format('alter table public.%I replica identity full', t);
      begin
        execute format('alter publication supabase_realtime add table public.%I', t);
      exception
        when duplicate_object then null;
        when undefined_object then null;
      end;
    end if;
  end loop;
end;
$$;

commit;

begin;

create table if not exists public.booking_reminder_log (
  booking_id uuid not null references public.bookings (id) on delete cascade,
  reminder_type text not null check (reminder_type in ('customer_2h','provider_2h')),
  sent_at timestamptz not null default now(),
  primary key (booking_id, reminder_type)
);

alter table public.booking_reminder_log enable row level security;

drop policy if exists "booking_reminder_log_admin_read" on public.booking_reminder_log;
create policy "booking_reminder_log_admin_read"
on public.booking_reminder_log
for select
to authenticated
using (public.is_admin());

create or replace function public.send_booking_reminders(now_ts timestamptz default now())
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int := 0;
  r record;
  v_provider_profile uuid;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception using message = 'FORBIDDEN';
  end if;

  for r in
    select b.id, b.customer_profile_id, b.barber_id, b.shop_id, b.start_at
    from public.bookings b
    where b.status in ('pending','confirmed')
      and b.start_at >= now_ts
      and b.start_at < (now_ts + interval '2 hours')
  loop
    if not exists (select 1 from public.booking_reminder_log l where l.booking_id = r.id and l.reminder_type = 'customer_2h') then
      perform public.notify(r.customer_profile_id, 'booking_reminder', 'Upcoming booking', 'Your booking starts soon.', jsonb_build_object('booking_id', r.id));
      insert into public.booking_reminder_log (booking_id, reminder_type) values (r.id, 'customer_2h');
      v_count := v_count + 1;
    end if;

    v_provider_profile := null;
    if r.barber_id is not null then
      select br.profile_id into v_provider_profile from public.barbers br where br.id = r.barber_id;
    elsif r.shop_id is not null then
      select s.owner_profile_id into v_provider_profile from public.barbershops s where s.id = r.shop_id;
    end if;

    if v_provider_profile is not null then
      if not exists (select 1 from public.booking_reminder_log l where l.booking_id = r.id and l.reminder_type = 'provider_2h') then
        perform public.notify(v_provider_profile, 'booking_reminder', 'Upcoming booking', 'You have a booking starting soon.', jsonb_build_object('booking_id', r.id));
        insert into public.booking_reminder_log (booking_id, reminder_type) values (r.id, 'provider_2h');
        v_count := v_count + 1;
      end if;
    end if;
  end loop;

  return v_count;
end;
$$;

do $$
begin
  if to_regprocedure('public.send_booking_reminders(timestamptz)') is not null then
    revoke all on function public.send_booking_reminders(timestamptz) from public;
  end if;

  if to_regprocedure('public.send_booking_reminders(timestamptz)') is not null
     and exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.send_booking_reminders(timestamptz) to authenticated;
  end if;
end;
$$;

commit;

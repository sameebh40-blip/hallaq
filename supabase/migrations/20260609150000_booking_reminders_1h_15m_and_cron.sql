begin;

create extension if not exists pg_cron;

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'booking_reminder_log_reminder_type_check'
      and conrelid = 'public.booking_reminder_log'::regclass
  ) then
    alter table public.booking_reminder_log drop constraint booking_reminder_log_reminder_type_check;
  end if;

  alter table public.booking_reminder_log
    add constraint booking_reminder_log_reminder_type_check
    check (
      reminder_type in (
        'customer_2h',
        'provider_2h',
        'customer_1h',
        'provider_1h',
        'customer_15m',
        'provider_15m'
      )
    ) not valid;

  alter table public.booking_reminder_log validate constraint booking_reminder_log_reminder_type_check;
end $$;

create or replace function public.send_booking_reminders(now_ts timestamptz default now())
returns int
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_count int := 0;
  v_provider_profile uuid;
  v_jwt_role text;
  r record;
begin
  v_jwt_role := nullif(current_setting('request.jwt.claim.role', true), '');

  if auth.uid() is null and current_user <> 'postgres' and v_jwt_role is distinct from 'service_role' then
    raise exception using message = 'FORBIDDEN';
  end if;

  for r in
    with windowed as (
      select
        b.id,
        b.customer_profile_id,
        b.barber_id,
        b.shop_id,
        b.start_at,
        case
          when b.start_at >= now_ts + interval '115 minutes' and b.start_at < now_ts + interval '125 minutes' then '2h'
          when b.start_at >= now_ts + interval '55 minutes' and b.start_at < now_ts + interval '65 minutes' then '1h'
          when b.start_at >= now_ts + interval '10 minutes' and b.start_at < now_ts + interval '20 minutes' then '15m'
          else null
        end as reminder_window
      from public.bookings b
      where b.status in ('pending','confirmed','rescheduled')
        and b.start_at >= now_ts
        and b.start_at < now_ts + interval '125 minutes'
    )
    select *
    from windowed
    where reminder_window is not null
  loop
    if not exists (
      select 1
      from public.booking_reminder_log l
      where l.booking_id = r.id
        and l.reminder_type = ('customer_' || r.reminder_window)
    ) then
      perform public.notify(
        r.customer_profile_id,
        'booking_reminder',
        case r.reminder_window
          when '15m' then 'Booking in 15 minutes'
          when '1h' then 'Booking in 1 hour'
          else 'Booking coming up soon'
        end,
        case r.reminder_window
          when '15m' then 'Your booking starts in 15 minutes.'
          when '1h' then 'Your booking starts in 1 hour.'
          else 'Your booking starts in 2 hours.'
        end,
        jsonb_build_object('booking_id', r.id, 'reminder_window', r.reminder_window)
      );

      insert into public.booking_reminder_log (booking_id, reminder_type)
      values (r.id, 'customer_' || r.reminder_window);

      v_count := v_count + 1;
    end if;

    v_provider_profile := null;
    if r.barber_id is not null then
      select br.profile_id into v_provider_profile
      from public.barbers br
      where br.id = r.barber_id;
    elsif r.shop_id is not null then
      select s.owner_profile_id into v_provider_profile
      from public.barbershops s
      where s.id = r.shop_id;
    end if;

    if v_provider_profile is not null
      and not exists (
        select 1
        from public.booking_reminder_log l
        where l.booking_id = r.id
          and l.reminder_type = ('provider_' || r.reminder_window)
      ) then
      perform public.notify(
        v_provider_profile,
        'booking_reminder',
        case r.reminder_window
          when '15m' then 'Client in 15 minutes'
          when '1h' then 'Client in 1 hour'
          else 'Booking coming up soon'
        end,
        case r.reminder_window
          when '15m' then 'You have a booking starting in 15 minutes.'
          when '1h' then 'You have a booking starting in 1 hour.'
          else 'You have a booking starting in 2 hours.'
        end,
        jsonb_build_object('booking_id', r.id, 'reminder_window', r.reminder_window)
      );

      insert into public.booking_reminder_log (booking_id, reminder_type)
      values (r.id, 'provider_' || r.reminder_window);

      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

do $$
declare
  v_job_id int;
begin
  if to_regprocedure('cron.schedule(text, text, text)') is null then
    return;
  end if;

  if to_regclass('cron.job') is null then
    return;
  end if;

  select jobid into v_job_id from cron.job where jobname = 'booking_reminders' limit 1;
  if v_job_id is not null and to_regprocedure('cron.unschedule(integer)') is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'booking_reminders',
    '*/5 * * * *',
    $cmd$select public.send_booking_reminders();$cmd$
  );
end;
$$;

commit;


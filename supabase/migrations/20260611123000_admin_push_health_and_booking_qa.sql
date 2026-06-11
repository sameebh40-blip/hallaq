begin;

create or replace function public.admin_get_push_delivery_health()
returns jsonb
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_pending_total int := 0;
  v_pending_due int := 0;
  v_processing_total int := 0;
  v_sent_total int := 0;
  v_failed_total int := 0;
  v_oldest_pending timestamptz;
  v_oldest_due timestamptz;
  v_push_url text;
  v_push_secret text;
  v_push_worker_job boolean := false;
  v_booking_reminders_job boolean := false;
begin
  if not public.is_admin() then
    raise exception using message = 'FORBIDDEN';
  end if;

  select
    count(*) filter (where q.status = 'pending')::int,
    count(*) filter (where q.status = 'pending' and q.next_attempt_at <= now())::int,
    count(*) filter (where q.status = 'processing')::int,
    count(*) filter (where q.status = 'sent')::int,
    count(*) filter (where q.status = 'failed')::int,
    min(q.created_at) filter (where q.status = 'pending'),
    min(q.created_at) filter (where q.status = 'pending' and q.next_attempt_at <= now())
  into
    v_pending_total,
    v_pending_due,
    v_processing_total,
    v_sent_total,
    v_failed_total,
    v_oldest_pending,
    v_oldest_due
  from public.push_queue q;

  select value into v_push_url from public.app_config where key = 'push_url';
  select value into v_push_secret from public.app_config where key = 'push_secret';

  if to_regclass('cron.job') is not null then
    select exists (select 1 from cron.job where jobname = 'push_worker') into v_push_worker_job;
    select exists (select 1 from cron.job where jobname = 'booking_reminders') into v_booking_reminders_job;
  end if;

  return jsonb_build_object(
    'push_queue',
    jsonb_build_object(
      'pending_total', v_pending_total,
      'pending_due', v_pending_due,
      'processing_total', v_processing_total,
      'sent_total', v_sent_total,
      'failed_total', v_failed_total,
      'oldest_pending_created_at', v_oldest_pending,
      'oldest_due_created_at', v_oldest_due,
      'oldest_pending_minutes', case when v_oldest_pending is null then null else greatest(0, floor(extract(epoch from (now() - v_oldest_pending)) / 60.0)::int) end,
      'oldest_due_minutes', case when v_oldest_due is null then null else greatest(0, floor(extract(epoch from (now() - v_oldest_due)) / 60.0)::int) end
    ),
    'config',
    jsonb_build_object(
      'push_url_set', coalesce(trim(v_push_url), '') <> '',
      'push_secret_set', coalesce(trim(v_push_secret), '') <> ''
    ),
    'cron',
    jsonb_build_object(
      'cron_available', to_regclass('cron.job') is not null,
      'push_worker_job', v_push_worker_job,
      'booking_reminders_job', v_booking_reminders_job
    )
  );
end;
$$;

create or replace function public.admin_booking_qa_report()
returns jsonb
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_cron_available boolean := false;
  v_push jsonb;
begin
  if not public.is_admin() then
    raise exception using message = 'FORBIDDEN';
  end if;

  v_cron_available := to_regclass('cron.job') is not null;
  v_push := public.admin_get_push_delivery_health();

  return jsonb_build_object(
    'tables',
    jsonb_build_object(
      'bookings', to_regclass('public.bookings') is not null,
      'booking_slot_holds', to_regclass('public.booking_slot_holds') is not null,
      'booking_reminder_log', to_regclass('public.booking_reminder_log') is not null,
      'notifications', to_regclass('public.notifications') is not null,
      'push_queue', to_regclass('public.push_queue') is not null,
      'app_config', to_regclass('public.app_config') is not null,
      'device_tokens', to_regclass('public.device_tokens') is not null
    ),
    'rpcs',
    jsonb_build_object(
      'create_booking_safely',
      to_regprocedure('public.create_booking_safely(uuid, timestamptz, uuid, uuid, text, text, uuid, text, uuid, uuid, numeric, uuid)') is not null,
      'hold_booking_slot', to_regprocedure('public.hold_booking_slot(uuid, timestamptz, uuid, uuid, integer)') is not null,
      'get_available_days', to_regprocedure('public.get_available_days(uuid, date, integer, integer)') is not null,
      'get_available_times', to_regprocedure('public.get_available_times(uuid, date, integer, integer)') is not null,
      'cancel_booking', to_regprocedure('public.cancel_booking(uuid, text)') is not null,
      'reschedule_booking', to_regprocedure('public.reschedule_booking(uuid, timestamptz)') is not null,
      'send_booking_reminders', to_regprocedure('public.send_booking_reminders(timestamptz)') is not null,
      'claim_push_queue', to_regprocedure('public.claim_push_queue(integer)') is not null,
      'run_push_worker_http', to_regprocedure('public.run_push_worker_http()') is not null
    ),
    'cron',
    jsonb_build_object(
      'available', v_cron_available
    ),
    'push', v_push
  );
end;
$$;

create or replace function public.bookings_clear_reminders_on_start_change()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  if to_regclass('public.booking_reminder_log') is null then
    return new;
  end if;

  if new.start_at is distinct from old.start_at then
    delete from public.booking_reminder_log l where l.booking_id = new.id;
  end if;

  return new;
end;
$$;

do $$
begin
  if to_regclass('public.bookings') is null then
    return;
  end if;
  if to_regprocedure('public.bookings_clear_reminders_on_start_change()') is null then
    return;
  end if;
  execute 'drop trigger if exists bookings_clear_reminders_on_start_change on public.bookings';
  execute 'create trigger bookings_clear_reminders_on_start_change after update of start_at on public.bookings for each row execute function public.bookings_clear_reminders_on_start_change()';
end;
$$;

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
          when (b.start_at - now_ts) <= interval '15 minutes' and (b.start_at - now_ts) > interval '2 minutes' then '15m'
          when (b.start_at - now_ts) <= interval '1 hour' and (b.start_at - now_ts) > interval '20 minutes' then '1h'
          when (b.start_at - now_ts) <= interval '2 hours' and (b.start_at - now_ts) > interval '1 hour 45 minutes' then '2h'
          else null
        end as reminder_window
      from public.bookings b
      where b.status in ('confirmed', 'rescheduled')
        and b.start_at > now_ts
        and b.start_at <= now_ts + interval '2 hours'
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

commit;

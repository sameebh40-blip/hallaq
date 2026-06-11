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
  v_jwt_role text;
begin
  v_jwt_role := nullif(current_setting('request.jwt.claim.role', true), '');
  if not public.is_admin() and current_user <> 'postgres' and v_jwt_role is distinct from 'service_role' then
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
  v_jwt_role text;
begin
  v_jwt_role := nullif(current_setting('request.jwt.claim.role', true), '');
  if not public.is_admin() and current_user <> 'postgres' and v_jwt_role is distinct from 'service_role' then
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

commit;


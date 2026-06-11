begin;

create extension if not exists pg_cron;

create or replace function public.cleanup_expired_booking_slot_holds()
returns int
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_count int;
begin
  delete from public.booking_slot_holds h
  where h.consumed_at is null
    and h.expires_at <= now();
  get diagnostics v_count = row_count;
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

  select jobid into v_job_id from cron.job where jobname = 'cleanup_booking_slot_holds' limit 1;
  if v_job_id is not null and to_regprocedure('cron.unschedule(integer)') is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'cleanup_booking_slot_holds',
    '*/5 * * * *',
    $cmd$select public.cleanup_expired_booking_slot_holds();$cmd$
  );
end;
$$;

commit;

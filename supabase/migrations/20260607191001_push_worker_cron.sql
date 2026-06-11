begin;

do $$
begin
  begin
    create extension if not exists pg_cron;
  exception when others then
    null;
  end;
end;
$$;

create or replace function public.run_push_worker_http()
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_url text;
  v_secret text;
  v_headers jsonb;
begin
  select value into v_url from public.app_config where key = 'push_url';
  select value into v_secret from public.app_config where key = 'push_secret';

  v_url := coalesce(trim(v_url), '');
  v_secret := coalesce(trim(v_secret), '');

  if v_url = '' then
    return;
  end if;

  if to_regproc('net.http_post') is null then
    return;
  end if;

  v_headers := jsonb_build_object(
    'content-type', 'application/json',
    'x-hallaq-secret', v_secret
  );

  execute 'select net.http_post(url := $1, headers := $2, body := $3)'
  using v_url, v_headers, '{}'::jsonb;
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

  select jobid into v_job_id from cron.job where jobname = 'push_worker' limit 1;
  if v_job_id is not null and to_regprocedure('cron.unschedule(integer)') is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'push_worker',
    '* * * * *',
    $cmd$select public.run_push_worker_http();$cmd$
  );
end;
$$;

commit;

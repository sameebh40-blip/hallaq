begin;

create or replace function public.notify(
  profile uuid,
  ntype text,
  title text,
  body text,
  payload jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  if pg_trigger_depth() = 0 then
    raise exception using message = 'FORBIDDEN';
  end if;

  insert into public.notifications (profile_id, type, title, body, data)
  values (profile, ntype, title, body, payload);
end;
$$;

commit;

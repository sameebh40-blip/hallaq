begin;

do $$
declare r record;
begin
  for r in
    select n.nspname as schema_name,
           p.proname as func_name,
           pg_get_function_identity_arguments(p.oid) as identity_args
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
      and p.proconfig is null
      and pg_get_userbyid(p.proowner) = current_user
  loop
    execute format('alter function %I.%I(%s) set search_path = public;', r.schema_name, r.func_name, r.identity_args);
  end loop;
end;
$$;

commit;


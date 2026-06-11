begin;

do $$
declare r record;
begin
  for r in
    select n.nspname as schema_name, c.relname as view_name
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'v'
      and pg_get_userbyid(c.relowner) = current_user
  loop
    execute format('alter view %I.%I set (security_invoker=true);', r.schema_name, r.view_name);
  end loop;
end;
$$;

alter function public.search_barbers(double precision, double precision, text, integer, integer) set search_path = public;
alter function public.search_barbers(double precision, double precision, text, integer, integer, boolean, boolean, boolean, boolean, text) set search_path = public;
alter function public.search_shops(double precision, double precision, text, integer, integer) set search_path = public;
alter function public.search_shops(double precision, double precision, text, integer, integer, boolean, boolean, boolean, boolean, text) set search_path = public;
alter function public.search_home_service_shops(double precision, double precision, integer, integer) set search_path = public;

commit;

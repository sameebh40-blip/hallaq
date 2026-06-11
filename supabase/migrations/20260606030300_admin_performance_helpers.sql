begin;

create or replace function public.admin_list_table_sizes(p_limit int default 30)
returns table (
  table_name text,
  size_bytes bigint,
  row_estimate bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;

  return query
  select
    c.relname::text as table_name,
    pg_total_relation_size(c.oid)::bigint as size_bytes,
    c.reltuples::bigint as row_estimate
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind = 'r'
  order by pg_total_relation_size(c.oid) desc
  limit greatest(1, least(p_limit, 200));
end;
$$;

do $$
begin
  if to_regprocedure('public.admin_list_table_sizes(int)') is not null then
    revoke all on function public.admin_list_table_sizes(int) from public;
  end if;
end;
$$;

commit;

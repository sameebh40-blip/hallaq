begin;

do $$
declare
  r record;
begin
  if to_regclass('public.customer_membership') is null then
    return;
  end if;

  if to_regclass('public.profiles') is null then
    return;
  end if;

  for r in select id from public.profiles loop
    perform public.recompute_customer_membership(r.id);
  end loop;
end;
$$;

commit;


begin;

create or replace function public.compute_membership_tier(points int)
returns text
language plpgsql
immutable
as $$
begin
  if points >= 700 then
    return 'Platinum';
  elsif points >= 300 then
    return 'Gold';
  else
    return 'Silver';
  end if;
end;
$$;

do $$
declare
  r record;
begin
  for r in (select id from public.profiles) loop
    perform public.recompute_customer_membership(r.id);
  end loop;
end;
$$;

commit;


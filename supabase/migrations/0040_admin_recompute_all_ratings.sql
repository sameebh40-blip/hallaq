begin;

create or replace function public.recompute_all_ratings()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  rec record;
begin
  if not public.is_admin() then
    raise exception using message = 'FORBIDDEN';
  end if;

  for rec in
    select distinct target_type, target_id
    from public.reviews
    where status = 'published'
      and is_verified = true
  loop
    perform public.recompute_target_rating(rec.target_type, rec.target_id);
  end loop;
end;
$$;

do $$
begin
  if to_regprocedure('public.recompute_all_ratings()') is not null then
    revoke all on function public.recompute_all_ratings() from public;
  end if;

  if to_regprocedure('public.recompute_all_ratings()') is not null
     and exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.recompute_all_ratings() to authenticated;
  end if;
end;
$$;

commit;

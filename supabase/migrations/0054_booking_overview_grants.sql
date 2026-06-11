begin;

do $$
begin
  if to_regclass('public.booking_overview') is not null then
    execute 'grant select on public.booking_overview to authenticated';
  end if;
end;
$$;

commit;

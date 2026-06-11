begin;

alter table public.payments replica identity full;
do $$
begin
  alter publication supabase_realtime add table public.payments;
exception
  when duplicate_object then null;
  when undefined_object then null;
end;
$$;

commit;


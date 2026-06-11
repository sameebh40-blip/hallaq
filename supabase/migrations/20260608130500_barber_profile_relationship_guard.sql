begin;

create or replace function public.enforce_barber_profile_relationship()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' or new.profile_id is distinct from old.profile_id then
    if exists (select 1 from public.barbershops s where s.owner_profile_id = new.profile_id) then
      raise exception 'barber_cannot_own_shop';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists barbers_profile_relationship_guard on public.barbers;
create trigger barbers_profile_relationship_guard
before insert or update of profile_id on public.barbers
for each row execute function public.enforce_barber_profile_relationship();

commit;

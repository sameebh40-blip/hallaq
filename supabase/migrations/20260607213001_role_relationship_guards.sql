begin;

create or replace function public.prevent_profile_role_change()
returns trigger
language plpgsql
as $$
declare
  jwt_role text := current_setting('request.jwt.claim.role', true);
begin
  if new.role is distinct from old.role then
    if new.role = 'shop_owner' then
      if exists (select 1 from public.barbers b where b.profile_id = new.id) then
        raise exception 'role_conflict_barber';
      end if;
    end if;

    if new.role = 'barber' then
      if exists (select 1 from public.barbershops s where s.owner_profile_id = new.id) then
        raise exception 'role_conflict_shop_owner';
      end if;
    end if;

    if jwt_role = 'service_role' then
      return new;
    end if;
    if not public.is_admin() then
      raise exception 'role_change_not_allowed';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.enforce_barbershop_owner_relationship()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' or new.owner_profile_id is distinct from old.owner_profile_id then
    if exists (select 1 from public.barbers b where b.profile_id = new.owner_profile_id) then
      raise exception 'owner_cannot_be_barber';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists barbershops_owner_relationship_guard on public.barbershops;
create trigger barbershops_owner_relationship_guard
before insert or update of owner_profile_id on public.barbershops
for each row execute function public.enforce_barbershop_owner_relationship();

commit;

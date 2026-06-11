begin;

create or replace function public.prevent_profile_role_change()
returns trigger
language plpgsql
as $$
declare
  jwt_role text := current_setting('request.jwt.claim.role', true);
begin
  if new.role is distinct from old.role then
    if jwt_role = 'service_role' then
      return new;
    end if;

    if old.role is null and new.role = 'customer' and old.id = auth.uid() then
      return new;
    end if;

    if not public.is_admin() then
      raise exception 'role_change_not_allowed';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_prevent_role_change on public.profiles;
create trigger profiles_prevent_role_change
before update on public.profiles
for each row execute function public.prevent_profile_role_change();

commit;

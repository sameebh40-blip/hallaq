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
    if not public.is_admin() then
      raise exception 'role_change_not_allowed';
    end if;
  end if;
  return new;
end;
$$;

commit;


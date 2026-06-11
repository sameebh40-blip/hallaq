begin;

create or replace function public.sync_profile_role_from_entities(p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_role text;
  target_role text;
begin
  if p_profile_id is null then
    return;
  end if;

  select role
  into current_role
  from public.profiles
  where id = p_profile_id;

  if current_role is null or current_role = 'admin' then
    return;
  end if;

  if exists (select 1 from public.barbershops s where s.owner_profile_id = p_profile_id) then
    target_role := 'shop_owner';
  elsif exists (select 1 from public.barbers b where b.profile_id = p_profile_id) then
    target_role := 'barber';
  else
    target_role := 'customer';
  end if;

  if target_role is distinct from current_role then
    perform set_config('request.jwt.claim.role', 'service_role', true);
    update public.profiles
    set role = target_role
    where id = p_profile_id;
  end if;
end;
$$;

select set_config('request.jwt.claim.role', 'service_role', true);

update public.profiles p
set role = case
  when exists (select 1 from public.barbershops s where s.owner_profile_id = p.id) then 'shop_owner'
  when exists (select 1 from public.barbers b where b.profile_id = p.id) then 'barber'
  else 'customer'
end
where p.role <> 'admin'
  and p.role is distinct from case
    when exists (select 1 from public.barbershops s where s.owner_profile_id = p.id) then 'shop_owner'
    when exists (select 1 from public.barbers b where b.profile_id = p.id) then 'barber'
    else 'customer'
  end;

commit;

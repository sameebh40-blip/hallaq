begin;

do $$
declare
  a uuid;
  b uuid;
  sh uuid;
  br uuid;
  c int;
  err text;
begin
  select p.id into a
  from public.profiles p
  where p.role <> 'admin'
    and not exists (select 1 from public.barbers b where b.profile_id = p.id)
  order by p.created_at asc
  limit 1;

  select p.id into b
  from public.profiles p
  where p.role <> 'admin'
    and p.id <> a
    and not exists (select 1 from public.barbershops s where s.owner_profile_id = p.id)
  order by p.created_at asc
  limit 1;
  if a is null then
    raise exception 'Need at least 1 non-admin profile without barber row to run role relationship test.';
  end if;
  if b is null then
    b := a;
  end if;

  perform set_config('request.jwt.claim.role', 'service_role', true);

  update public.profiles set role = 'shop_owner' where id = a;
  update public.profiles set role = 'barber' where id = b;

  insert into public.barbershops (owner_profile_id, name)
  values (a, 'Role Relationship Shop')
  returning id into sh;

  insert into public.barbers (profile_id, shop_id, display_name, is_independent)
  values (b, sh, 'Role Relationship Barber', false)
  on conflict (profile_id) do update
    set shop_id = excluded.shop_id, is_independent = excluded.is_independent
  returning id into br;

  select count(*) into c from public.profiles p where p.id = b and p.role = 'barber';
  if c <> 1 then raise exception 'Expected barber role to remain barber after shop assignment.'; end if;

  begin
    update public.barbershops set owner_profile_id = b where id = sh;
    raise exception 'Expected owner_cannot_be_barber';
  exception when others then
    err := lower(sqlerrm);
    if position('owner_cannot_be_barber' in err) = 0 then
      raise;
    end if;
  end;

  begin
    update public.profiles set role = 'shop_owner' where id = b;
    raise exception 'Expected role_conflict_barber';
  exception when others then
    err := lower(sqlerrm);
    if position('role_conflict_barber' in err) = 0 then
      raise;
    end if;
  end;
end;
$$;

rollback;

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
  select role into current_role from public.profiles where id = p_profile_id;
  if current_role is null then
    return;
  end if;

  if current_role = 'admin' then
    return;
  end if;

  if exists (
    select 1
    from public.barbershops s
    where s.owner_profile_id = p_profile_id
      and s.deleted_at is null
      and s.is_active = true
      and s.status = 'approved'
  ) then
    target_role := 'shop_owner';
  elsif exists (
    select 1
    from public.barbers b
    where b.profile_id = p_profile_id
      and b.deleted_at is null
      and b.is_active = true
      and b.status = 'approved'
  ) then
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

drop policy if exists "barbers_write_owner" on public.barbers;

drop policy if exists "barbers_update_self" on public.barbers;
create policy "barbers_update_self"
on public.barbers
for update
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

drop policy if exists "barbers_insert_shop_owner" on public.barbers;
create policy "barbers_insert_shop_owner"
on public.barbers
for insert
to authenticated
with check (
  public.is_admin()
  or (shop_id is not null and public.is_shop_owner(shop_id))
);

select set_config('request.jwt.claim.role', 'service_role', true);

update public.profiles p
set role = 'customer'
where p.role = 'barber'
  and not exists (
    select 1
    from public.barbers b
    where b.profile_id = p.id
      and b.deleted_at is null
      and b.is_active = true
      and b.status = 'approved'
  );

update public.profiles p
set role = 'customer'
where p.role = 'shop_owner'
  and not exists (
    select 1
    from public.barbershops s
    where s.owner_profile_id = p.id
      and s.deleted_at is null
      and s.is_active = true
      and s.status = 'approved'
  );

commit;

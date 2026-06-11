begin;

do $$
begin
  if exists (select 1 from pg_proc where proname = 'handle_new_user' and pronamespace = 'public'::regnamespace) then
    if not exists (select 1 from pg_trigger where tgname = 'on_auth_user_created') then
      create trigger on_auth_user_created
      after insert on auth.users
      for each row
      execute function public.handle_new_user();
    end if;
  end if;
end;
$$;

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
  if current_role is null then return; end if;
  if current_role <> 'customer' then return; end if;

  if exists (select 1 from public.barbershops s where s.owner_profile_id = p_profile_id) then
    target_role := 'shop_owner';
  elsif exists (select 1 from public.barbers b where b.profile_id = p_profile_id) then
    target_role := 'barber';
  else
    target_role := 'customer';
  end if;

  if target_role is distinct from current_role then
    update public.profiles set role = target_role where id = p_profile_id and role = 'customer';
  end if;
end;
$$;

create or replace function public.sync_profile_role_from_barbers()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.sync_profile_role_from_entities(coalesce(new.profile_id, old.profile_id));
  return coalesce(new, old);
end;
$$;

drop trigger if exists barbers_sync_profile_role on public.barbers;
create trigger barbers_sync_profile_role
after insert or update of profile_id or delete on public.barbers
for each row execute function public.sync_profile_role_from_barbers();

create or replace function public.sync_profile_role_from_shops()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.sync_profile_role_from_entities(coalesce(new.owner_profile_id, old.owner_profile_id));
  return coalesce(new, old);
end;
$$;

drop trigger if exists barbershops_sync_profile_role on public.barbershops;
create trigger barbershops_sync_profile_role
after insert or update of owner_profile_id or delete on public.barbershops
for each row execute function public.sync_profile_role_from_shops();

select set_config('request.jwt.claim.role', 'service_role', true);

update public.profiles p
set role = 'shop_owner'
where p.role = 'customer'
  and exists (select 1 from public.barbershops s where s.owner_profile_id = p.id);

update public.profiles p
set role = 'barber'
where p.role = 'customer'
  and exists (select 1 from public.barbers b where b.profile_id = p.id)
  and not exists (select 1 from public.barbershops s where s.owner_profile_id = p.id);

do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values
      ('review-images', 'review-images', true),
      ('product-images', 'product-images', true)
    on conflict (id) do nothing;
  end if;
end;
$$;

commit;

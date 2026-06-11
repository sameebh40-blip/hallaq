do $$
begin
  alter table public.barbers alter column status set default 'pending';
exception
  when undefined_column then null;
end $$;

do $$
begin
  alter table public.barbers alter column is_active set default false;
exception
  when undefined_column then null;
end $$;

do $$
begin
  alter table public.barbershops alter column status set default 'pending';
exception
  when undefined_column then null;
end $$;

do $$
begin
  alter table public.barbershops alter column is_active set default false;
exception
  when undefined_column then null;
end $$;

create or replace function public.set_barber_status_on_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  jwt_role text;
begin
  jwt_role := current_setting('request.jwt.claim.role', true);
  if jwt_role = 'service_role' or public.is_admin() then
    return new;
  end if;
  new.status := 'pending';
  new.is_active := false;
  return new;
end;
$$;

drop trigger if exists barbers_set_status_on_insert on public.barbers;
create trigger barbers_set_status_on_insert
before insert on public.barbers
for each row
execute function public.set_barber_status_on_insert();

create or replace function public.set_barbershop_status_on_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  jwt_role text;
begin
  jwt_role := current_setting('request.jwt.claim.role', true);
  if jwt_role = 'service_role' or public.is_admin() then
    return new;
  end if;
  new.status := 'pending';
  new.is_active := false;
  return new;
end;
$$;

drop trigger if exists barbershops_set_status_on_insert on public.barbershops;
create trigger barbershops_set_status_on_insert
before insert on public.barbershops
for each row
execute function public.set_barbershop_status_on_insert();

drop policy if exists "barbershops_write_owner" on public.barbershops;
drop policy if exists "shops_write_owner" on public.barbershops;

drop policy if exists "shops_insert_admin_only" on public.barbershops;
create policy "shops_insert_admin_only"
on public.barbershops
for insert
to authenticated
with check (public.is_admin());


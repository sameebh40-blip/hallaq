begin;

create or replace function public.prevent_barber_self_shop_assignment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if new.profile_id = auth.uid() then
    if new.shop_id is distinct from old.shop_id then
      raise exception 'not_allowed';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.prevent_barber_self_shop_assignment_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if new.profile_id = auth.uid() and new.shop_id is not null then
    raise exception 'not_allowed';
  end if;

  return new;
end;
$$;

drop trigger if exists barbers_prevent_self_shop_assignment on public.barbers;
create trigger barbers_prevent_self_shop_assignment
before update on public.barbers
for each row
execute function public.prevent_barber_self_shop_assignment();

drop trigger if exists barbers_prevent_self_shop_assignment_insert on public.barbers;
create trigger barbers_prevent_self_shop_assignment_insert
before insert on public.barbers
for each row
execute function public.prevent_barber_self_shop_assignment_insert();

commit;


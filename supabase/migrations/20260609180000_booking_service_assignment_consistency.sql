begin;

do $$
declare
  v_has_service_barbers boolean := to_regclass('public.service_barbers') is not null;
  v_select_list text;
  v_mapping_predicate text := '';
  r record;
begin
  if v_has_service_barbers then
    delete from public.service_barbers sb
    where exists (
      select 1
      from public.services s
      join public.barbers b on b.id = sb.barber_id
      where s.id = sb.service_id
        and s.shop_id is not null
        and b.shop_id is distinct from s.shop_id
    );
  end if;

  if v_has_service_barbers then
    v_mapping_predicate := $pred$
      and (
        not exists (select 1 from public.service_barbers sb where sb.service_id = s.id)
        or exists (select 1 from public.service_barbers sb where sb.service_id = s.id and sb.barber_id = b.id)
      )
    $pred$;
  end if;

  if to_regclass('public.barber_services_effective') is not null then
    select string_agg(
      case
        when c.column_name = 'barber_ref' then 'b.id as barber_ref'
        else format('s.%I', c.column_name)
      end,
      E',\n        '
      order by c.ordinal_position
    )
    into v_select_list
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'barber_services_effective';

    for r in
      select c.column_name
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'services'
        and not exists (
          select 1
          from information_schema.columns v
          where v.table_schema = 'public'
            and v.table_name = 'barber_services_effective'
            and v.column_name = c.column_name
        )
      order by c.ordinal_position
    loop
      v_select_list := v_select_list || format(E',\n        s.%I', r.column_name);
    end loop;
  else
    select string_agg(format('s.%I', c.column_name), E',\n        ' order by c.ordinal_position)
    into v_select_list
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'services';

    v_select_list := v_select_list || E',\n        b.id as barber_ref';
  end if;

  execute format(
    $view$
      create or replace view public.barber_services_effective with (security_invoker = true) as
      select
        %1$s
      from public.services s
      join public.barbers b on b.id = s.barber_id
      where s.is_active = true
        and s.deleted_at is null
        and s.status = 'approved'
      union all
      select
        %1$s
      from public.services s
      join public.barbers b on b.shop_id = s.shop_id
      where s.barber_id is null
        and s.shop_id is not null
        and s.is_active = true
        and s.deleted_at is null
        and s.status = 'approved'
        %2$s
    $view$,
    v_select_list,
    v_mapping_predicate
  );
end
$$;

create or replace function public.service_allows_barber(
  p_service_id uuid,
  p_barber_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_service record;
  v_barber_shop_id uuid;
begin
  if p_service_id is null or p_barber_id is null then
    return false;
  end if;

  select s.id, s.shop_id, s.barber_id, s.deleted_at, s.is_active, s.status
  into v_service
  from public.services s
  where s.id = p_service_id
  limit 1;

  if v_service.id is null then
    return false;
  end if;

  if v_service.deleted_at is not null or v_service.is_active is not true or v_service.status <> 'approved' then
    return false;
  end if;

  if v_service.barber_id is not null then
    return v_service.barber_id = p_barber_id;
  end if;

  if v_service.shop_id is null then
    return false;
  end if;

  select b.shop_id
  into v_barber_shop_id
  from public.barbers b
  where b.id = p_barber_id
  limit 1;

  if v_barber_shop_id is distinct from v_service.shop_id then
    return false;
  end if;

  if to_regclass('public.service_barbers') is not null
     and exists (
       select 1
       from public.service_barbers sb
       where sb.service_id = p_service_id
     ) then
    return exists (
      select 1
      from public.service_barbers sb
      where sb.service_id = p_service_id
        and sb.barber_id = p_barber_id
    );
  end if;

  return true;
end;
$$;

create or replace function public.validate_service_booking_assignment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_service record;
  v_barber record;
begin
  if new.service_id is null or new.barber_id is null then
    return new;
  end if;

  select s.id, s.shop_id, s.barber_id
  into v_service
  from public.services s
  where s.id = new.service_id
  limit 1;

  if v_service.id is null then
    raise exception using message = 'SERVICE_NOT_FOUND';
  end if;

  select b.id, b.shop_id
  into v_barber
  from public.barbers b
  where b.id = new.barber_id
  limit 1;

  if v_barber.id is null then
    raise exception using message = 'INVALID_BARBER';
  end if;

  if v_service.shop_id is not null and new.shop_id is not null and new.shop_id <> v_service.shop_id then
    raise exception using message = 'SERVICE_NOT_FOR_SHOP';
  end if;

  if v_service.shop_id is not null and v_barber.shop_id is distinct from v_service.shop_id then
    raise exception using message = 'BARBER_NOT_IN_SHOP';
  end if;

  if not public.service_allows_barber(new.service_id, new.barber_id) then
    raise exception using message = 'SERVICE_NOT_FOR_BARBER';
  end if;

  return new;
end;
$$;

drop trigger if exists booking_slot_holds_validate_service_assignment on public.booking_slot_holds;
create trigger booking_slot_holds_validate_service_assignment
before insert or update of service_id, barber_id, shop_id on public.booking_slot_holds
for each row execute function public.validate_service_booking_assignment();

drop trigger if exists bookings_validate_service_assignment on public.bookings;
create trigger bookings_validate_service_assignment
before insert or update of service_id, barber_id, shop_id on public.bookings
for each row execute function public.validate_service_booking_assignment();

commit;

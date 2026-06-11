begin;

create or replace function public.get_shop_qr_scans_daily(p_shop_id uuid, p_from date default null, p_to date default null)
returns table(day date, scans int, unique_sessions int)
language plpgsql
stable
security definer
set search_path = public
set row_security = off
as $$
begin
  if not (public.is_admin() or public.is_shop_owner(p_shop_id)) then
    raise exception 'Not allowed';
  end if;

  return query
  select
    date_trunc('day', ae.created_at)::date as day,
    count(*)::int as scans,
    count(distinct coalesce(nullif(ae.session_id, ''), ae.id::text))::int as unique_sessions
  from public.analytics_events ae
  where ae.event_name = 'qr_scan'
    and (
      (ae.entity_type = 'shop' and ae.entity_id = p_shop_id)
      or (
        ae.entity_type = 'barber'
        and exists (
          select 1
          from public.barbers b
          where b.id = ae.entity_id and b.shop_id = p_shop_id
        )
      )
    )
    and (p_from is null or ae.created_at >= p_from::timestamptz)
    and (p_to is null or ae.created_at < (p_to + 1)::timestamptz)
  group by 1
  order by 1;
end;
$$;

create or replace function public.get_shop_qr_scans_by_barber(p_shop_id uuid, p_from date default null, p_to date default null)
returns table(barber_id uuid, scans int)
language plpgsql
stable
security definer
set search_path = public
set row_security = off
as $$
begin
  if not (public.is_admin() or public.is_shop_owner(p_shop_id)) then
    raise exception 'Not allowed';
  end if;

  return query
  select
    ae.entity_id as barber_id,
    count(*)::int as scans
  from public.analytics_events ae
  where ae.event_name = 'qr_scan'
    and ae.entity_type = 'barber'
    and exists (select 1 from public.barbers b where b.id = ae.entity_id and b.shop_id = p_shop_id)
    and (p_from is null or ae.created_at >= p_from::timestamptz)
    and (p_to is null or ae.created_at < (p_to + 1)::timestamptz)
  group by 1
  order by 2 desc;
end;
$$;

grant execute on function public.get_shop_qr_scans_daily(uuid, date, date) to authenticated;
grant execute on function public.get_shop_qr_scans_by_barber(uuid, date, date) to authenticated;

commit;


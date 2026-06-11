begin;

create or replace function public.sync_profile_role_from_barbers()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.sync_profile_role_from_entities(new.profile_id);
  elsif tg_op = 'DELETE' then
    perform public.sync_profile_role_from_entities(old.profile_id);
  else
    if old.profile_id is distinct from new.profile_id then
      perform public.sync_profile_role_from_entities(old.profile_id);
    end if;
    perform public.sync_profile_role_from_entities(new.profile_id);
  end if;

  return coalesce(new, old);
end;
$$;

create or replace function public.sync_profile_role_from_shops()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.sync_profile_role_from_entities(new.owner_profile_id);
  elsif tg_op = 'DELETE' then
    perform public.sync_profile_role_from_entities(old.owner_profile_id);
  else
    if old.owner_profile_id is distinct from new.owner_profile_id then
      perform public.sync_profile_role_from_entities(old.owner_profile_id);
    end if;
    perform public.sync_profile_role_from_entities(new.owner_profile_id);
  end if;

  return coalesce(new, old);
end;
$$;

create or replace function public.approve_shop_claim_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop_id uuid;
  v_requester uuid;
begin
  if not public.is_admin() then
    raise exception 'not_allowed';
  end if;

  select r.shop_id, r.requester_profile_id
  into v_shop_id, v_requester
  from public.shop_claim_requests r
  where r.id = p_request_id
  for update;

  if v_shop_id is null or v_requester is null then
    raise exception 'not_found';
  end if;

  if exists (select 1 from public.barbers b where b.profile_id = v_requester) then
    raise exception 'requester_cannot_be_barber';
  end if;

  update public.shop_claim_requests
  set status = 'approved',
      decided_by_profile_id = auth.uid(),
      decided_at = now()
  where id = p_request_id
    and status = 'pending';

  update public.barbershops
  set owner_profile_id = v_requester
  where id = v_shop_id;

  perform public.sync_profile_role_from_entities(v_requester);

  insert into public.notifications (profile_id, type, title, body, data)
  values (
    v_requester,
    'claim_approved',
    'Shop claim approved',
    'Your shop claim has been approved.',
    jsonb_build_object('shop_id', v_shop_id, 'request_id', p_request_id)
  );
end;
$$;

commit;

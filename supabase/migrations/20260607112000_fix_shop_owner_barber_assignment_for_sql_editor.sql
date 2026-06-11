begin;

create or replace function public.enforce_shop_owner_barber_assignment()
returns trigger
language plpgsql
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if auth.uid() is null then
    return new;
  end if;

  if old.profile_id = auth.uid() then
    return new;
  end if;

  if not public.is_shop_owner(coalesce(old.shop_id, new.shop_id)) then
    raise exception 'Not allowed';
  end if;

  if new.profile_id is distinct from old.profile_id then raise exception 'Not allowed'; end if;

  if new.shop_id is distinct from old.shop_id then
    if old.shop_id is null then
      if not public.is_shop_owner(new.shop_id) then raise exception 'Not allowed'; end if;
    elsif new.shop_id is null then
      if not public.is_shop_owner(old.shop_id) then raise exception 'Not allowed'; end if;
    else
      raise exception 'Not allowed';
    end if;
  end if;

  if new.slug is distinct from old.slug then raise exception 'Not allowed'; end if;

  if new.is_verified is distinct from old.is_verified then raise exception 'Not allowed'; end if;
  if new.is_hallaq_certified is distinct from old.is_hallaq_certified then raise exception 'Not allowed'; end if;
  if new.rating_avg is distinct from old.rating_avg then raise exception 'Not allowed'; end if;
  if new.rating_count is distinct from old.rating_count then raise exception 'Not allowed'; end if;
  if new.followers_count is distinct from old.followers_count then raise exception 'Not allowed'; end if;
  if new.reviews_count is distinct from old.reviews_count then raise exception 'Not allowed'; end if;
  if new.badge_verified is distinct from old.badge_verified then raise exception 'Not allowed'; end if;
  if new.badge_elite is distinct from old.badge_elite then raise exception 'Not allowed'; end if;
  if new.badge_trending is distinct from old.badge_trending then raise exception 'Not allowed'; end if;
  if new.badge_top_rated is distinct from old.badge_top_rated then raise exception 'Not allowed'; end if;
  if new.badge_certified is distinct from old.badge_certified then raise exception 'Not allowed'; end if;
  if new.deleted_at is distinct from old.deleted_at then raise exception 'Not allowed'; end if;
  if new.status is distinct from old.status then raise exception 'Not allowed'; end if;

  return new;
end;
$$;

commit;


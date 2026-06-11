begin;

create or replace function public.enforce_shop_owner_barber_assignment()
returns trigger
language plpgsql
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if old.profile_id = auth.uid() then
    return new;
  end if;

  if not public.is_shop_owner(coalesce(new.shop_id, old.shop_id)) then
    raise exception 'Not allowed';
  end if;

  if new.profile_id is distinct from old.profile_id then raise exception 'Not allowed'; end if;
  if new.slug is distinct from old.slug then raise exception 'Not allowed'; end if;
  if new.display_name is distinct from old.display_name then raise exception 'Not allowed'; end if;
  if new.avatar_url is distinct from old.avatar_url then raise exception 'Not allowed'; end if;
  if new.cover_url is distinct from old.cover_url then raise exception 'Not allowed'; end if;
  if new.bio is distinct from old.bio then raise exception 'Not allowed'; end if;
  if new.specialty is distinct from old.specialty then raise exception 'Not allowed'; end if;
  if new.area is distinct from old.area then raise exception 'Not allowed'; end if;
  if new.address is distinct from old.address then raise exception 'Not allowed'; end if;
  if new.lat is distinct from old.lat then raise exception 'Not allowed'; end if;
  if new.lng is distinct from old.lng then raise exception 'Not allowed'; end if;
  if new.is_verified is distinct from old.is_verified then raise exception 'Not allowed'; end if;
  if new.is_hallaq_certified is distinct from old.is_hallaq_certified then raise exception 'Not allowed'; end if;
  if new.rating_avg is distinct from old.rating_avg then raise exception 'Not allowed'; end if;
  if new.rating_count is distinct from old.rating_count then raise exception 'Not allowed'; end if;
  if new.followers_count is distinct from old.followers_count then raise exception 'Not allowed'; end if;
  if new.reviews_count is distinct from old.reviews_count then raise exception 'Not allowed'; end if;
  if new.available_now is distinct from old.available_now then raise exception 'Not allowed'; end if;
  if new.waiting_time_min is distinct from old.waiting_time_min then raise exception 'Not allowed'; end if;
  if new.queue_length is distinct from old.queue_length then raise exception 'Not allowed'; end if;
  if new.badge_verified is distinct from old.badge_verified then raise exception 'Not allowed'; end if;
  if new.badge_elite is distinct from old.badge_elite then raise exception 'Not allowed'; end if;
  if new.badge_trending is distinct from old.badge_trending then raise exception 'Not allowed'; end if;
  if new.badge_top_rated is distinct from old.badge_top_rated then raise exception 'Not allowed'; end if;
  if new.badge_certified is distinct from old.badge_certified then raise exception 'Not allowed'; end if;
  if new.deleted_at is distinct from old.deleted_at then raise exception 'Not allowed'; end if;

  return new;
end;
$$;

drop trigger if exists barbers_shop_owner_assignment_guard on public.barbers;
create trigger barbers_shop_owner_assignment_guard
before update on public.barbers
for each row
execute function public.enforce_shop_owner_barber_assignment();

drop policy if exists "barbers_shop_owner_assign" on public.barbers;
create policy "barbers_shop_owner_assign"
on public.barbers
for update
to authenticated
using (
  shop_id is null
  or public.is_shop_owner(shop_id)
  or public.is_admin()
)
with check (
  (shop_id is null or public.is_shop_owner(shop_id) or public.is_admin())
);

commit;

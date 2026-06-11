begin;

alter table public.reviews add column if not exists is_verified boolean not null default false;
alter table public.reviews add column if not exists verified_at timestamptz;
alter table public.reviews add column if not exists reply_text text;
alter table public.reviews add column if not exists replied_at timestamptz;
alter table public.reviews add column if not exists replied_by_profile_id uuid references public.profiles (id) on delete set null;

create or replace function public.set_review_verification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  ok boolean := false;
begin
  if new.booking_id is null then
    new.is_verified := false;
    new.verified_at := null;
    return new;
  end if;

  select true into ok
  from public.bookings b
  where b.id = new.booking_id
    and b.customer_profile_id = new.customer_profile_id
    and (
      (new.target_type = 'barber' and b.barber_id = new.target_id::uuid)
      or (new.target_type = 'shop' and b.shop_id = new.target_id::uuid)
    )
    and b.status in ('confirmed','completed')
  limit 1;

  if coalesce(ok, false) then
    new.is_verified := true;
    if new.verified_at is null then
      new.verified_at := now();
    end if;
  else
    new.is_verified := false;
    new.verified_at := null;
  end if;

  return new;
end;
$$;

drop trigger if exists reviews_set_verification on public.reviews;
create trigger reviews_set_verification
before insert or update of booking_id, customer_profile_id, target_type, target_id
on public.reviews
for each row execute function public.set_review_verification();

create or replace function public.reviews_guard_updates()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if (
    new.customer_profile_id is distinct from old.customer_profile_id
    or new.customer_id is distinct from old.customer_id
    or new.target_type is distinct from old.target_type
    or new.target_id is distinct from old.target_id
    or new.barber_id is distinct from old.barber_id
    or new.shop_id is distinct from old.shop_id
    or new.rating is distinct from old.rating
    or new.comment is distinct from old.comment
    or new.text is distinct from old.text
    or new.image_url is distinct from old.image_url
    or new.photo_url is distinct from old.photo_url
    or new.booking_id is distinct from old.booking_id
    or new.status is distinct from old.status
  ) then
    raise exception 'Not allowed';
  end if;

  if new.reply_text is distinct from old.reply_text then
    if new.reply_text is null or length(trim(new.reply_text)) = 0 then
      new.reply_text := null;
      new.replied_at := null;
      new.replied_by_profile_id := null;
    else
      new.replied_at := now();
      if new.replied_by_profile_id is null then
        new.replied_by_profile_id := auth.uid();
      end if;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists reviews_guard_updates on public.reviews;
create trigger reviews_guard_updates
before update on public.reviews
for each row execute function public.reviews_guard_updates();

drop policy if exists "reviews_insert_verified" on public.reviews;
create policy "reviews_insert_verified"
on public.reviews
for insert
to authenticated
with check (
  customer_profile_id = auth.uid()
  and booking_id is not null
  and exists (
    select 1
    from public.bookings b
    where b.id = booking_id
      and b.customer_profile_id = auth.uid()
      and (
        (target_type = 'barber' and b.barber_id = target_id::uuid)
        or (target_type = 'shop' and b.shop_id = target_id::uuid)
      )
      and b.status in ('confirmed','completed')
  )
);

drop policy if exists "reviews_update_reply_owner" on public.reviews;
create policy "reviews_update_reply_owner"
on public.reviews
for update
to authenticated
using (
  public.is_admin()
  or (barber_id is not null and public.is_barber_owner(barber_id))
  or (
    barber_id is not null
    and exists (
      select 1
      from public.barbers b
      join public.barbershops s on s.id = b.shop_id
      where b.id = barber_id and s.owner_profile_id = auth.uid()
    )
  )
  or (shop_id is not null and public.is_shop_owner(shop_id))
)
with check (
  public.is_admin()
  or (barber_id is not null and public.is_barber_owner(barber_id))
  or (
    barber_id is not null
    and exists (
      select 1
      from public.barbers b
      join public.barbershops s on s.id = b.shop_id
      where b.id = barber_id and s.owner_profile_id = auth.uid()
    )
  )
  or (shop_id is not null and public.is_shop_owner(shop_id))
);

create or replace function public.recompute_target_rating(target_type text, target_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_avg numeric(3,2);
  v_count int;
begin
  select coalesce(avg(r.rating),0)::numeric(3,2), count(*)::int
  into v_avg, v_count
  from public.reviews r
  where r.target_type = target_type
    and r.target_id = target_id
    and r.status = 'published'
    and r.is_verified = true;

  if target_type = 'barber' then
    update public.barbers
    set rating_avg = v_avg,
        rating_count = v_count,
        reviews_count = v_count
    where id = target_id;
  elsif target_type = 'shop' then
    update public.barbershops
    set rating_avg = v_avg,
        rating_count = v_count,
        reviews_count = v_count
    where id = target_id;
  end if;
end;
$$;

commit;


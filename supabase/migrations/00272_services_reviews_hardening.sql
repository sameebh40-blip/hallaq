begin;

create index if not exists barbers_shop_id_idx on public.barbers (shop_id);

create or replace function public.enforce_service_shop_barber_relation()
returns trigger
language plpgsql
as $$
begin
  if new.shop_id is not null and new.barber_id is not null then
    if not exists (
      select 1
      from public.barbers b
      where b.id = new.barber_id
        and b.shop_id = new.shop_id
    ) then
      raise exception 'Service barber_id must belong to service shop_id';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists services_enforce_relation on public.services;
create trigger services_enforce_relation
before insert or update of shop_id, barber_id
on public.services
for each row execute function public.enforce_service_shop_barber_relation();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'services_image_url_format'
      and conrelid = 'public.services'::regclass
  ) then
    alter table public.services
    add constraint services_image_url_format
    check (image_url is null or image_url ~* '^https?://');
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'portfolio_items_image_url_format'
      and conrelid = 'public.portfolio_items'::regclass
  ) then
    alter table public.portfolio_items
    add constraint portfolio_items_image_url_format
    check (
      image_url is null
      or image_url ~* '^https?://'
      or image_url = media_url
    );
  end if;
end $$;

alter table public.reviews add column if not exists booking_id uuid references public.bookings (id) on delete set null;
alter table public.reviews add column if not exists status text not null default 'published';

create unique index if not exists reviews_unique_booking_id
on public.reviews (booking_id)
where booking_id is not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'reviews_image_url_format'
      and conrelid = 'public.reviews'::regclass
  ) then
    alter table public.reviews
    add constraint reviews_image_url_format
    check (image_url is null or image_url ~* '^https?://');
  end if;
end $$;

create or replace view public.barber_services_effective with (security_invoker = true) as
select
  s.*,
  b.id as barber_ref
from public.services s
join public.barbers b on b.id = s.barber_id
where s.is_active = true and s.deleted_at is null
union all
select
  s.*,
  b.id as barber_ref
from public.services s
join public.barbers b on b.shop_id = s.shop_id
where s.barber_id is null
  and s.shop_id is not null
  and s.is_active = true
  and s.deleted_at is null;

commit;


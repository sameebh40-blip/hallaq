begin;

alter table public.services add column if not exists shop_id uuid references public.barbershops (id) on delete set null;
alter table public.services add column if not exists barber_id uuid references public.barbers (id) on delete set null;
alter table public.services add column if not exists name_en text;
alter table public.services add column if not exists name_ar text;
alter table public.services add column if not exists description_en text;
alter table public.services add column if not exists description_ar text;
alter table public.services add column if not exists price_bhd numeric(10,3);
alter table public.services add column if not exists duration_minutes int;
alter table public.services add column if not exists image_url text;
alter table public.services add column if not exists category text;
alter table public.services add column if not exists is_popular boolean not null default false;
alter table public.services add column if not exists is_active boolean not null default true;

update public.services
set shop_id = owner_id
where shop_id is null
  and owner_type = 'shop'
  and owner_id is not null;

update public.services
set barber_id = owner_id
where barber_id is null
  and owner_type = 'barber'
  and owner_id is not null;

update public.services
set
  name_en = coalesce(name_en, name),
  description_en = coalesce(description_en, description),
  price_bhd = coalesce(price_bhd, price, 0),
  duration_minutes = coalesce(duration_minutes, duration_min, 30),
  is_active = coalesce(is_active, active, true)
where true;

update public.services
set is_active = false,
    deleted_at = coalesce(deleted_at, now())
where shop_id is null
  and barber_id is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'services_owner_check'
      and conrelid = 'public.services'::regclass
  ) then
    alter table public.services
    add constraint services_owner_check
    check (shop_id is not null or barber_id is not null)
    not valid;
  end if;
end $$;

commit;


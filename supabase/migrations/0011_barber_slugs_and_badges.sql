create or replace function public.slugify(input text)
returns text
language sql
immutable
as $$
  select trim(both '-' from regexp_replace(lower(coalesce(input, '')), '[^a-z0-9]+', '-', 'g'))
$$;

create or replace function public.generate_unique_barber_slug(p_display_name text, p_id uuid)
returns text
language plpgsql
as $$
declare
  base text;
  candidate text;
begin
  base := public.slugify(p_display_name);
  if base is null or base = '' then
    base := 'barber';
  end if;

  candidate := base;
  if exists (select 1 from public.barbers b where b.slug = candidate and b.id <> p_id) then
    candidate := base || '-' || substr(p_id::text, 1, 6);
  end if;

  return candidate;
end;
$$;

alter table public.barbers add column if not exists slug text;
alter table public.barbers add column if not exists badge_verified boolean not null default false;
alter table public.barbers add column if not exists badge_elite boolean not null default false;
alter table public.barbers add column if not exists badge_trending boolean not null default false;
alter table public.barbers add column if not exists badge_certified boolean not null default false;

update public.barbers
set slug = public.generate_unique_barber_slug(display_name, id)
where slug is null or btrim(slug) = '';

alter table public.barbers
  alter column slug set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'barbers_slug_format'
      and conrelid = 'public.barbers'::regclass
  ) then
    alter table public.barbers
      add constraint barbers_slug_format check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$');
  end if;
end $$;

create unique index if not exists barbers_slug_unique on public.barbers (slug);

create or replace function public.barbers_set_slug()
returns trigger
language plpgsql
as $$
begin
  if new.slug is null or btrim(new.slug) = '' then
    new.slug := public.generate_unique_barber_slug(new.display_name, new.id);
  else
    new.slug := public.slugify(new.slug);
  end if;
  return new;
end;
$$;

drop trigger if exists barbers_set_slug on public.barbers;
create trigger barbers_set_slug
before insert or update of display_name, slug on public.barbers
for each row execute function public.barbers_set_slug();

alter table public.barbershops add column if not exists badge_verified boolean not null default false;
alter table public.barbershops add column if not exists badge_elite boolean not null default false;
alter table public.barbershops add column if not exists badge_trending boolean not null default false;
alter table public.barbershops add column if not exists badge_certified boolean not null default false;


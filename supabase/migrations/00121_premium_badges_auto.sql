alter table public.barbers add column if not exists badge_top_rated boolean not null default false;
alter table public.barbershops add column if not exists badge_top_rated boolean not null default false;

create or replace function public.barbers_set_auto_badges()
returns trigger
language plpgsql
as $$
begin
  new.badge_verified := (coalesce(new.rating_count, 0) >= 25);
  new.badge_elite := (coalesce(new.rating_avg, 0) >= 4.8 and coalesce(new.rating_count, 0) >= 120);
  new.badge_top_rated := (coalesce(new.rating_avg, 0) >= 4.9 and coalesce(new.rating_count, 0) >= 200);
  new.badge_trending := (coalesce(new.available_now, false) = true or (coalesce(new.rating_avg, 0) >= 4.7 and coalesce(new.rating_count, 0) >= 150));
  return new;
end;
$$;

drop trigger if exists barbers_set_auto_badges on public.barbers;
create trigger barbers_set_auto_badges
before insert or update of rating_avg, rating_count, available_now on public.barbers
for each row execute function public.barbers_set_auto_badges();

create or replace function public.barbershops_set_auto_badges()
returns trigger
language plpgsql
as $$
begin
  new.badge_verified := (coalesce(new.rating_count, 0) >= 50);
  new.badge_elite := (coalesce(new.rating_avg, 0) >= 4.8 and coalesce(new.rating_count, 0) >= 250);
  new.badge_top_rated := (coalesce(new.rating_avg, 0) >= 4.9 and coalesce(new.rating_count, 0) >= 400);
  new.badge_trending := (coalesce(new.rating_avg, 0) >= 4.7 and coalesce(new.rating_count, 0) >= 300);
  return new;
end;
$$;

drop trigger if exists barbershops_set_auto_badges on public.barbershops;
create trigger barbershops_set_auto_badges
before insert or update of rating_avg, rating_count on public.barbershops
for each row execute function public.barbershops_set_auto_badges();

alter table public.barbers disable trigger user;
alter table public.barbershops disable trigger user;
update public.barbers set updated_at = updated_at;
update public.barbershops set updated_at = updated_at;
alter table public.barbers enable trigger user;
alter table public.barbershops enable trigger user;

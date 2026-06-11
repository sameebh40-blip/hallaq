begin;

alter table public.profiles
  add column if not exists cover_url text;

alter table public.customers
  add column if not exists loyalty_points integer not null default 0;

commit;

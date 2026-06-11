begin;

create table if not exists public.feature_flags (
  key text primary key,
  enabled boolean not null default true,
  description text,
  updated_at timestamptz not null default now()
);

create or replace function public.touch_feature_flags_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists feature_flags_touch_updated_at on public.feature_flags;
create trigger feature_flags_touch_updated_at
before update on public.feature_flags
for each row execute function public.touch_feature_flags_updated_at();

alter table public.feature_flags enable row level security;

drop policy if exists "feature_flags_public_read" on public.feature_flags;
create policy "feature_flags_public_read"
on public.feature_flags
for select
to anon, authenticated
using (true);

drop policy if exists "feature_flags_admin_write" on public.feature_flags;
create policy "feature_flags_admin_write"
on public.feature_flags
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

commit;


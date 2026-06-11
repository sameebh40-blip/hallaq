begin;

create extension if not exists pg_net;

create table if not exists public.app_config (
  key text primary key,
  value text not null default '',
  updated_at timestamptz not null default now()
);

alter table public.app_config enable row level security;

drop policy if exists "app_config_admin_all" on public.app_config;
create policy "app_config_admin_all"
on public.app_config
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop trigger if exists app_config_set_updated_at on public.app_config;
create trigger app_config_set_updated_at
before update on public.app_config
for each row execute function public.set_updated_at();

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  token text not null,
  platform text not null default 'unknown' check (platform in ('android','ios','web','unknown')),
  device_id text,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (token)
);

create index if not exists device_tokens_profile_idx on public.device_tokens (profile_id);

alter table public.device_tokens enable row level security;

drop policy if exists "device_tokens_read_own" on public.device_tokens;
create policy "device_tokens_read_own"
on public.device_tokens
for select
to authenticated
using (profile_id = auth.uid());

drop policy if exists "device_tokens_write_own" on public.device_tokens;
create policy "device_tokens_write_own"
on public.device_tokens
for all
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

drop policy if exists "device_tokens_admin_all" on public.device_tokens;
create policy "device_tokens_admin_all"
on public.device_tokens
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop trigger if exists device_tokens_set_updated_at on public.device_tokens;
create trigger device_tokens_set_updated_at
before update on public.device_tokens
for each row execute function public.set_updated_at();

create or replace function public.upsert_device_token(
  token text,
  platform text default 'unknown',
  device_id text default null
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_user uuid;
  v_platform text;
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception using message = 'NOT_AUTHENTICATED';
  end if;

  v_platform := lower(coalesce(platform, 'unknown'));
  if v_platform not in ('android','ios','web','unknown') then
    v_platform := 'unknown';
  end if;

  insert into public.device_tokens (profile_id, token, platform, device_id, enabled, last_seen_at)
  values (v_user, token, v_platform, device_id, true, now())
  on conflict (token)
  do update set
    profile_id = excluded.profile_id,
    platform = excluded.platform,
    device_id = coalesce(excluded.device_id, public.device_tokens.device_id),
    enabled = true,
    last_seen_at = now(),
    updated_at = now();
end;
$$;

create or replace function public.on_notification_inserted_push()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_url text;
  v_secret text;
begin
  select value into v_url from public.app_config where key = 'push_url';
  select value into v_secret from public.app_config where key = 'push_secret';

  v_url := coalesce(trim(v_url), '');
  v_secret := coalesce(trim(v_secret), '');

  if v_url = '' then
    return new;
  end if;

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-hallaq-secret', v_secret
    ),
    body := jsonb_build_object(
      'notification_id', new.id,
      'profile_id', new.profile_id,
      'type', new.type,
      'title', new.title,
      'body', new.body,
      'data', new.data,
      'created_at', new.created_at
    )
  );

  return new;
end;
$$;

drop trigger if exists notifications_push_insert on public.notifications;
create trigger notifications_push_insert
after insert on public.notifications
for each row execute function public.on_notification_inserted_push();

do $$
begin
  if to_regprocedure('public.upsert_device_token(text, text, text)') is not null then
    revoke all on function public.upsert_device_token(text, text, text) from public;
  end if;

  if to_regprocedure('public.upsert_device_token(text, text, text)') is not null
     and exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.upsert_device_token(text, text, text) to authenticated;
  end if;
end;
$$;

commit;


begin;

do $$
begin
  if not exists (
    select 1
    from information_schema.tables
    where table_schema = 'public' and table_name = 'feature_flags'
  ) then
    execute $ct$
      create table public.feature_flags (
        key text primary key,
        enabled boolean not null default true,
        description text,
        updated_at timestamptz not null default now()
      )
    $ct$;
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'feature_flags' and column_name = 'key'
  ) then
    execute 'alter table public.feature_flags add column key text';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'feature_flags' and column_name = 'flag_name'
  ) then
    execute 'update public.feature_flags set key = coalesce(key, flag_name) where key is null';
    begin
      execute 'alter table public.feature_flags alter column flag_name drop not null';
    exception when others then
      null;
    end;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'feature_flags' and column_name = 'flag_key'
  ) then
    execute 'update public.feature_flags set key = coalesce(key, flag_key) where key is null';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'feature_flags' and column_name = 'enabled'
  ) then
    execute 'alter table public.feature_flags add column enabled boolean not null default true';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'feature_flags' and column_name = 'description'
  ) then
    execute 'alter table public.feature_flags add column description text';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'feature_flags' and column_name = 'updated_at'
  ) then
    execute 'alter table public.feature_flags add column updated_at timestamptz not null default now()';
  end if;
end;
$$;

create or replace function public.feature_flags_sync_compat()
returns trigger
language plpgsql
as $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'feature_flags' and column_name = 'flag_name'
  ) then
    if new.flag_name is null and new.key is not null then
      new.flag_name := new.key;
    end if;
    if new.key is null and new.flag_name is not null then
      new.key := new.flag_name;
    end if;
  end if;
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'feature_flags' and column_name = 'flag_key'
  ) then
    if new.key is null and new.flag_key is not null then
      new.key := new.flag_key;
    end if;
    if new.flag_key is null and new.key is not null then
      new.flag_key := new.key;
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists feature_flags_sync_compat_trg on public.feature_flags;
create trigger feature_flags_sync_compat_trg
before insert or update on public.feature_flags
for each row execute function public.feature_flags_sync_compat();

create unique index if not exists feature_flags_key_uidx on public.feature_flags (key);

commit;


begin;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public' and table_name = 'feature_flags'
  ) then
    if not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public' and table_name = 'feature_flags' and column_name = 'key'
    ) then
      if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public' and table_name = 'feature_flags' and column_name = 'flag_key'
      ) then
        execute 'alter table public.feature_flags rename column flag_key to key';
      elsif exists (
        select 1
        from information_schema.columns
        where table_schema = 'public' and table_name = 'feature_flags' and column_name = 'name'
      ) then
        execute 'alter table public.feature_flags rename column name to key';
      elsif exists (
        select 1
        from information_schema.columns
        where table_schema = 'public' and table_name = 'feature_flags' and column_name = 'feature_key'
      ) then
        execute 'alter table public.feature_flags rename column feature_key to key';
      else
        execute 'alter table public.feature_flags add column key text';
      end if;
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
  else
    execute $ct$
      create table public.feature_flags (
        key text primary key,
        enabled boolean not null default true,
        description text,
        updated_at timestamptz not null default now()
      )
    $ct$;
  end if;
end;
$$;

delete from public.feature_flags a
using public.feature_flags b
where a.key is not null
  and b.key is not null
  and a.key = b.key
  and a.ctid < b.ctid;

create unique index if not exists feature_flags_key_uidx on public.feature_flags (key);

commit;


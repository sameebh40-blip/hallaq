begin;

do $$
declare
  missing_cols text[];
  missing_views text[];
begin
  select array_agg(x.col) into missing_cols
  from (
    select 'public.barbershops.deleted_at' as col
    where not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public' and table_name = 'barbershops' and column_name = 'deleted_at'
    )
    union all
    select 'public.barbershops.status' as col
    where not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public' and table_name = 'barbershops' and column_name = 'status'
    )
    union all
    select 'public.barbers.deleted_at' as col
    where not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public' and table_name = 'barbers' and column_name = 'deleted_at'
    )
    union all
    select 'public.reels.deleted_at' as col
    where not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public' and table_name = 'reels' and column_name = 'deleted_at'
    )
    union all
    select 'public.reels.media_path' as col
    where not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public' and table_name = 'reels' and column_name = 'media_path'
    )
    union all
    select 'public.reels.thumbnail_path' as col
    where not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public' and table_name = 'reels' and column_name = 'thumbnail_path'
    )
    union all
    select 'public.services.deleted_at' as col
    where not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public' and table_name = 'services' and column_name = 'deleted_at'
    )
  ) x;

  if missing_cols is not null then
    raise exception 'DB health failed: missing columns: %', array_to_string(missing_cols, ', ');
  end if;

  select array_agg(v.name) into missing_views
  from (
    select 'public.shops' as name where to_regclass('public.shops') is null
    union all
    select 'public.appointments' as name where to_regclass('public.appointments') is null
    union all
    select 'public.posts' as name where to_regclass('public.posts') is null
  ) v;

  if missing_views is not null then
    raise exception 'DB health failed: missing views: %', array_to_string(missing_views, ', ');
  end if;

  perform 1 from public.shops limit 1;
  perform 1 from public.appointments limit 1;
  perform 1 from public.posts limit 1;
end $$;

commit;

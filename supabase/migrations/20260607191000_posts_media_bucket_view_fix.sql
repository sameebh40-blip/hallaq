begin;

do $$
declare
  reels_kind char;
  posts_kind char;
begin
  select c.relkind
  into reels_kind
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'reels';

  select c.relkind
  into posts_kind
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'posts';

  if reels_kind = 'r' then
    alter table public.reels add column if not exists media_bucket text;
    alter table public.reels add column if not exists thumbnail_bucket text;

    update public.reels
    set media_bucket = 'reels'
    where media_bucket is null or btrim(media_bucket) = '';

    update public.reels
    set thumbnail_bucket = coalesce(nullif(btrim(thumbnail_bucket), ''), nullif(btrim(media_bucket), ''), 'reels')
    where thumbnail_bucket is null or btrim(thumbnail_bucket) = '';

    alter table public.reels alter column media_bucket set default 'reels';
    alter table public.reels alter column thumbnail_bucket set default 'reels';
    alter table public.reels alter column media_bucket set not null;
    alter table public.reels alter column thumbnail_bucket set not null;
  end if;

  if posts_kind = 'r' then
    alter table public.posts add column if not exists media_bucket text;
    alter table public.posts add column if not exists thumbnail_bucket text;

    update public.posts
    set media_bucket = 'reels'
    where media_bucket is null or btrim(media_bucket) = '';

    update public.posts
    set thumbnail_bucket = coalesce(nullif(btrim(thumbnail_bucket), ''), nullif(btrim(media_bucket), ''), 'reels')
    where thumbnail_bucket is null or btrim(thumbnail_bucket) = '';

    alter table public.posts alter column media_bucket set default 'reels';
    alter table public.posts alter column thumbnail_bucket set default 'reels';
    alter table public.posts alter column media_bucket set not null;
    alter table public.posts alter column thumbnail_bucket set not null;
  end if;

  if reels_kind = 'v' then
    create or replace view public.reels
    with (security_invoker = true) as
    select p.*
    from public.posts p;
  end if;
end;
$$;

commit;

begin;

do $$
declare
  reels_kind char;
  v_kind char;
begin
  select c.relkind
  into v_kind
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'posts';

  select c.relkind
  into reels_kind
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'reels';

  if reels_kind = 'r' then
    alter table public.reels add column if not exists media_bucket text;
    alter table public.reels add column if not exists thumbnail_bucket text;

    update public.reels
    set media_bucket = 'reels'
    where media_bucket is null or btrim(media_bucket) = '';

    update public.reels
    set thumbnail_bucket = coalesce(nullif(btrim(media_bucket), ''), 'reels')
    where thumbnail_bucket is null or btrim(thumbnail_bucket) = '';

    alter table public.reels alter column media_bucket set default 'reels';
    alter table public.reels alter column thumbnail_bucket set default 'reels';

    alter table public.reels alter column media_bucket set not null;
    alter table public.reels alter column thumbnail_bucket set not null;
  end if;

  if v_kind = 'r' then
    alter table public.posts add column if not exists media_bucket text;
    alter table public.posts add column if not exists thumbnail_bucket text;

    update public.posts
    set media_bucket = 'reels'
    where media_bucket is null or btrim(media_bucket) = '';

    update public.posts
    set thumbnail_bucket = coalesce(nullif(btrim(media_bucket), ''), 'reels')
    where thumbnail_bucket is null or btrim(thumbnail_bucket) = '';

    alter table public.posts alter column media_bucket set default 'reels';
    alter table public.posts alter column thumbnail_bucket set default 'reels';

    alter table public.posts alter column media_bucket set not null;
    alter table public.posts alter column thumbnail_bucket set not null;
  end if;

  if v_kind = 'v' and reels_kind = 'r' then
    create or replace view public.posts as
    select
      r.id,
      r.created_by,
      r.owner_type,
      r.shop_id,
      r.barber_id,
      r.media_url,
      r.media_path,
      r.thumbnail_url,
      r.thumbnail_path,
      r.media_bucket,
      r.thumbnail_bucket,
      r.media_type,
      r.caption,
      r.hashtags,
      r.location,
      r.status,
      r.is_featured,
      r.is_sponsored,
      r.likes_count,
      r.comments_count,
      r.saves_count,
      r.shares_count,
      r.video_url,
      r.image_url,
      r.approved_by,
      r.approved_at,
      r.rejected_by,
      r.rejected_at,
      r.rejection_reason,
      r.deleted_at,
      r.created_at,
      r.updated_at
    from public.reels r;
  end if;
end;
$$;

commit;

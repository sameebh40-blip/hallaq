begin;

do $$
begin
  if exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'posts' and c.relkind = 'r'
  ) then
    alter table public.posts add column if not exists deleted_at timestamptz;
    create index if not exists posts_deleted_idx on public.posts (deleted_at);
    create index if not exists posts_feed_idx on public.posts (status, deleted_at, created_at desc);
    create index if not exists posts_shop_feed_idx on public.posts (shop_id, status, deleted_at, created_at desc);
  elsif exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'reels' and c.relkind = 'r'
  ) then
    alter table public.reels add column if not exists deleted_at timestamptz;
    create index if not exists reels_deleted_idx on public.reels (deleted_at);
    create index if not exists reels_feed_idx on public.reels (status, deleted_at, created_at desc);
    create index if not exists reels_shop_feed_idx on public.reels (shop_id, status, deleted_at, created_at desc);
  end if;
end;
$$;

commit;

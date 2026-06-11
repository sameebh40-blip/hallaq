begin;

do $$
begin
  if to_regprocedure('public.sync_reel_counters()') is not null then
    if not exists (
      select 1
      from pg_trigger t
      join pg_class c on c.oid = t.tgrelid
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = 'reel_likes'
        and t.tgname = 'reel_likes_sync_counter'
        and not t.tgisinternal
    ) then
      create trigger reel_likes_sync_counter
      after insert or delete on public.reel_likes
      for each row execute function public.sync_reel_counters();
    end if;

    if not exists (
      select 1
      from pg_trigger t
      join pg_class c on c.oid = t.tgrelid
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = 'reel_comments'
        and t.tgname = 'reel_comments_sync_counter'
        and not t.tgisinternal
    ) then
      create trigger reel_comments_sync_counter
      after insert or delete on public.reel_comments
      for each row execute function public.sync_reel_counters();
    end if;
  end if;
end $$;

do $$
declare
  has_status boolean;
begin
  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'reel_comments'
      and column_name = 'status'
  )
  into has_status;

  if has_status then
    execute $sql$
      with
      likes as (
        select reel_id, count(*)::int as c
        from public.reel_likes
        group by reel_id
      ),
      comments as (
        select reel_id, count(*)::int as c
        from public.reel_comments
        where status = 'visible'
        group by reel_id
      ),
      saves as (
        select reel_id, count(*)::int as c
        from public.reel_saves
        group by reel_id
      )
      update public.reels r
      set
        likes_count = coalesce(likes.c, 0),
        comments_count = coalesce(comments.c, 0),
        saves_count = coalesce(saves.c, 0)
      from public.reels r2
      left join likes on likes.reel_id = r2.id
      left join comments on comments.reel_id = r2.id
      left join saves on saves.reel_id = r2.id
      where r.id = r2.id;
    $sql$;
  else
    execute $sql$
      with
      likes as (
        select reel_id, count(*)::int as c
        from public.reel_likes
        group by reel_id
      ),
      comments as (
        select reel_id, count(*)::int as c
        from public.reel_comments
        group by reel_id
      ),
      saves as (
        select reel_id, count(*)::int as c
        from public.reel_saves
        group by reel_id
      )
      update public.reels r
      set
        likes_count = coalesce(likes.c, 0),
        comments_count = coalesce(comments.c, 0),
        saves_count = coalesce(saves.c, 0)
      from public.reels r2
      left join likes on likes.reel_id = r2.id
      left join comments on comments.reel_id = r2.id
      left join saves on saves.reel_id = r2.id
      where r.id = r2.id;
    $sql$;
  end if;
end $$;

do $$
begin
  if to_regclass('public.reels') is not null
     and to_regclass('public.reel_likes') is not null
     and not exists (
       select 1
       from pg_indexes
       where schemaname = 'public'
         and indexname = 'reel_likes_reel_id_idx'
     ) then
    create index reel_likes_reel_id_idx on public.reel_likes (reel_id);
  end if;

  if to_regclass('public.reels') is not null
     and to_regclass('public.reel_saves') is not null
     and not exists (
       select 1
       from pg_indexes
       where schemaname = 'public'
         and indexname = 'reel_saves_reel_id_idx'
     ) then
    create index reel_saves_reel_id_idx on public.reel_saves (reel_id);
  end if;
end $$;

do $$
begin
  if to_regclass('public.reels') is not null
     and to_regclass('public.barbers') is not null then
    update public.reels r
    set barber_id = null
    where barber_id is not null
      and not exists (select 1 from public.barbers b where b.id = r.barber_id);
  end if;

  if to_regclass('public.reels') is not null
     and to_regclass('public.barbershops') is not null then
    update public.reels r
    set shop_id = null
    where shop_id is not null
      and not exists (select 1 from public.barbershops s where s.id = r.shop_id);
  end if;
end $$;

do $$
begin
  if to_regclass('public.reels') is not null
     and to_regclass('public.barbers') is not null
     and to_regclass('public.barbershops') is not null then
    update public.reels
    set deleted_at = coalesce(deleted_at, now())
    where barber_id is null and shop_id is null and deleted_at is null;
  end if;
end $$;

do $$
begin
  if to_regclass('public.reels') is not null
     and exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.reels;
    exception when duplicate_object then null;
    end;
    begin
      alter publication supabase_realtime add table public.reel_likes;
    exception when duplicate_object then null;
    end;
    begin
      alter publication supabase_realtime add table public.reel_saves;
    exception when duplicate_object then null;
    end;
    begin
      alter publication supabase_realtime add table public.reel_comments;
    exception when duplicate_object then null;
    end;
  end if;
end $$;

commit;

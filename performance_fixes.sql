begin;

do $$
begin
  if to_regclass('public.reels') is not null
     and not exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'reels_barber_status_created_idx') then
    create index reels_barber_status_created_idx on public.reels (barber_id, status, created_at desc);
  end if;

  if to_regclass('public.services') is not null
     and not exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'services_owner_lookup_idx') then
    create index services_owner_lookup_idx on public.services (owner_type, owner_id, created_at desc);
  end if;

  if to_regclass('public.services') is not null
     and not exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'services_active_deleted_idx') then
    create index services_active_deleted_idx on public.services (is_active, deleted_at);
  end if;

  if to_regclass('public.follows') is not null
     and not exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'follows_target_idx') then
    create index follows_target_idx on public.follows (target_type, target_id, created_at desc);
  end if;

  if to_regclass('public.favorites') is not null
     and not exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'favorites_target_idx') then
    create index favorites_target_idx on public.favorites (target_type, target_id, created_at desc);
  end if;
end $$;

commit;

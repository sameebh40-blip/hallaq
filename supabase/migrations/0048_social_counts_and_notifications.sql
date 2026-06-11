begin;

alter table public.barbers add column if not exists followers_count int not null default 0;
alter table public.barbershops add column if not exists followers_count int not null default 0;

create or replace function public.on_reel_like_changed()
returns trigger
language plpgsql
as $$
declare
  owner_profile uuid;
  r record;
begin
  if tg_op = 'INSERT' then
    update public.reels
    set likes_count = coalesce(likes_count, 0) + 1
    where id = new.reel_id;

    select reel.barber_id, reel.shop_id into r from public.reels reel where reel.id = new.reel_id;
    owner_profile := null;
    if r.barber_id is not null then
      select b.profile_id into owner_profile from public.barbers b where b.id = r.barber_id;
    elsif r.shop_id is not null then
      select s.owner_profile_id into owner_profile from public.barbershops s where s.id = r.shop_id;
    end if;

    if owner_profile is not null and owner_profile <> new.profile_id then
      perform public.notify(
        owner_profile,
        'reel_like',
        'New reel like',
        'Someone liked your reel.',
        jsonb_build_object('reel_id', new.reel_id, 'by_profile_id', new.profile_id)
      );
    end if;

    return new;
  end if;

  if tg_op = 'DELETE' then
    update public.reels
    set likes_count = greatest(coalesce(likes_count, 0) - 1, 0)
    where id = old.reel_id;
    return old;
  end if;

  return null;
end;
$$;

drop trigger if exists reel_likes_sync_counts on public.reel_likes;
create trigger reel_likes_sync_counts
after insert or delete on public.reel_likes
for each row execute function public.on_reel_like_changed();

create or replace function public.on_reel_save_changed()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    update public.reels
    set saves_count = coalesce(saves_count, 0) + 1
    where id = new.reel_id;
    return new;
  end if;

  if tg_op = 'DELETE' then
    update public.reels
    set saves_count = greatest(coalesce(saves_count, 0) - 1, 0)
    where id = old.reel_id;
    return old;
  end if;

  return null;
end;
$$;

do $$
begin
  if to_regclass('public.reel_saves') is not null then
    drop trigger if exists reel_saves_sync_counts on public.reel_saves;
    create trigger reel_saves_sync_counts
    after insert or delete on public.reel_saves
    for each row execute function public.on_reel_save_changed();
  end if;
end $$;

create or replace function public.on_reel_comment_changed()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    update public.reels
    set comments_count = coalesce(comments_count, 0) + 1
    where id = new.reel_id;
    return new;
  end if;

  if tg_op = 'DELETE' then
    update public.reels
    set comments_count = greatest(coalesce(comments_count, 0) - 1, 0)
    where id = old.reel_id;
    return old;
  end if;

  return null;
end;
$$;

drop trigger if exists reel_comments_sync_counts on public.reel_comments;
create trigger reel_comments_sync_counts
after insert or delete on public.reel_comments
for each row execute function public.on_reel_comment_changed();

create or replace function public.on_follow_changed()
returns trigger
language plpgsql
as $$
declare
  owner_profile uuid;
begin
  if tg_op = 'INSERT' then
    if new.target_type = 'barber' then
      update public.barbers
      set followers_count = coalesce(followers_count, 0) + 1
      where id = new.target_id;
      select b.profile_id into owner_profile from public.barbers b where b.id = new.target_id;
    elsif new.target_type = 'shop' then
      update public.barbershops
      set followers_count = coalesce(followers_count, 0) + 1
      where id = new.target_id;
      select s.owner_profile_id into owner_profile from public.barbershops s where s.id = new.target_id;
    end if;

    if owner_profile is not null and owner_profile <> new.profile_id then
      perform public.notify(
        owner_profile,
        'new_follower',
        'New follower',
        'Someone followed you.',
        jsonb_build_object('by_profile_id', new.profile_id, 'target_type', new.target_type, 'target_id', new.target_id)
      );
    end if;

    return new;
  end if;

  if tg_op = 'DELETE' then
    if old.target_type = 'barber' then
      update public.barbers
      set followers_count = greatest(coalesce(followers_count, 0) - 1, 0)
      where id = old.target_id;
    elsif old.target_type = 'shop' then
      update public.barbershops
      set followers_count = greatest(coalesce(followers_count, 0) - 1, 0)
      where id = old.target_id;
    end if;
    return old;
  end if;

  return null;
end;
$$;

drop trigger if exists follows_sync_counts_notify on public.follows;
create trigger follows_sync_counts_notify
after insert or delete on public.follows
for each row execute function public.on_follow_changed();

create or replace function public.on_review_inserted_notify()
returns trigger
language plpgsql
as $$
declare
  owner_profile uuid;
begin
  owner_profile := null;
  if new.target_type = 'barber' then
    select b.profile_id into owner_profile from public.barbers b where b.id = new.target_id;
  elsif new.target_type = 'shop' then
    select s.owner_profile_id into owner_profile from public.barbershops s where s.id = new.target_id;
  end if;

  if owner_profile is not null and owner_profile <> new.customer_profile_id then
    perform public.notify(
      owner_profile,
      'new_review',
      'New review',
      'You received a new review.',
      jsonb_build_object('review_id', new.id, 'target_type', new.target_type, 'target_id', new.target_id, 'rating', new.rating)
    );
  end if;

  return new;
end;
$$;

drop trigger if exists reviews_notify_insert on public.reviews;
create trigger reviews_notify_insert
after insert on public.reviews
for each row execute function public.on_review_inserted_notify();

commit;


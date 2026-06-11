begin;

create table if not exists public.push_queue (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','processing','sent','failed')),
  attempts int not null default 0,
  next_attempt_at timestamptz not null default now(),
  last_error text,
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (notification_id)
);

create index if not exists push_queue_next_idx on public.push_queue (status, next_attempt_at);
create index if not exists push_queue_profile_idx on public.push_queue (profile_id, created_at desc);

alter table public.push_queue enable row level security;

drop policy if exists "push_queue_admin_all" on public.push_queue;
create policy "push_queue_admin_all"
on public.push_queue
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop trigger if exists push_queue_set_updated_at on public.push_queue;
create trigger push_queue_set_updated_at
before update on public.push_queue
for each row execute function public.set_updated_at();

create or replace function public.enqueue_push_for_notification()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  insert into public.push_queue (notification_id, profile_id)
  values (new.id, new.profile_id)
  on conflict (notification_id) do nothing;
  return new;
end;
$$;

create or replace function public.claim_push_queue(batch_size int default 50)
returns table (id uuid, notification_id uuid, profile_id uuid)
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  return query
  with picked as (
    select q.id
    from public.push_queue q
    where q.status = 'pending'
      and q.next_attempt_at <= now()
    order by q.created_at asc
    for update skip locked
    limit batch_size
  ),
  updated as (
    update public.push_queue q
    set status = 'processing',
        attempts = q.attempts + 1,
        updated_at = now()
    where q.id in (select id from picked)
    returning q.id, q.notification_id, q.profile_id
  )
  select u.id, u.notification_id, u.profile_id from updated u;
end;
$$;

create or replace function public.mark_push_queue_sent(queue_id uuid)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  update public.push_queue
  set status = 'sent',
      processed_at = now(),
      updated_at = now()
  where id = queue_id;
end;
$$;

create or replace function public.mark_push_queue_failed(queue_id uuid, err text, retry_seconds int default 300)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_retry int;
begin
  v_retry := greatest(30, least(coalesce(retry_seconds, 300), 3600));
  update public.push_queue
  set status = 'pending',
      last_error = left(coalesce(err, ''), 2000),
      next_attempt_at = now() + make_interval(secs => v_retry),
      updated_at = now()
  where id = queue_id;
end;
$$;

drop trigger if exists notifications_push_insert on public.notifications;
drop function if exists public.on_notification_inserted_push();

drop trigger if exists notifications_enqueue_push on public.notifications;
create trigger notifications_enqueue_push
after insert on public.notifications
for each row execute function public.enqueue_push_for_notification();

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    if to_regprocedure('public.claim_push_queue(integer)') is not null then
      revoke all on function public.claim_push_queue(integer) from public;
    end if;
    if to_regprocedure('public.mark_push_queue_sent(uuid)') is not null then
      revoke all on function public.mark_push_queue_sent(uuid) from public;
    end if;
    if to_regprocedure('public.mark_push_queue_failed(uuid, text, integer)') is not null then
      revoke all on function public.mark_push_queue_failed(uuid, text, integer) from public;
    end if;
  end if;
end;
$$;

commit;

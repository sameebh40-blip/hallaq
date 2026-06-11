begin;

create table if not exists public.booking_events (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id) on delete cascade,
  event_type text not null check (event_type in ('booking_created','booking_rescheduled','booking_status_changed')),
  actor_profile_id uuid,
  old_status text,
  new_status text,
  old_start_at timestamptz,
  new_start_at timestamptz,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists booking_events_booking_idx on public.booking_events (booking_id, created_at desc);

alter table public.booking_events enable row level security;

drop policy if exists "booking_events_read_participants" on public.booking_events;
create policy "booking_events_read_participants"
on public.booking_events
for select
to authenticated
using (
  public.is_admin()
  or public.is_booking_participant(booking_id)
);

create or replace function public.on_booking_events_insert()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_actor uuid;
begin
  v_actor := auth.uid();
  insert into public.booking_events (booking_id, event_type, actor_profile_id, new_status, new_start_at, meta)
  values (
    new.id,
    'booking_created',
    v_actor,
    new.status,
    new.start_at,
    jsonb_build_object('shop_id', new.shop_id, 'barber_id', new.barber_id, 'service_id', new.service_id)
  );
  return new;
end;
$$;

create or replace function public.on_booking_events_update()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_actor uuid;
begin
  v_actor := coalesce(new.cancelled_by_profile_id, auth.uid());

  if new.start_at is distinct from old.start_at then
    insert into public.booking_events (
      booking_id,
      event_type,
      actor_profile_id,
      old_start_at,
      new_start_at,
      old_status,
      new_status,
      meta
    )
    values (
      new.id,
      'booking_rescheduled',
      v_actor,
      old.start_at,
      new.start_at,
      old.status,
      new.status,
      jsonb_build_object('old_end_at', old.end_at, 'new_end_at', new.end_at)
    );
  end if;

  if new.status is distinct from old.status then
    insert into public.booking_events (
      booking_id,
      event_type,
      actor_profile_id,
      old_status,
      new_status,
      old_start_at,
      new_start_at,
      meta
    )
    values (
      new.id,
      'booking_status_changed',
      v_actor,
      old.status,
      new.status,
      old.start_at,
      new.start_at,
      jsonb_build_object('cancel_reason', new.cancel_reason)
    );
  end if;

  return new;
end;
$$;

drop trigger if exists booking_events_insert on public.bookings;
create trigger booking_events_insert
after insert on public.bookings
for each row execute function public.on_booking_events_insert();

drop trigger if exists booking_events_update on public.bookings;
create trigger booking_events_update
after update on public.bookings
for each row execute function public.on_booking_events_update();

commit;


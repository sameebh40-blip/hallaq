create table if not exists public.booking_audit_trail (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null,
  actor_profile_id uuid references public.profiles (id) on delete set null,
  action text not null check (action in ('created','updated','status_changed','deleted')),
  old_status text,
  new_status text,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

create index if not exists booking_audit_trail_booking_idx on public.booking_audit_trail (booking_id, created_at desc);
create index if not exists booking_audit_trail_actor_idx on public.booking_audit_trail (actor_profile_id, created_at desc);

alter table public.booking_audit_trail enable row level security;

drop policy if exists "booking_audit_read_participants" on public.booking_audit_trail;
create policy "booking_audit_read_participants"
on public.booking_audit_trail
for select
to authenticated
using (public.is_admin() or public.is_booking_participant(booking_id));

drop policy if exists "booking_audit_admin_all" on public.booking_audit_trail;
create policy "booking_audit_admin_all"
on public.booking_audit_trail
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create or replace function public.on_booking_audit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid;
  action_name text;
begin
  actor := auth.uid();

  if tg_op = 'INSERT' then
    action_name := 'created';
    insert into public.booking_audit_trail (booking_id, actor_profile_id, action, old_status, new_status, old_data, new_data)
    values (new.id, actor, action_name, null, new.status, null, to_jsonb(new));
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if old.status is distinct from new.status then
      action_name := 'status_changed';
    else
      action_name := 'updated';
    end if;
    insert into public.booking_audit_trail (booking_id, actor_profile_id, action, old_status, new_status, old_data, new_data)
    values (new.id, actor, action_name, old.status, new.status, to_jsonb(old), to_jsonb(new));
    return new;
  end if;

  if tg_op = 'DELETE' then
    action_name := 'deleted';
    insert into public.booking_audit_trail (booking_id, actor_profile_id, action, old_status, new_status, old_data, new_data)
    values (old.id, actor, action_name, old.status, null, to_jsonb(old), null);
    return old;
  end if;

  return null;
end;
$$;

drop trigger if exists bookings_audit_trail on public.bookings;
create trigger bookings_audit_trail
after insert or update or delete on public.bookings
for each row execute function public.on_booking_audit();

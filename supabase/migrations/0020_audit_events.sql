begin;

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_profile_id uuid references public.profiles (id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists audit_events_created_idx on public.audit_events (created_at desc);
create index if not exists audit_events_entity_idx on public.audit_events (entity_type, entity_id);

alter table public.audit_events enable row level security;

drop policy if exists "audit_events_admin_all" on public.audit_events;
create policy "audit_events_admin_all"
on public.audit_events
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "audit_events_owner_insert" on public.audit_events;
create policy "audit_events_owner_insert"
on public.audit_events
for insert
to authenticated
with check (
  actor_profile_id = auth.uid()
  and (
    (
      entity_type = 'booking'
      and exists (
        select 1
        from public.bookings b
        join public.barbershops s on s.id = b.shop_id
        where b.id = entity_id and s.owner_profile_id = auth.uid()
      )
    )
    or
    (
      entity_type = 'service'
      and exists (
        select 1
        from public.services sv
        where sv.id = entity_id and sv.owner_type = 'shop' and sv.owner_id in (
          select s.id from public.barbershops s where s.owner_profile_id = auth.uid()
        )
      )
    )
    or
    (
      entity_type = 'reel'
      and exists (
        select 1
        from public.reels r
        join public.barbershops s on s.id = r.shop_id
        where r.id = entity_id and s.owner_profile_id = auth.uid()
      )
    )
  )
);

commit;


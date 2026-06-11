alter table public.reel_comments
add column if not exists status text not null default 'visible',
add column if not exists hidden_by uuid references public.profiles (id) on delete set null,
add column if not exists hidden_at timestamptz,
add column if not exists hidden_reason text,
add column if not exists updated_at timestamptz not null default now();

alter table public.reel_comments drop constraint if exists reel_comments_status_check;
alter table public.reel_comments
add constraint reel_comments_status_check
check (status in ('visible','hidden'));

drop trigger if exists reel_comments_set_updated_at on public.reel_comments;
create trigger reel_comments_set_updated_at
before update on public.reel_comments
for each row execute function public.set_updated_at();

create index if not exists reel_comments_reel_status_created_idx on public.reel_comments (reel_id, status, created_at desc);

drop policy if exists "reel_comments_public_read" on public.reel_comments;
create policy "reel_comments_public_read"
on public.reel_comments
for select
to anon, authenticated
using (status = 'visible');

drop policy if exists "reel_comments_read_owner_or_admin" on public.reel_comments;
create policy "reel_comments_read_owner_or_admin"
on public.reel_comments
for select
to authenticated
using (profile_id = auth.uid() or public.is_admin());

drop policy if exists "reel_comments_insert_own" on public.reel_comments;
create policy "reel_comments_insert_own"
on public.reel_comments
for insert
to authenticated
with check (profile_id = auth.uid() and status = 'visible' and hidden_by is null and hidden_at is null);

drop policy if exists "reel_comments_update_own" on public.reel_comments;
create policy "reel_comments_update_own"
on public.reel_comments
for update
to authenticated
using (profile_id = auth.uid() and status = 'visible')
with check (profile_id = auth.uid() and status = 'visible' and hidden_by is null and hidden_at is null);

drop policy if exists "reel_comments_delete_own" on public.reel_comments;
create policy "reel_comments_delete_own"
on public.reel_comments
for delete
to authenticated
using (profile_id = auth.uid());

drop policy if exists "reel_comments_admin_all" on public.reel_comments;
create policy "reel_comments_admin_all"
on public.reel_comments
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

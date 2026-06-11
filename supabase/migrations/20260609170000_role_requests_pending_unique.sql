begin;

alter table public.role_requests
drop constraint if exists role_requests_profile_id_requested_role_key;

create unique index if not exists role_requests_pending_unique_idx
on public.role_requests (profile_id, requested_role)
where status = 'pending';

commit;

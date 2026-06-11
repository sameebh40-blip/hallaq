begin;

alter table public.role_requests
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by uuid references public.profiles (id);

create index if not exists role_requests_reviewed_at_idx on public.role_requests (reviewed_at desc);

commit;


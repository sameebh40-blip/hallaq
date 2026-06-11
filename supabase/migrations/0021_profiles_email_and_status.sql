begin;

alter table public.profiles
  add column if not exists email text,
  add column if not exists status text not null default 'active'
    check (status in ('active','suspended'));

create index if not exists profiles_email_idx on public.profiles (email);
create index if not exists profiles_status_created_idx on public.profiles (status, created_at desc);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role, email, status)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    'customer',
    new.email,
    'active'
  )
  on conflict (id) do update
    set email = excluded.email
    where public.profiles.email is null;

  return new;
end;
$$;

insert into public.profiles (id, full_name, role, email, status)
select u.id, '', 'customer', u.email, 'active'
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null;

update public.profiles p
set email = u.email
from auth.users u
where u.id = p.id and p.email is null;

commit;

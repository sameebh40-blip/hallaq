begin;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role, email, phone, status)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    'customer',
    new.email,
    new.phone,
    'active'
  )
  on conflict (id) do update
    set email = coalesce(public.profiles.email, excluded.email),
        phone = coalesce(public.profiles.phone, excluded.phone)
    where public.profiles.email is null or public.profiles.phone is null;

  return new;
end;
$$;

create or replace function public.handle_user_updated()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set email = new.email,
      phone = new.phone
  where id = new.id;
  return new;
end;
$$;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'on_auth_user_created') then
    create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();
  end if;

  if not exists (select 1 from pg_trigger where tgname = 'on_auth_user_updated') then
    create trigger on_auth_user_updated
    after update of email, phone on auth.users
    for each row execute function public.handle_user_updated();
  end if;
end $$;

insert into public.profiles (id, full_name, role, email, phone, status)
select u.id, '', 'customer', u.email, u.phone, 'active'
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null;

update public.profiles p
set email = u.email
from auth.users u
where u.id = p.id and p.email is null;

update public.profiles p
set phone = u.phone
from auth.users u
where u.id = p.id and p.phone is null;

commit;


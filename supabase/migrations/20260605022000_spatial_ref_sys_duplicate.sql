begin;

do $$
begin
  create extension if not exists postgis;

  if to_regclass('public.spatial_ref_sys') is null then
    raise exception 'public.spatial_ref_sys does not exist (is PostGIS installed?)';
  end if;

  if to_regclass('public.spatial_ref_sys_duplicate') is null then
    execute 'create table public.spatial_ref_sys_duplicate (like public.spatial_ref_sys including all)';
  end if;

  execute 'insert into public.spatial_ref_sys_duplicate select * from public.spatial_ref_sys on conflict do nothing';
end;
$$;

alter table public.spatial_ref_sys_duplicate enable row level security;

drop policy if exists "spatial_ref_sys_duplicate_read_public" on public.spatial_ref_sys_duplicate;
create policy "spatial_ref_sys_duplicate_read_public"
on public.spatial_ref_sys_duplicate
for select
to public
using (true);

grant select on public.spatial_ref_sys_duplicate to public;

commit;

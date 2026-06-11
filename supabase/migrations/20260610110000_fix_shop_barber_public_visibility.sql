begin;

drop policy if exists "shops_public_read" on public.barbershops;
create policy "shops_public_read"
on public.barbershops
for select
to anon, authenticated
using (
  public.is_admin()
  or owner_profile_id = auth.uid()
  or (deleted_at is null and is_active = true and status = 'approved')
);

drop policy if exists "barbers_public_read" on public.barbers;
create policy "barbers_public_read"
on public.barbers
for select
to anon, authenticated
using (
  public.is_admin()
  or profile_id = auth.uid()
  or (
    shop_id is not null
    and exists (
      select 1
      from public.barbershops s
      where s.id = shop_id
        and s.owner_profile_id = auth.uid()
    )
  )
  or (
    deleted_at is null
    and is_active = true
    and status = 'approved'
    and (
      shop_id is null
      or exists (
        select 1
        from public.barbershops s
        where s.id = shop_id
          and s.deleted_at is null
          and s.is_active = true
          and s.status = 'approved'
      )
    )
  )
);

commit;

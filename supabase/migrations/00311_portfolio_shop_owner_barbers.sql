begin;

drop policy if exists "portfolio_items_shop_owner_manage_barbers" on public.portfolio_items;
create policy "portfolio_items_shop_owner_manage_barbers"
on public.portfolio_items
for all
to authenticated
using (
  owner_type = 'barber'
  and exists (
    select 1
    from public.barbers b
    join public.barbershops s on s.id = b.shop_id
    where b.id = owner_id
      and s.owner_profile_id = auth.uid()
  )
)
with check (
  owner_type = 'barber'
  and exists (
    select 1
    from public.barbers b
    join public.barbershops s on s.id = b.shop_id
    where b.id = owner_id
      and s.owner_profile_id = auth.uid()
  )
);

do $$
begin
  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_portfolio_write_owner" on storage.objects;
    create policy "storage_portfolio_write_owner"
    on storage.objects
    for insert
    to authenticated
    with check (
      bucket_id = 'portfolio'
      and (
        (
          split_part(name, '/', 1) = 'barbers'
          and (
            public.is_barber_owner((split_part(name, '/', 2))::uuid)
            or exists (
              select 1
              from public.barbers b
              join public.barbershops s on s.id = b.shop_id
              where b.id = (split_part(name, '/', 2))::uuid
                and s.owner_profile_id = auth.uid()
            )
          )
        )
        or
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner((split_part(name, '/', 2))::uuid)
        )
        or public.is_admin()
      )
    );

    drop policy if exists "storage_portfolio_update_owner" on storage.objects;
    create policy "storage_portfolio_update_owner"
    on storage.objects
    for update
    to authenticated
    using (
      bucket_id = 'portfolio'
      and (
        (
          split_part(name, '/', 1) = 'barbers'
          and (
            public.is_barber_owner((split_part(name, '/', 2))::uuid)
            or exists (
              select 1
              from public.barbers b
              join public.barbershops s on s.id = b.shop_id
              where b.id = (split_part(name, '/', 2))::uuid
                and s.owner_profile_id = auth.uid()
            )
          )
        )
        or
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner((split_part(name, '/', 2))::uuid)
        )
        or public.is_admin()
      )
    )
    with check (
      bucket_id = 'portfolio'
      and (
        (
          split_part(name, '/', 1) = 'barbers'
          and (
            public.is_barber_owner((split_part(name, '/', 2))::uuid)
            or exists (
              select 1
              from public.barbers b
              join public.barbershops s on s.id = b.shop_id
              where b.id = (split_part(name, '/', 2))::uuid
                and s.owner_profile_id = auth.uid()
            )
          )
        )
        or
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner((split_part(name, '/', 2))::uuid)
        )
        or public.is_admin()
      )
    );

    drop policy if exists "storage_portfolio_delete_owner" on storage.objects;
    create policy "storage_portfolio_delete_owner"
    on storage.objects
    for delete
    to authenticated
    using (
      bucket_id = 'portfolio'
      and (
        (
          split_part(name, '/', 1) = 'barbers'
          and (
            public.is_barber_owner((split_part(name, '/', 2))::uuid)
            or exists (
              select 1
              from public.barbers b
              join public.barbershops s on s.id = b.shop_id
              where b.id = (split_part(name, '/', 2))::uuid
                and s.owner_profile_id = auth.uid()
            )
          )
        )
        or
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner((split_part(name, '/', 2))::uuid)
        )
        or public.is_admin()
      )
    );
  end if;
end;
$$;

commit;

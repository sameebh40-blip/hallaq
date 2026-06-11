begin;

do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values
      ('awards', 'awards', true)
    on conflict (id) do nothing;
  end if;

  if to_regclass('storage.objects') is not null then
    begin
      execute 'alter table storage.objects enable row level security';
    exception
      when insufficient_privilege then
        null;
    end;

    drop policy if exists "storage_awards_public_read" on storage.objects;
    create policy "storage_awards_public_read"
    on storage.objects
    for select
    to anon, authenticated
    using (bucket_id in ('awards'));

    drop policy if exists "storage_awards_admin_all" on storage.objects;
    create policy "storage_awards_admin_all"
    on storage.objects
    for all
    to authenticated
    using (bucket_id in ('awards') and public.is_admin())
    with check (bucket_id in ('awards') and public.is_admin());

    drop policy if exists "storage_awards_owner_insert" on storage.objects;
    create policy "storage_awards_owner_insert"
    on storage.objects
    for insert
    to authenticated
    with check (
      bucket_id in ('awards')
      and (
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner(split_part(name, '/', 2)::uuid)
        )
        or
        (
          split_part(name, '/', 1) = 'barbers'
          and public.is_barber_owner(split_part(name, '/', 2)::uuid)
        )
      )
    );

    drop policy if exists "storage_awards_owner_update" on storage.objects;
    create policy "storage_awards_owner_update"
    on storage.objects
    for update
    to authenticated
    using (
      bucket_id in ('awards')
      and (
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner(split_part(name, '/', 2)::uuid)
        )
        or
        (
          split_part(name, '/', 1) = 'barbers'
          and public.is_barber_owner(split_part(name, '/', 2)::uuid)
        )
      )
    )
    with check (
      bucket_id in ('awards')
      and (
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner(split_part(name, '/', 2)::uuid)
        )
        or
        (
          split_part(name, '/', 1) = 'barbers'
          and public.is_barber_owner(split_part(name, '/', 2)::uuid)
        )
      )
    );

    drop policy if exists "storage_awards_owner_delete" on storage.objects;
    create policy "storage_awards_owner_delete"
    on storage.objects
    for delete
    to authenticated
    using (
      bucket_id in ('awards')
      and (
        (
          split_part(name, '/', 1) = 'shops'
          and public.is_shop_owner(split_part(name, '/', 2)::uuid)
        )
        or
        (
          split_part(name, '/', 1) = 'barbers'
          and public.is_barber_owner(split_part(name, '/', 2)::uuid)
        )
      )
    );
  end if;
end;
$$;

commit;

begin;

do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values
      ('shop-images', 'shop-images', true),
      ('barber-images', 'barber-images', true),
      ('review-images', 'review-images', true)
    on conflict (id) do nothing;
  end if;

  if to_regclass('storage.objects') is not null then
    begin
      execute 'alter table storage.objects enable row level security';
    exception
      when insufficient_privilege then
        null;
    end;

    drop policy if exists "storage_public_read_shop_barber_review" on storage.objects;
    create policy "storage_public_read_shop_barber_review"
    on storage.objects
    for select
    to anon, authenticated
    using (bucket_id in ('shop-images','barber-images','review-images'));

    drop policy if exists "storage_admin_write_shop_barber_review" on storage.objects;
    create policy "storage_admin_write_shop_barber_review"
    on storage.objects
    for all
    to authenticated
    using (bucket_id in ('shop-images','barber-images','review-images') and public.is_admin())
    with check (bucket_id in ('shop-images','barber-images','review-images') and public.is_admin());
  end if;
end;
$$;

commit;

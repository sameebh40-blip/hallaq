begin;

do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values
      ('avatars', 'avatars', true),
      ('barber-images', 'barber-images', true),
      ('shop-images', 'shop-images', true),
      ('portfolio', 'portfolio', true),
      ('reels', 'reels', true),
      ('reels-media', 'reels-media', true),
      ('review-photos', 'review-photos', true),
      ('haircut-history', 'haircut-history', true),
      ('service-images', 'service-images', true),
      ('products', 'products', true)
    on conflict (id) do nothing;
  end if;
end;
$$;

commit;

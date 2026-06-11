begin;

update public.profiles
set avatar_path = regexp_replace(avatar_url, '^.*?/storage/v1/object/public/avatars/', ''),
    avatar_url = null
where avatar_path is null
  and avatar_url is not null
  and avatar_url ~ '^https?://'
  and avatar_url like '%/storage/v1/object/public/avatars/%';

update public.profiles
set cover_path = regexp_replace(cover_url, '^.*?/storage/v1/object/public/avatars/', ''),
    cover_url = null
where cover_path is null
  and cover_url is not null
  and cover_url ~ '^https?://'
  and cover_url like '%/storage/v1/object/public/avatars/%';

update public.profiles
set avatar_path = avatar_url,
    avatar_url = null
where avatar_path is null
  and avatar_url is not null
  and avatar_url !~ '^https?://';

update public.profiles
set cover_path = cover_url,
    cover_url = null
where cover_path is null
  and cover_url is not null
  and cover_url !~ '^https?://';

update public.barbers
set avatar_path = regexp_replace(avatar_url, '^.*?/storage/v1/object/public/barber-images/', ''),
    avatar_url = null
where avatar_path is null
  and avatar_url is not null
  and avatar_url ~ '^https?://'
  and avatar_url like '%/storage/v1/object/public/barber-images/%';

update public.barbers
set cover_path = regexp_replace(cover_url, '^.*?/storage/v1/object/public/barber-images/', ''),
    cover_url = null
where cover_path is null
  and cover_url is not null
  and cover_url ~ '^https?://'
  and cover_url like '%/storage/v1/object/public/barber-images/%';

update public.barbers
set avatar_path = avatar_url,
    avatar_url = null
where avatar_path is null
  and avatar_url is not null
  and avatar_url !~ '^https?://';

update public.barbers
set cover_path = cover_url,
    cover_url = null
where cover_path is null
  and cover_url is not null
  and cover_url !~ '^https?://';

update public.barbershops
set logo_path = regexp_replace(logo_url, '^.*?/storage/v1/object/public/shop-images/', ''),
    logo_url = null
where logo_path is null
  and logo_url is not null
  and logo_url ~ '^https?://'
  and logo_url like '%/storage/v1/object/public/shop-images/%';

update public.barbershops
set cover_path = regexp_replace(cover_url, '^.*?/storage/v1/object/public/shop-images/', ''),
    cover_url = null
where cover_path is null
  and cover_url is not null
  and cover_url ~ '^https?://'
  and cover_url like '%/storage/v1/object/public/shop-images/%';

update public.barbershops
set logo_path = logo_url,
    logo_url = null
where logo_path is null
  and logo_url is not null
  and logo_url !~ '^https?://';

update public.barbershops
set cover_path = cover_url,
    cover_url = null
where cover_path is null
  and cover_url is not null
  and cover_url !~ '^https?://';

update public.reels
set media_path = regexp_replace(media_url, '^.*?/storage/v1/object/public/reels-media/', ''),
    media_url = null
where media_path is null
  and media_url is not null
  and media_url ~ '^https?://'
  and media_url like '%/storage/v1/object/public/reels-media/%';

update public.reels
set thumbnail_path = regexp_replace(thumbnail_url, '^.*?/storage/v1/object/public/reels-media/', ''),
    thumbnail_url = null
where thumbnail_path is null
  and thumbnail_url is not null
  and thumbnail_url ~ '^https?://'
  and thumbnail_url like '%/storage/v1/object/public/reels-media/%';

update public.reels
set media_path = media_url,
    media_url = null
where media_path is null
  and media_url is not null
  and media_url !~ '^https?://';

update public.reels
set thumbnail_path = thumbnail_url,
    thumbnail_url = null
where thumbnail_path is null
  and thumbnail_url is not null
  and thumbnail_url !~ '^https?://';

update public.portfolio_items
set media_path = regexp_replace(media_url, '^.*?/storage/v1/object/public/portfolio/', ''),
    media_url = null
where media_path is null
  and media_url is not null
  and media_url ~ '^https?://'
  and media_url like '%/storage/v1/object/public/portfolio/%';

update public.portfolio_items
set thumbnail_path = regexp_replace(thumbnail_url, '^.*?/storage/v1/object/public/portfolio/', ''),
    thumbnail_url = null
where thumbnail_path is null
  and thumbnail_url is not null
  and thumbnail_url ~ '^https?://'
  and thumbnail_url like '%/storage/v1/object/public/portfolio/%';

update public.portfolio_items
set media_path = media_url,
    media_url = null
where media_path is null
  and media_url is not null
  and media_url !~ '^https?://';

update public.portfolio_items
set thumbnail_path = thumbnail_url,
    thumbnail_url = null
where thumbnail_path is null
  and thumbnail_url is not null
  and thumbnail_url !~ '^https?://';

update public.reviews
set image_path = regexp_replace(image_url, '^.*?/storage/v1/object/public/review-photos/', ''),
    image_url = null
where image_path is null
  and image_url is not null
  and image_url ~ '^https?://'
  and image_url like '%/storage/v1/object/public/review-photos/%';

update public.reviews
set image_path = regexp_replace(photo_url, '^.*?/storage/v1/object/public/review-photos/', ''),
    photo_url = null
where image_path is null
  and photo_url is not null
  and photo_url ~ '^https?://'
  and photo_url like '%/storage/v1/object/public/review-photos/%';

update public.reviews
set image_path = image_url,
    image_url = null
where image_path is null
  and image_url is not null
  and image_url !~ '^https?://';

update public.reviews
set image_path = photo_url,
    photo_url = null
where image_path is null
  and photo_url is not null
  and photo_url !~ '^https?://';

commit;


begin;

alter table public.products
  add column if not exists image_url text;

update public.products
set image_url = nullif(images[1], '')
where image_url is null
  and coalesce(array_length(images, 1), 0) >= 1;

commit;

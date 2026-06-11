begin;

drop function if exists public.create_booking(uuid, timestamptz, uuid, uuid, text);
drop function if exists public.create_booking(uuid, timestamptz, uuid, uuid, text, text);

commit;


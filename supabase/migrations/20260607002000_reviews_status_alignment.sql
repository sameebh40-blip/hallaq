begin;

create or replace function public.recompute_target_rating(target_type text, target_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_avg numeric(3,2);
  v_count int;
begin
  select coalesce(avg(r.rating),0)::numeric(3,2), count(*)::int
  into v_avg, v_count
  from public.reviews r
  where r.target_type = target_type
    and r.target_id = target_id
    and r.status = 'approved'
    and r.is_active = true
    and r.is_verified = true;

  if target_type = 'barber' then
    update public.barbers
    set rating_avg = v_avg,
        rating_count = v_count,
        reviews_count = v_count
    where id = target_id;
  elsif target_type = 'shop' then
    update public.barbershops
    set rating_avg = v_avg,
        rating_count = v_count,
        reviews_count = v_count
    where id = target_id;
  end if;
end;
$$;

create or replace function public.recompute_all_ratings()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  rec record;
begin
  if not public.is_admin() then
    raise exception using message = 'FORBIDDEN';
  end if;

  for rec in
    select distinct target_type, target_id
    from public.reviews
    where status = 'approved'
      and is_active = true
      and is_verified = true
  loop
    perform public.recompute_target_rating(rec.target_type, rec.target_id);
  end loop;
end;
$$;

commit;


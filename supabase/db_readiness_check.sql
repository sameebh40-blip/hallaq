begin;

create temp table required_tables(name text primary key);
insert into required_tables(name) values
  ('profiles'),
  ('barbershops'),
  ('shop_branches'),
  ('shop_staff'),
  ('barbers'),
  ('services'),
  ('products'),
  ('bookings'),
  ('reels'),
  ('saved_items'),
  ('portfolio_items'),
  ('system_logs'),
  ('admin_audit_logs');

select name as missing_table
from required_tables
where to_regclass('public.' || name) is null
order by name;

create temp table required_columns(table_name text, column_name text);
insert into required_columns(table_name, column_name) values
  ('profiles','id'),
  ('profiles','role'),
  ('profiles','avatar_path'),
  ('profiles','cover_path'),
  ('barbershops','id'),
  ('barbershops','owner_profile_id'),
  ('barbershops','name'),
  ('barbershops','logo_path'),
  ('barbershops','cover_path'),
  ('shop_branches','id'),
  ('shop_branches','shop_id'),
  ('shop_branches','name'),
  ('shop_staff','id'),
  ('shop_staff','shop_id'),
  ('shop_staff','branch_id'),
  ('shop_staff','profile_id'),
  ('shop_staff','staff_role'),
  ('barbers','id'),
  ('barbers','profile_id'),
  ('barbers','shop_id'),
  ('barbers','avatar_path'),
  ('barbers','cover_path'),
  ('services','id'),
  ('services','shop_id'),
  ('services','barber_id'),
  ('services','name_en'),
  ('services','name_ar'),
  ('services','price_bhd'),
  ('services','duration_minutes'),
  ('services','image_url'),
  ('services','is_active'),
  ('products','id'),
  ('products','shop_id'),
  ('products','name'),
  ('products','description'),
  ('products','price'),
  ('products','stock'),
  ('products','image_url'),
  ('products','images'),
  ('products','active'),
  ('bookings','id'),
  ('bookings','shop_id'),
  ('bookings','barber_id'),
  ('bookings','service_id'),
  ('bookings','customer_profile_id'),
  ('bookings','start_at'),
  ('bookings','end_at'),
  ('bookings','price_bhd'),
  ('bookings','status'),
  ('bookings','branch_id'),
  ('reels','id'),
  ('reels','media_path'),
  ('reels','thumbnail_path'),
  ('reels','media_type'),
  ('reels','status'),
  ('saved_items','id'),
  ('saved_items','user_id'),
  ('saved_items','item_type'),
  ('saved_items','item_id'),
  ('portfolio_items','id'),
  ('portfolio_items','barber_id'),
  ('portfolio_items','media_path'),
  ('portfolio_items','thumbnail_path'),
  ('portfolio_items','status'),
  ('system_logs','id'),
  ('system_logs','user_id'),
  ('system_logs','page'),
  ('system_logs','action'),
  ('system_logs','error_message'),
  ('admin_audit_logs','id'),
  ('admin_audit_logs','admin_profile_id'),
  ('admin_audit_logs','action');

select rc.table_name, rc.column_name
from required_columns rc
left join information_schema.columns c
  on c.table_schema = 'public'
  and c.table_name = rc.table_name
  and c.column_name = rc.column_name
where c.column_name is null
order by rc.table_name, rc.column_name;

drop table if exists missing_buckets;
create temp table missing_buckets(name text primary key);

do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into missing_buckets(name)
    select v.name
    from (
      values
        ('avatars'),
        ('profile-covers'),
        ('reels'),
        ('barber-images'),
        ('shop-images')
    ) as v(name)
    where not exists (select 1 from storage.buckets b where b.id = v.name)
    on conflict (name) do nothing;
  end if;
end $$;

select name as missing_bucket
from missing_buckets
order by name;

commit;

begin;

create index if not exists bookings_barber_start_at_idx on public.bookings (barber_id, start_at);
create index if not exists bookings_customer_start_at_idx on public.bookings (customer_profile_id, start_at);
create index if not exists bookings_shop_start_at_idx on public.bookings (shop_id, start_at);
create index if not exists bookings_status_start_at_idx on public.bookings (status, start_at);

create index if not exists notifications_profile_read_created_idx on public.notifications (profile_id, read, created_at desc);

create index if not exists posts_barber_approved_active_created_idx on public.posts (barber_id, status, is_active, created_at desc);
create index if not exists posts_shop_approved_active_created_idx on public.posts (shop_id, status, is_active, created_at desc);

create index if not exists offer_targets_customer_status_created_idx on public.offer_targets (customer_profile_id, status, created_at desc);

commit;


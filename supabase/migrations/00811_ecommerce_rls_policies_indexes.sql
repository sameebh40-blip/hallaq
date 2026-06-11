begin;

alter view public.shop_revenue_daily set (security_invoker = true);

alter table public.products enable row level security;
drop policy if exists "products_public_read_0081" on public.products;
create policy "products_public_read_0081"
on public.products
for select
to anon, authenticated
using (active is true and deleted_at is null);

drop policy if exists "products_owner_all_0081" on public.products;
create policy "products_owner_all_0081"
on public.products
for all
to authenticated
using (public.is_admin() or public.is_shop_owner(shop_id))
with check (public.is_admin() or public.is_shop_owner(shop_id));

alter table public.product_categories enable row level security;
drop policy if exists "product_categories_public_read_0081" on public.product_categories;
create policy "product_categories_public_read_0081"
on public.product_categories
for select
to anon, authenticated
using (true);

drop policy if exists "product_categories_admin_write_0081" on public.product_categories;
create policy "product_categories_admin_write_0081"
on public.product_categories
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

alter table public.product_tags enable row level security;
drop policy if exists "product_tags_public_read_0081" on public.product_tags;
create policy "product_tags_public_read_0081"
on public.product_tags
for select
to anon, authenticated
using (true);

drop policy if exists "product_tags_admin_write_0081" on public.product_tags;
create policy "product_tags_admin_write_0081"
on public.product_tags
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

alter table public.product_tag_links enable row level security;
drop policy if exists "product_tag_links_public_read_0081" on public.product_tag_links;
create policy "product_tag_links_public_read_0081"
on public.product_tag_links
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.products p
    where p.id = product_tag_links.product_id
      and p.active is true
      and p.deleted_at is null
  )
);

drop policy if exists "product_tag_links_owner_all_0081" on public.product_tag_links;
create policy "product_tag_links_owner_all_0081"
on public.product_tag_links
for all
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.products p
    where p.id = product_tag_links.product_id
      and public.is_shop_owner(p.shop_id)
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.products p
    where p.id = product_tag_links.product_id
      and public.is_shop_owner(p.shop_id)
  )
);

alter table public.product_images enable row level security;
drop policy if exists "product_images_public_read_0081" on public.product_images;
create policy "product_images_public_read_0081"
on public.product_images
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.products p
    where p.id = product_images.product_id
      and p.active is true
      and p.deleted_at is null
  )
);

drop policy if exists "product_images_owner_all_0081" on public.product_images;
create policy "product_images_owner_all_0081"
on public.product_images
for all
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.products p
    where p.id = product_images.product_id
      and public.is_shop_owner(p.shop_id)
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.products p
    where p.id = product_images.product_id
      and public.is_shop_owner(p.shop_id)
  )
);

alter table public.product_options enable row level security;
drop policy if exists "product_options_public_read_0081" on public.product_options;
create policy "product_options_public_read_0081"
on public.product_options
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.products p
    where p.id = product_options.product_id
      and p.active is true
      and p.deleted_at is null
  )
);

drop policy if exists "product_options_owner_all_0081" on public.product_options;
create policy "product_options_owner_all_0081"
on public.product_options
for all
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.products p
    where p.id = product_options.product_id
      and public.is_shop_owner(p.shop_id)
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.products p
    where p.id = product_options.product_id
      and public.is_shop_owner(p.shop_id)
  )
);

alter table public.product_option_values enable row level security;
drop policy if exists "product_option_values_public_read_0081" on public.product_option_values;
create policy "product_option_values_public_read_0081"
on public.product_option_values
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.product_options o
    join public.products p on p.id = o.product_id
    where o.id = product_option_values.option_id
      and p.active is true
      and p.deleted_at is null
  )
);

drop policy if exists "product_option_values_owner_all_0081" on public.product_option_values;
create policy "product_option_values_owner_all_0081"
on public.product_option_values
for all
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.product_options o
    join public.products p on p.id = o.product_id
    where o.id = product_option_values.option_id
      and public.is_shop_owner(p.shop_id)
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.product_options o
    join public.products p on p.id = o.product_id
    where o.id = product_option_values.option_id
      and public.is_shop_owner(p.shop_id)
  )
);

alter table public.product_variants enable row level security;
drop policy if exists "product_variants_public_read_0081" on public.product_variants;
create policy "product_variants_public_read_0081"
on public.product_variants
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.products p
    where p.id = product_variants.product_id
      and p.active is true
      and p.deleted_at is null
  )
);

drop policy if exists "product_variants_owner_all_0081" on public.product_variants;
create policy "product_variants_owner_all_0081"
on public.product_variants
for all
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.products p
    where p.id = product_variants.product_id
      and public.is_shop_owner(p.shop_id)
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.products p
    where p.id = product_variants.product_id
      and public.is_shop_owner(p.shop_id)
  )
);

alter table public.product_variant_images enable row level security;
drop policy if exists "product_variant_images_public_read_0081" on public.product_variant_images;
create policy "product_variant_images_public_read_0081"
on public.product_variant_images
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.product_variants v
    join public.products p on p.id = v.product_id
    where v.id = product_variant_images.variant_id
      and p.active is true
      and p.deleted_at is null
  )
);

drop policy if exists "product_variant_images_owner_all_0081" on public.product_variant_images;
create policy "product_variant_images_owner_all_0081"
on public.product_variant_images
for all
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.product_variants v
    join public.products p on p.id = v.product_id
    where v.id = product_variant_images.variant_id
      and public.is_shop_owner(p.shop_id)
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.product_variants v
    join public.products p on p.id = v.product_id
    where v.id = product_variant_images.variant_id
      and public.is_shop_owner(p.shop_id)
  )
);

alter table public.product_variant_values enable row level security;
drop policy if exists "product_variant_values_public_read_0081" on public.product_variant_values;
create policy "product_variant_values_public_read_0081"
on public.product_variant_values
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.product_variants v
    join public.products p on p.id = v.product_id
    where v.id = product_variant_values.variant_id
      and p.active is true
      and p.deleted_at is null
  )
);

drop policy if exists "product_variant_values_owner_all_0081" on public.product_variant_values;
create policy "product_variant_values_owner_all_0081"
on public.product_variant_values
for all
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.product_variants v
    join public.products p on p.id = v.product_id
    where v.id = product_variant_values.variant_id
      and public.is_shop_owner(p.shop_id)
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.product_variants v
    join public.products p on p.id = v.product_id
    where v.id = product_variant_values.variant_id
      and public.is_shop_owner(p.shop_id)
  )
);

alter table public.cart_items enable row level security;
drop policy if exists "cart_items_owner_all_0081" on public.cart_items;
create policy "cart_items_owner_all_0081"
on public.cart_items
for all
to authenticated
using (public.is_admin() or profile_id = auth.uid())
with check (public.is_admin() or profile_id = auth.uid());

alter table public.orders enable row level security;
drop policy if exists "orders_admin_all_0081" on public.orders;
create policy "orders_admin_all_0081"
on public.orders
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "orders_customer_read_0081" on public.orders;
create policy "orders_customer_read_0081"
on public.orders
for select
to authenticated
using (customer_profile_id = auth.uid());

drop policy if exists "orders_customer_write_0081" on public.orders;
create policy "orders_customer_write_0081"
on public.orders
for insert
to authenticated
with check (customer_profile_id = auth.uid());

drop policy if exists "orders_customer_update_0081" on public.orders;
create policy "orders_customer_update_0081"
on public.orders
for update
to authenticated
using (customer_profile_id = auth.uid())
with check (customer_profile_id = auth.uid());

drop policy if exists "orders_shop_owner_read_0081" on public.orders;
create policy "orders_shop_owner_read_0081"
on public.orders
for select
to authenticated
using (public.is_shop_owner(shop_id));

drop policy if exists "orders_shop_owner_update_0081" on public.orders;
create policy "orders_shop_owner_update_0081"
on public.orders
for update
to authenticated
using (public.is_shop_owner(shop_id))
with check (public.is_shop_owner(shop_id));

alter table public.order_items enable row level security;
drop policy if exists "order_items_read_0081" on public.order_items;
create policy "order_items_read_0081"
on public.order_items
for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and (o.customer_profile_id = auth.uid() or public.is_shop_owner(o.shop_id))
  )
);

drop policy if exists "order_items_insert_0081" on public.order_items;
create policy "order_items_insert_0081"
on public.order_items
for insert
to authenticated
with check (
  public.is_admin()
  or exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and o.customer_profile_id = auth.uid()
  )
);

drop policy if exists "order_items_admin_write_0081" on public.order_items;
create policy "order_items_admin_write_0081"
on public.order_items
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

alter table public.order_refunds enable row level security;
drop policy if exists "order_refunds_read_0081" on public.order_refunds;
create policy "order_refunds_read_0081"
on public.order_refunds
for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.orders o
    where o.id = order_refunds.order_id
      and (o.customer_profile_id = auth.uid() or public.is_shop_owner(o.shop_id))
  )
);

drop policy if exists "order_refunds_insert_0081" on public.order_refunds;
create policy "order_refunds_insert_0081"
on public.order_refunds
for insert
to authenticated
with check (
  public.is_admin()
  or exists (
    select 1
    from public.orders o
    where o.id = order_refunds.order_id
      and o.customer_profile_id = auth.uid()
  )
);

drop policy if exists "order_refunds_admin_write_0081" on public.order_refunds;
create policy "order_refunds_admin_write_0081"
on public.order_refunds
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

alter table public.service_images enable row level security;
drop policy if exists "service_images_public_read_0081" on public.service_images;
create policy "service_images_public_read_0081"
on public.service_images
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.services s
    where s.id = service_images.service_id
      and coalesce(s.is_active, s.active, true) is true
      and s.deleted_at is null
  )
);

drop policy if exists "service_images_owner_all_0081" on public.service_images;
create policy "service_images_owner_all_0081"
on public.service_images
for all
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.services s
    where s.id = service_images.service_id
      and public.is_shop_owner(s.shop_id)
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.services s
    where s.id = service_images.service_id
      and public.is_shop_owner(s.shop_id)
  )
);

alter table public.service_templates enable row level security;
drop policy if exists "service_templates_read_0081" on public.service_templates;
create policy "service_templates_read_0081"
on public.service_templates
for select
to authenticated
using (true);

drop policy if exists "service_templates_admin_write_0081" on public.service_templates;
create policy "service_templates_admin_write_0081"
on public.service_templates
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

alter table public.service_template_images enable row level security;
drop policy if exists "service_template_images_read_0081" on public.service_template_images;
create policy "service_template_images_read_0081"
on public.service_template_images
for select
to authenticated
using (true);

drop policy if exists "service_template_images_admin_write_0081" on public.service_template_images;
create policy "service_template_images_admin_write_0081"
on public.service_template_images
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create index if not exists profiles_role_idx on public.profiles (role);
create index if not exists barbershops_owner_profile_id_idx on public.barbershops (owner_profile_id);
create index if not exists barbers_profile_id_idx on public.barbers (profile_id);
create index if not exists barbers_shop_id_idx on public.barbers (shop_id);
create index if not exists services_shop_id_idx on public.services (shop_id);
create index if not exists services_barber_id_idx on public.services (barber_id);
create index if not exists products_shop_id_idx on public.products (shop_id);
create index if not exists bookings_customer_profile_id_idx on public.bookings (customer_profile_id);
create index if not exists bookings_barber_id_idx on public.bookings (barber_id);
create index if not exists bookings_shop_id_idx on public.bookings (shop_id);
create index if not exists reels_shop_id_idx on public.reels (shop_id);
create index if not exists reels_barber_id_idx on public.reels (barber_id);
create index if not exists reels_status_idx on public.reels (status);
create index if not exists saved_items_user_id_idx on public.saved_items (user_id);
create index if not exists reviews_target_id_idx on public.reviews (target_id);

create index if not exists cart_items_profile_id_idx on public.cart_items (profile_id);
create index if not exists cart_items_product_id_idx on public.cart_items (product_id);
create index if not exists orders_customer_profile_id_idx on public.orders (customer_profile_id);
create index if not exists orders_shop_id_idx on public.orders (shop_id);
create index if not exists order_items_order_id_idx on public.order_items (order_id);
create index if not exists order_items_product_id_idx on public.order_items (product_id);
create index if not exists order_refunds_order_id_idx on public.order_refunds (order_id);

commit;

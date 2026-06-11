begin;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.barbershops (id) on delete cascade,
  name text not null,
  description text,
  price numeric(10,3) not null default 0,
  currency text not null default 'BHD',
  stock int not null default 0,
  images text[] not null default '{}'::text[],
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists products_shop_active_idx on public.products (shop_id, active, created_at desc);

drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at
before update on public.products
for each row execute function public.set_updated_at();

alter table public.products enable row level security;

drop policy if exists "products_public_read_active" on public.products;
create policy "products_public_read_active"
on public.products
for select
to anon, authenticated
using (active = true);

drop policy if exists "products_write_shop_owner" on public.products;
create policy "products_write_shop_owner"
on public.products
for all
to authenticated
using (public.is_shop_owner(shop_id) or public.is_admin())
with check (public.is_shop_owner(shop_id) or public.is_admin());

create table if not exists public.cart_items (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  quantity int not null default 1 check (quantity > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (profile_id, product_id)
);

create index if not exists cart_items_profile_idx on public.cart_items (profile_id, updated_at desc);

drop trigger if exists cart_items_set_updated_at on public.cart_items;
create trigger cart_items_set_updated_at
before update on public.cart_items
for each row execute function public.set_updated_at();

alter table public.cart_items enable row level security;

drop policy if exists "cart_items_read_own" on public.cart_items;
create policy "cart_items_read_own"
on public.cart_items
for select
to authenticated
using (profile_id = auth.uid());

drop policy if exists "cart_items_write_own" on public.cart_items;
create policy "cart_items_write_own"
on public.cart_items
for all
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_profile_id uuid not null references public.profiles (id) on delete cascade,
  shop_id uuid not null references public.barbershops (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','rejected','shipped','delivered','cancelled')),
  total_amount numeric(10,3) not null default 0,
  currency text not null default 'BHD',
  payment_method text not null default 'cod' check (payment_method in ('cod','card')),
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid','paid','failed','refunded')),
  payment_id uuid references public.payments (id) on delete set null,
  delivery_address jsonb not null default '{}'::jsonb,
  customer_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists orders_customer_created_idx on public.orders (customer_profile_id, created_at desc);
create index if not exists orders_shop_status_created_idx on public.orders (shop_id, status, created_at desc);

drop trigger if exists orders_set_updated_at on public.orders;
create trigger orders_set_updated_at
before update on public.orders
for each row execute function public.set_updated_at();

alter table public.orders enable row level security;

drop policy if exists "orders_read_participants" on public.orders;
create policy "orders_read_participants"
on public.orders
for select
to authenticated
using (
  customer_profile_id = auth.uid()
  or public.is_shop_owner(shop_id)
  or public.is_admin()
);

drop policy if exists "orders_insert_customer" on public.orders;
create policy "orders_insert_customer"
on public.orders
for insert
to authenticated
with check (customer_profile_id = auth.uid());

drop policy if exists "orders_update_shop_owner" on public.orders;
create policy "orders_update_shop_owner"
on public.orders
for update
to authenticated
using (public.is_shop_owner(shop_id) or public.is_admin())
with check (public.is_shop_owner(shop_id) or public.is_admin());

drop policy if exists "orders_update_customer_cancel" on public.orders;
create policy "orders_update_customer_cancel"
on public.orders
for update
to authenticated
using (customer_profile_id = auth.uid())
with check (customer_profile_id = auth.uid() and status = 'cancelled');

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete restrict,
  quantity int not null default 1 check (quantity > 0),
  unit_price numeric(10,3) not null default 0,
  line_total numeric(10,3) not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists order_items_order_idx on public.order_items (order_id);

alter table public.order_items enable row level security;

drop policy if exists "order_items_read_participants" on public.order_items;
create policy "order_items_read_participants"
on public.order_items
for select
to authenticated
using (
  exists (select 1 from public.orders o where o.id = order_id and (o.customer_profile_id = auth.uid() or public.is_shop_owner(o.shop_id) or public.is_admin()))
);

drop policy if exists "order_items_insert_customer" on public.order_items;
create policy "order_items_insert_customer"
on public.order_items
for insert
to authenticated
with check (
  exists (select 1 from public.orders o where o.id = order_id and o.customer_profile_id = auth.uid() and o.status = 'pending')
);

create or replace function public.recompute_order_total(p_order_id uuid)
returns void
language plpgsql
as $$
declare
  new_total numeric(10,3);
begin
  select coalesce(sum(oi.line_total), 0)
  into new_total
  from public.order_items oi
  where oi.order_id = p_order_id;

  update public.orders
  set total_amount = new_total
  where id = p_order_id;
end;
$$;

create or replace function public.order_items_sync_totals()
returns trigger
language plpgsql
as $$
declare
  p_price numeric(10,3);
begin
  select p.price into p_price from public.products p where p.id = new.product_id;
  new.unit_price := coalesce(p_price, 0);
  new.line_total := new.unit_price * new.quantity;
  return new;
end;
$$;

drop trigger if exists order_items_sync_totals on public.order_items;
create trigger order_items_sync_totals
before insert or update on public.order_items
for each row execute function public.order_items_sync_totals();

create or replace function public.on_order_items_changed()
returns trigger
language plpgsql
as $$
declare
  oid uuid;
begin
  oid := coalesce(new.order_id, old.order_id);
  if oid is not null then
    perform public.recompute_order_total(oid);
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists order_items_recompute_total on public.order_items;
create trigger order_items_recompute_total
after insert or update or delete on public.order_items
for each row execute function public.on_order_items_changed();

create or replace function public.on_order_inserted()
returns trigger
language plpgsql
as $$
declare
  shop_owner uuid;
begin
  perform public.notify(new.customer_profile_id, 'order_created', 'Order placed', 'Your order was placed successfully', jsonb_build_object('order_id', new.id, 'status', new.status));

  select s.owner_profile_id into shop_owner from public.barbershops s where s.id = new.shop_id;
  if shop_owner is not null then
    perform public.notify(shop_owner, 'order_new', 'New order', 'You have a new order', jsonb_build_object('order_id', new.id, 'status', new.status));
  end if;

  return new;
end;
$$;

drop trigger if exists orders_notify_insert on public.orders;
create trigger orders_notify_insert
after insert on public.orders
for each row execute function public.on_order_inserted();

create or replace function public.on_order_status_changed()
returns trigger
language plpgsql
as $$
declare
  shop_owner uuid;
begin
  if old.status is distinct from new.status then
    perform public.notify(new.customer_profile_id, 'order_status', 'Order update', 'Your order status changed to ' || new.status, jsonb_build_object('order_id', new.id, 'status', new.status));

    select s.owner_profile_id into shop_owner from public.barbershops s where s.id = new.shop_id;
    if shop_owner is not null then
      perform public.notify(shop_owner, 'order_status', 'Order update', 'Order status changed to ' || new.status, jsonb_build_object('order_id', new.id, 'status', new.status));
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists orders_notify_status on public.orders;
create trigger orders_notify_status
after update on public.orders
for each row execute function public.on_order_status_changed();

do $$
begin
  if to_regclass('storage.objects') is not null then
    drop policy if exists "storage_public_read" on storage.objects;
    create policy "storage_public_read"
    on storage.objects
    for select
    to anon, authenticated
    using (bucket_id in ('avatars','portfolio','reels-media','review-photos','haircut-history','service-images','shop-images','barber-images','post-media','review-images','products'));

    drop policy if exists "storage_products_write_shop_owner" on storage.objects;
    create policy "storage_products_write_shop_owner"
    on storage.objects
    for insert
    to authenticated
    with check (
      bucket_id = 'products'
      and split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner((split_part(name, '/', 2))::uuid)
    );

    drop policy if exists "storage_products_update_shop_owner" on storage.objects;
    create policy "storage_products_update_shop_owner"
    on storage.objects
    for update
    to authenticated
    using (
      bucket_id = 'products'
      and split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner((split_part(name, '/', 2))::uuid)
    )
    with check (
      bucket_id = 'products'
      and split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner((split_part(name, '/', 2))::uuid)
    );

    drop policy if exists "storage_products_delete_shop_owner" on storage.objects;
    create policy "storage_products_delete_shop_owner"
    on storage.objects
    for delete
    to authenticated
    using (
      bucket_id = 'products'
      and split_part(name, '/', 1) = 'shops'
      and public.is_shop_owner((split_part(name, '/', 2))::uuid)
    );

    drop policy if exists "storage_products_admin_all" on storage.objects;
    create policy "storage_products_admin_all"
    on storage.objects
    for all
    to authenticated
    using (bucket_id = 'products' and public.is_admin())
    with check (bucket_id = 'products' and public.is_admin());
  end if;
end;
$$;

commit;

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $set_updated_at$
begin
  new.updated_at := now();
  return new;
end;
$set_updated_at$;

create table if not exists public.product_categories (
  id uuid primary key default gen_random_uuid(),
  name_en text not null,
  name_ar text,
  created_at timestamptz not null default now()
);

create table if not exists public.product_tags (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

do $do$
begin
  if to_regclass('public.barbershops') is not null and to_regclass('public.products') is null then
    execute $sql$
      create table public.products (
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
      )
    $sql$;

    execute $sql$
      create index if not exists products_shop_active_idx
      on public.products (shop_id, active, created_at desc)
    $sql$;

    execute $sql$
      drop trigger if exists products_set_updated_at on public.products
    $sql$;

    execute $sql$
      create trigger products_set_updated_at
      before update on public.products
      for each row execute function public.set_updated_at()
    $sql$;
  end if;

  if to_regclass('public.products') is not null then
    execute $sql$
      alter table public.products
        add column if not exists deleted_at timestamptz,
        add column if not exists sku text,
        add column if not exists category_id uuid references public.product_categories (id) on delete set null
    $sql$;

    execute $sql$
      create table if not exists public.product_tag_links (
        product_id uuid not null references public.products (id) on delete cascade,
        tag_id uuid not null references public.product_tags (id) on delete cascade,
        created_at timestamptz not null default now(),
        primary key (product_id, tag_id)
      )
    $sql$;

    execute $sql$
      create table if not exists public.product_images (
        id uuid primary key default gen_random_uuid(),
        product_id uuid not null references public.products (id) on delete cascade,
        storage_path text not null,
        public_url text not null,
        position int not null default 0,
        is_primary boolean not null default false,
        created_at timestamptz not null default now()
      )
    $sql$;

    execute $sql$
      create unique index if not exists product_images_one_primary_idx
      on public.product_images (product_id) where is_primary
    $sql$;

    execute $sql$
      create index if not exists product_images_product_pos_idx
      on public.product_images (product_id, position asc, created_at asc)
    $sql$;

    execute $sql$
      create table if not exists public.product_options (
        id uuid primary key default gen_random_uuid(),
        product_id uuid not null references public.products (id) on delete cascade,
        name_en text not null,
        name_ar text,
        position int not null default 0,
        created_at timestamptz not null default now()
      )
    $sql$;

    execute $sql$
      create index if not exists product_options_product_pos_idx
      on public.product_options (product_id, position asc)
    $sql$;

    execute $sql$
      create table if not exists public.product_option_values (
        id uuid primary key default gen_random_uuid(),
        option_id uuid not null references public.product_options (id) on delete cascade,
        value_en text not null,
        value_ar text,
        position int not null default 0,
        created_at timestamptz not null default now()
      )
    $sql$;

    execute $sql$
      create index if not exists product_option_values_option_pos_idx
      on public.product_option_values (option_id, position asc)
    $sql$;

    execute $sql$
      create table if not exists public.product_variants (
        id uuid primary key default gen_random_uuid(),
        product_id uuid not null references public.products (id) on delete cascade,
        sku text,
        signature text,
        price numeric(10,3),
        stock int not null default 0,
        active boolean not null default true,
        created_at timestamptz not null default now(),
        updated_at timestamptz not null default now(),
        unique (product_id, sku),
        unique (product_id, signature)
      )
    $sql$;

    execute $sql$
      drop trigger if exists product_variants_set_updated_at on public.product_variants
    $sql$;

    execute $sql$
      create trigger product_variants_set_updated_at
      before update on public.product_variants
      for each row execute function public.set_updated_at()
    $sql$;

    execute $sql$
      create index if not exists product_variants_product_active_idx
      on public.product_variants (product_id, active, created_at desc)
    $sql$;

    execute $sql$
      create table if not exists public.product_variant_values (
        variant_id uuid not null references public.product_variants (id) on delete cascade,
        option_value_id uuid not null references public.product_option_values (id) on delete cascade,
        created_at timestamptz not null default now(),
        primary key (variant_id, option_value_id)
      )
    $sql$;

    execute $sql$
      create index if not exists product_variant_values_value_idx
      on public.product_variant_values (option_value_id)
    $sql$;

    execute $sql$
      create table if not exists public.product_variant_images (
        id uuid primary key default gen_random_uuid(),
        variant_id uuid not null references public.product_variants (id) on delete cascade,
        storage_path text not null,
        public_url text not null,
        position int not null default 0,
        is_primary boolean not null default false,
        created_at timestamptz not null default now()
      )
    $sql$;

    execute $sql$
      create unique index if not exists product_variant_images_one_primary_idx
      on public.product_variant_images (variant_id) where is_primary
    $sql$;

    execute $sql$
      create index if not exists product_variant_images_variant_pos_idx
      on public.product_variant_images (variant_id, position asc, created_at asc)
    $sql$;
  end if;
end
$do$;

do $do$
begin
  if to_regclass('public.cart_items') is null
     and to_regclass('public.profiles') is not null
     and to_regclass('public.products') is not null
     and to_regclass('public.product_variants') is not null then
    execute $sql$
      create table public.cart_items (
        id uuid primary key default gen_random_uuid(),
        profile_id uuid not null references public.profiles (id) on delete cascade,
        product_id uuid not null references public.products (id) on delete cascade,
        variant_id uuid references public.product_variants (id) on delete restrict,
        quantity int not null default 1 check (quantity > 0),
        created_at timestamptz not null default now(),
        updated_at timestamptz not null default now()
      )
    $sql$;

    execute $sql$
      create index if not exists cart_items_profile_idx
      on public.cart_items (profile_id, updated_at desc)
    $sql$;

    execute $sql$
      drop trigger if exists cart_items_set_updated_at on public.cart_items
    $sql$;

    execute $sql$
      create trigger cart_items_set_updated_at
      before update on public.cart_items
      for each row execute function public.set_updated_at()
    $sql$;
  end if;
end
$do$;

do $do$
begin
  if to_regclass('public.cart_items') is not null and to_regclass('public.product_variants') is not null then
    execute $sql$
      alter table public.cart_items
        add column if not exists variant_id uuid references public.product_variants (id) on delete restrict
    $sql$;

    execute $sql$
      alter table public.cart_items
        drop constraint if exists cart_items_profile_id_product_id_key
    $sql$;

    if not exists (
      select 1
      from pg_constraint c
      where c.conname = 'cart_items_profile_product_variant_unique'
        and c.conrelid = 'public.cart_items'::regclass
    ) then
      execute $sql$
        alter table public.cart_items
          add constraint cart_items_profile_product_variant_unique unique (profile_id, product_id, variant_id)
      $sql$;
    end if;
  end if;
end
$do$;

do $do$
begin
  if to_regclass('public.orders') is null and to_regclass('public.profiles') is not null and to_regclass('public.barbershops') is not null then
    execute $sql$
      create table public.orders (
        id uuid primary key default gen_random_uuid(),
        customer_profile_id uuid not null references public.profiles (id) on delete cascade,
        shop_id uuid not null references public.barbershops (id) on delete cascade,
        status text not null default 'pending',
        total_amount numeric(10,3) not null default 0,
        currency text not null default 'BHD',
        payment_method text not null default 'cod',
        payment_status text not null default 'unpaid',
        payment_id uuid,
        delivery_address jsonb not null default '{}'::jsonb,
        customer_note text,
        stock_decremented boolean not null default false,
        created_at timestamptz not null default now(),
        updated_at timestamptz not null default now()
      )
    $sql$;

    execute $sql$
      create index if not exists orders_customer_created_idx
      on public.orders (customer_profile_id, created_at desc)
    $sql$;

    execute $sql$
      create index if not exists orders_shop_status_created_idx
      on public.orders (shop_id, status, created_at desc)
    $sql$;

    execute $sql$
      drop trigger if exists orders_set_updated_at on public.orders
    $sql$;

    execute $sql$
      create trigger orders_set_updated_at
      before update on public.orders
      for each row execute function public.set_updated_at()
    $sql$;
  end if;
end
$do$;

do $do$
begin
  if to_regclass('public.orders') is not null then
    execute $sql$
      alter table public.orders
        drop constraint if exists orders_status_check
    $sql$;

    execute $sql$
      alter table public.orders
        add constraint orders_status_check
        check (status in ('pending','accepted','processing','rejected','shipped','delivered','cancelled','refunded'))
    $sql$;
  end if;
end
$do$;

do $do$
begin
  if to_regclass('public.order_items') is null
     and to_regclass('public.orders') is not null
     and to_regclass('public.products') is not null
     and to_regclass('public.product_variants') is not null then
    execute $sql$
      create table public.order_items (
        id uuid primary key default gen_random_uuid(),
        order_id uuid not null references public.orders (id) on delete cascade,
        product_id uuid not null references public.products (id) on delete restrict,
        variant_id uuid references public.product_variants (id) on delete restrict,
        quantity int not null default 1 check (quantity > 0),
        unit_price numeric(10,3) not null default 0,
        line_total numeric(10,3) not null default 0,
        product_name text,
        variant_label text,
        currency text not null default 'BHD',
        created_at timestamptz not null default now()
      )
    $sql$;

    execute $sql$
      create index if not exists order_items_order_idx
      on public.order_items (order_id)
    $sql$;
  end if;
end
$do$;

do $do$
begin
  if to_regclass('public.order_items') is not null and to_regclass('public.product_variants') is not null then
    execute $sql$
      alter table public.order_items
        add column if not exists variant_id uuid references public.product_variants (id) on delete restrict,
        add column if not exists product_name text,
        add column if not exists variant_label text,
        add column if not exists currency text not null default 'BHD'
    $sql$;
  end if;
end
$do$;

create or replace function public.order_items_sync_totals()
returns trigger
language plpgsql
as $order_items_sync_totals$
declare
  p_price numeric(10,3);
  v_price numeric(10,3);
  p_name text;
begin
  select p.price, p.name
  into p_price, p_name
  from public.products p
  where p.id = new.product_id;

  if new.variant_id is not null then
    select pv.price
    into v_price
    from public.product_variants pv
    where pv.id = new.variant_id;
  end if;

  new.unit_price := coalesce(v_price, p_price, 0);
  new.line_total := new.unit_price * new.quantity;
  new.product_name := coalesce(new.product_name, p_name);
  return new;
end;
$order_items_sync_totals$;

do $do$
begin
  if to_regclass('public.order_items') is not null then
    execute $sql$
      drop trigger if exists order_items_sync_totals on public.order_items
    $sql$;

    execute $sql$
      create trigger order_items_sync_totals
      before insert or update on public.order_items
      for each row execute function public.order_items_sync_totals()
    $sql$;
  end if;
end
$do$;

create or replace function public.on_order_refunded()
returns trigger
language plpgsql
as $on_order_refunded$
declare
  it record;
begin
  update public.orders
  set payment_status = 'refunded',
      status = 'refunded'
  where id = new.order_id;

  if new.restock then
    for it in
      select oi.product_id, oi.variant_id, oi.quantity
      from public.order_items oi
      where oi.order_id = new.order_id
    loop
      if it.variant_id is not null then
        update public.product_variants
        set stock = stock + greatest(it.quantity, 0)
        where id = it.variant_id;
      else
        update public.products
        set stock = stock + greatest(it.quantity, 0)
        where id = it.product_id;
      end if;
    end loop;
  end if;

  return new;
end;
$on_order_refunded$;

do $do$
begin
  if to_regclass('public.orders') is not null
     and to_regclass('public.profiles') is not null
     and to_regclass('public.order_items') is not null then
    execute $sql$
      create table if not exists public.order_refunds (
        id uuid primary key default gen_random_uuid(),
        order_id uuid not null references public.orders (id) on delete cascade,
        amount numeric(10,3) not null default 0,
        currency text not null default 'BHD',
        reason text,
        restock boolean not null default false,
        created_by uuid references public.profiles (id) on delete set null,
        created_at timestamptz not null default now()
      )
    $sql$;

    execute $sql$
      create index if not exists order_refunds_order_created_idx
      on public.order_refunds (order_id, created_at desc)
    $sql$;

    execute $sql$
      drop trigger if exists order_refunds_apply on public.order_refunds
    $sql$;

    execute $sql$
      create trigger order_refunds_apply
      after insert on public.order_refunds
      for each row execute function public.on_order_refunded()
    $sql$;
  end if;
end
$do$;

create or replace function public.services_sync_primary_image()
returns trigger
language plpgsql
as $services_sync_primary_image$
begin
  if new.is_primary then
    update public.service_images
    set is_primary = false
    where service_id = new.service_id
      and id <> new.id
      and is_primary = true;

    update public.services
    set image_url = new.public_url
    where id = new.service_id;
  end if;

  return new;
end;
$services_sync_primary_image$;

do $do$
begin
  if to_regclass('public.services') is not null then
    execute $sql$
      create table if not exists public.service_images (
        id uuid primary key default gen_random_uuid(),
        service_id uuid not null references public.services (id) on delete cascade,
        storage_path text not null,
        public_url text not null,
        position int not null default 0,
        is_primary boolean not null default false,
        created_at timestamptz not null default now()
      )
    $sql$;

    execute $sql$
      create unique index if not exists service_images_one_primary_idx
      on public.service_images (service_id) where is_primary
    $sql$;

    execute $sql$
      create index if not exists service_images_service_pos_idx
      on public.service_images (service_id, position asc, created_at asc)
    $sql$;

    execute $sql$
      drop trigger if exists service_images_sync_primary on public.service_images
    $sql$;

    execute $sql$
      create trigger service_images_sync_primary
      after insert or update on public.service_images
      for each row execute function public.services_sync_primary_image()
    $sql$;
  end if;
end
$do$;

do $do$
begin
  if to_regclass('public.profiles') is not null then
    execute $sql$
      create table if not exists public.service_templates (
        id uuid primary key default gen_random_uuid(),
        name_en text not null,
        name_ar text,
        description_en text,
        description_ar text,
        price_bhd numeric(10,3) not null default 0,
        duration_minutes int not null default 30,
        category text,
        deposit_type text,
        deposit_value numeric(10,3),
        created_by uuid references public.profiles (id) on delete set null,
        created_at timestamptz not null default now()
      )
    $sql$;

    execute $sql$
      alter table public.service_templates
        drop constraint if exists service_templates_deposit_type_check
    $sql$;

    execute $sql$
      alter table public.service_templates
        add constraint service_templates_deposit_type_check
        check (deposit_type is null or deposit_type in ('fixed','percent'))
    $sql$;

    execute $sql$
      create index if not exists service_templates_created_at_idx
      on public.service_templates (created_at desc)
    $sql$;

    execute $sql$
      create table if not exists public.service_template_images (
        id uuid primary key default gen_random_uuid(),
        template_id uuid not null references public.service_templates (id) on delete cascade,
        storage_path text not null,
        public_url text not null,
        position int not null default 0,
        is_primary boolean not null default false,
        created_at timestamptz not null default now()
      )
    $sql$;

    execute $sql$
      create unique index if not exists service_template_images_one_primary_idx
      on public.service_template_images (template_id) where is_primary
    $sql$;

    execute $sql$
      create index if not exists service_template_images_template_pos_idx
      on public.service_template_images (template_id, position asc, created_at asc)
    $sql$;
  end if;
end
$do$;

create or replace function public.orders_decrement_stock_on_delivered()
returns trigger
language plpgsql
as $orders_decrement_stock_on_delivered$
declare
  it record;
begin
  if new.status = 'delivered' and old.status is distinct from new.status then
    if coalesce(new.stock_decremented, false) = true then
      return new;
    end if;

    for it in
      select oi.product_id, oi.variant_id, oi.quantity
      from public.order_items oi
      where oi.order_id = new.id
    loop
      if it.variant_id is not null then
        update public.product_variants
        set stock = greatest(stock - it.quantity, 0)
        where id = it.variant_id;
      else
        update public.products
        set stock = greatest(stock - it.quantity, 0)
        where id = it.product_id;
      end if;
    end loop;

    update public.orders set stock_decremented = true where id = new.id;
  end if;
  return new;
end;
$orders_decrement_stock_on_delivered$;

do $do$
begin
  if to_regclass('public.orders') is not null then
    execute $sql$
      drop trigger if exists orders_decrement_stock_on_delivered on public.orders
    $sql$;

    execute $sql$
      create trigger orders_decrement_stock_on_delivered
      after update on public.orders
      for each row execute function public.orders_decrement_stock_on_delivered()
    $sql$;
  end if;
end
$do$;

commit;

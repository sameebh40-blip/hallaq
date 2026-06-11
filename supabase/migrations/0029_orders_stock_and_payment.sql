begin;

alter table public.orders
add column if not exists stock_decremented boolean not null default false;

create or replace function public.decrement_stock_for_order(p_order_id uuid)
returns void
language plpgsql
as $$
begin
  update public.products p
  set stock = greatest(p.stock - oi.quantity, 0),
      updated_at = now()
  from public.order_items oi
  where oi.order_id = p_order_id
    and oi.product_id = p.id;
end;
$$;

create or replace function public.on_order_status_stock_decrement()
returns trigger
language plpgsql
as $$
begin
  if old.stock_decremented = false and new.status = 'delivered' then
    perform public.decrement_stock_for_order(new.id);
    new.stock_decremented := true;
  end if;
  return new;
end;
$$;

drop trigger if exists orders_stock_decrement_on_delivered on public.orders;
create trigger orders_stock_decrement_on_delivered
before update of status on public.orders
for each row execute function public.on_order_status_stock_decrement();

commit;


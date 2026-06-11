import { createSupabaseServerClient } from "@hallaq/supabase/server";

function csvEscape(value: unknown) {
  const s = String(value ?? "");
  if (s.includes('"') || s.includes(",") || s.includes("\n") || s.includes("\r")) {
    return `"${s.replaceAll('"', '""')}"`;
  }
  return s;
}

export async function GET() {
  const supabase = await createSupabaseServerClient();

  const { data: orders, error: ordersError } = await supabase
    .from("orders")
    .select("id, shop_id, customer_profile_id, status, total_amount, currency, payment_method, payment_status, created_at")
    .order("created_at", { ascending: false })
    .limit(500);

  if (ordersError) {
    return new Response(ordersError.message, { status: 500 });
  }

  const orderIds = (orders ?? []).map((o) => o.id);
  const shopIds = Array.from(new Set((orders ?? []).map((o) => o.shop_id).filter(Boolean)));
  const customerIds = Array.from(new Set((orders ?? []).map((o) => o.customer_profile_id).filter(Boolean)));

  const { data: shops } = shopIds.length
    ? await supabase.from("barbershops").select("id, name").in("id", shopIds).limit(1000)
    : { data: [] as Array<{ id: string; name: string | null }> };
  const shopNameById = new Map((shops ?? []).map((s) => [s.id, s.name ?? ""]));

  const { data: customers } = customerIds.length
    ? await supabase.from("profiles").select("id, full_name, phone, email").in("id", customerIds).limit(2000)
    : { data: [] as Array<{ id: string; full_name: string | null; phone: string | null; email: string | null }> };
  const customerById = new Map((customers ?? []).map((c) => [c.id, c]));

  type OrderItemRow = {
    order_id: string;
    product_id: string;
    variant_id: string | null;
    quantity: number;
    unit_price: number;
    line_total: number;
    product_name: string | null;
    variant_label: string | null;
  };

  const { data: items } = orderIds.length
    ? await supabase
        .from("order_items")
        .select("order_id, product_id, variant_id, quantity, unit_price, line_total, product_name, variant_label")
        .in("order_id", orderIds)
        .limit(20000)
    : { data: [] as Array<OrderItemRow> };

  const itemsByOrder = new Map<string, Array<OrderItemRow>>();
  for (const it of items ?? []) {
    const list = itemsByOrder.get(it.order_id) ?? [];
    list.push(it);
    itemsByOrder.set(it.order_id, list);
  }

  const header = [
    "order_id",
    "created_at",
    "shop",
    "customer",
    "status",
    "payment_status",
    "payment_method",
    "total_amount",
    "currency",
    "items_count",
    "items_summary"
  ];

  const lines: string[] = [];
  lines.push(header.join(","));

  for (const o of orders ?? []) {
    const c = customerById.get(o.customer_profile_id);
    const customerLabel = c?.full_name || c?.phone || c?.email || o.customer_profile_id;
    const shopName = shopNameById.get(o.shop_id) ?? o.shop_id;
    const orderItems = itemsByOrder.get(o.id) ?? [];
    const itemsCount = orderItems.reduce((sum, x) => sum + Number(x.quantity ?? 0), 0);
    const itemsSummary = orderItems
      .map((x) => {
        const name = x.product_name || x.product_id;
        const variant = x.variant_label ? ` (${x.variant_label})` : "";
        return `${name}${variant} x${x.quantity}`;
      })
      .join(" | ");

    const row = [
      o.id,
      o.created_at ?? "",
      shopName,
      customerLabel,
      o.status,
      o.payment_status,
      o.payment_method,
      Number(o.total_amount ?? 0).toFixed(3),
      o.currency ?? "BHD",
      String(itemsCount),
      itemsSummary
    ];
    lines.push(row.map(csvEscape).join(","));
  }

  const csv = lines.join("\n");
  return new Response(csv, {
    headers: {
      "content-type": "text/csv; charset=utf-8",
      "content-disposition": `attachment; filename="orders.csv"`
    }
  });
}

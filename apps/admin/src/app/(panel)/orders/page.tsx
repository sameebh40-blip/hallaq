import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong.";
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as an admin account.";
  }
  return m;
}

const ORDER_STATUSES = ["pending", "accepted", "processing", "rejected", "shipped", "delivered", "cancelled", "refunded"] as const;
const PAYMENT_STATUSES = ["unpaid", "paid", "failed", "refunded"] as const;
const REFUNDABLE_PAYMENT_STATUSES = ["paid"] as const;

export default async function AdminOrdersPage({ searchParams }: { searchParams?: Promise<{ error?: string }> }) {
  const params = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((params?.error ?? "").trim());

  const supabase = await createSupabaseServerClient();

  const { data: shops } = await supabase
    .from("barbershops")
    .select("id, name")
    .order("created_at", { ascending: false })
    .limit(600);

  const shopNameById = new Map((shops ?? []).map((s) => [s.id, s.name ?? ""]));

  const { data: orders } = await supabase
    .from("orders")
    .select("id, customer_profile_id, shop_id, status, total_amount, currency, payment_method, payment_status, created_at")
    .order("created_at", { ascending: false })
    .limit(200);

  const orderIds = (orders ?? []).map((o) => o.id);

  const { data: items } = orderIds.length
    ? await supabase.from("order_items").select("order_id, quantity, line_total").in("order_id", orderIds).limit(2000)
    : { data: [] as Array<{ order_id: string; quantity: number; line_total: number }> };

  const itemCountByOrder = new Map<string, number>();
  for (const it of items ?? []) {
    itemCountByOrder.set(it.order_id, (itemCountByOrder.get(it.order_id) ?? 0) + (it.quantity ?? 0));
  }

  const customerIds = Array.from(new Set((orders ?? []).map((o) => o.customer_profile_id).filter(Boolean)));
  const { data: customers } = customerIds.length
    ? await supabase.from("profiles").select("id, full_name, phone, email").in("id", customerIds).limit(600)
    : { data: [] as Array<{ id: string; full_name: string | null; phone: string | null; email: string | null }> };

  const customerById = new Map((customers ?? []).map((c) => [c.id, c]));

  const { data: refunds } = orderIds.length
    ? await supabase.from("order_refunds").select("order_id").in("order_id", orderIds).limit(2000)
    : { data: [] as Array<{ order_id: string }> };
  const refundCountByOrder = new Map<string, number>();
  for (const r of refunds ?? []) refundCountByOrder.set(r.order_id, (refundCountByOrder.get(r.order_id) ?? 0) + 1);

  async function updateOrder(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "").trim();
    const status = String(formData.get("status") ?? "").trim();
    const paymentStatus = String(formData.get("payment_status") ?? "").trim();

    if (!id) redirect("/orders");
    if (!ORDER_STATUSES.includes(status as (typeof ORDER_STATUSES)[number])) redirect("/orders");
    if (!PAYMENT_STATUSES.includes(paymentStatus as (typeof PAYMENT_STATUSES)[number])) redirect("/orders");

    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("orders").update({ status, payment_status: paymentStatus }).eq("id", id);
    if (error) redirect(`/orders?error=${encodeURIComponent(error.message)}`);
    redirect("/orders");
  }

  async function refundOrder(formData: FormData) {
    "use server";

    const orderId = String(formData.get("id") ?? "").trim();
    const amount = Number(formData.get("amount") ?? 0);
    const reason = String(formData.get("reason") ?? "").trim();
    const restock = String(formData.get("restock") ?? "") === "on";

    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const { data: order, error: oErr } = await supabase
      .from("orders")
      .select("id, payment_status, currency")
      .eq("id", orderId)
      .maybeSingle();
    if (oErr) redirect(`/orders?error=${encodeURIComponent(oErr.message)}`);
    if (!order?.id) redirect("/orders");
    if (!REFUNDABLE_PAYMENT_STATUSES.includes(order.payment_status as (typeof REFUNDABLE_PAYMENT_STATUSES)[number])) {
      redirect(`/orders?error=${encodeURIComponent("Only paid orders can be refunded.")}`);
    }

    const { error: rErr } = await supabase.from("order_refunds").insert({
      order_id: orderId,
      amount,
      currency: order.currency ?? "BHD",
      reason: reason || null,
      restock,
      created_by: actorId
    });
    if (rErr) redirect(`/orders?error=${encodeURIComponent(rErr.message)}`);
    redirect("/orders");
  }

  return (
    <PageFrame
      title="Orders"
      subtitle="Manage product orders across all shops."
      actions={
        <div className="flex items-center gap-2">
          <Button asChild variant="ghost" size="sm">
            <Link href="/orders/export">Export CSV</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/products">Products</Link>
          </Button>
        </div>
      }
    >
      {params?.error ? (
        <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard>
      ) : null}

      <LuxuryCard className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[1180px] text-sm">
            <thead className="text-xs text-muted-foreground">
              <tr className="border-b border-white/10">
                <th className="px-4 py-3 text-left font-medium">Order</th>
                <th className="px-4 py-3 text-left font-medium">Customer</th>
                <th className="px-4 py-3 text-left font-medium">Shop</th>
                <th className="px-4 py-3 text-left font-medium">Items</th>
                <th className="px-4 py-3 text-left font-medium">Total</th>
                <th className="px-4 py-3 text-left font-medium">Payment</th>
                <th className="px-4 py-3 text-right font-medium">Update</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/10">
              {orders?.length ? (
                orders.map((o) => {
                  const c = customerById.get(o.customer_profile_id);
                  const customerLabel = c?.full_name || c?.phone || c?.email || o.customer_profile_id;
                  const itemsCount = itemCountByOrder.get(o.id) ?? 0;
                  const refundCount = refundCountByOrder.get(o.id) ?? 0;
                  return (
                    <tr key={o.id} className="align-top">
                      <td className="px-4 py-3">
                        <div className="font-medium">{o.id.slice(0, 8)}</div>
                        <div className="text-xs text-muted-foreground">
                          {o.created_at ? Intl.DateTimeFormat("en", { dateStyle: "medium", timeStyle: "short" }).format(new Date(o.created_at)) : ""}
                        </div>
                      </td>
                      <td className="px-4 py-3">{customerLabel}</td>
                      <td className="px-4 py-3">{shopNameById.get(o.shop_id) ?? o.shop_id}</td>
                      <td className="px-4 py-3">{itemsCount}</td>
                      <td className="px-4 py-3">
                        {Number(o.total_amount ?? 0).toFixed(3)} {o.currency ?? "BHD"}
                      </td>
                      <td className="px-4 py-3">
                        <div className="text-xs text-muted-foreground">{o.payment_method ?? "cod"}</div>
                        <div className="flex items-center gap-2">
                          <div>{o.payment_status}</div>
                          {refundCount ? <div className="text-xs text-muted-foreground">refunds: {refundCount}</div> : null}
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex flex-col items-end gap-2">
                          <form action={updateOrder} className="flex items-center justify-end gap-2">
                            <input type="hidden" name="id" value={o.id} />
                            <select
                              name="status"
                              defaultValue={o.status}
                              className="h-9 rounded-md border border-white/10 bg-transparent px-2 text-xs"
                            >
                              {ORDER_STATUSES.map((s) => (
                                <option key={s} value={s}>
                                  {s}
                                </option>
                              ))}
                            </select>
                            <select
                              name="payment_status"
                              defaultValue={o.payment_status}
                              className="h-9 rounded-md border border-white/10 bg-transparent px-2 text-xs"
                            >
                              {PAYMENT_STATUSES.map((s) => (
                                <option key={s} value={s}>
                                  {s}
                                </option>
                              ))}
                            </select>
                            <Button type="submit" size="sm" variant="secondary" className="h-9">
                              Save
                            </Button>
                          </form>
                          <form action={refundOrder} className="flex items-center justify-end gap-2">
                            <input type="hidden" name="id" value={o.id} />
                            <input type="hidden" name="amount" value={String(o.total_amount ?? 0)} />
                            <Input
                              name="reason"
                              placeholder="Refund reason"
                              className="h-9 w-44"
                              disabled={o.payment_status !== "paid" || o.status === "refunded"}
                            />
                            <label className="flex items-center gap-2 text-xs text-muted-foreground">
                              <input
                                type="checkbox"
                                name="restock"
                                className="h-4 w-4"
                                disabled={o.payment_status !== "paid" || o.status === "refunded"}
                              />
                              Restock
                            </label>
                            <Button
                              type="submit"
                              size="sm"
                              variant="ghost"
                              className="h-9"
                              disabled={o.payment_status !== "paid" || o.status === "refunded"}
                            >
                              Refund
                            </Button>
                          </form>
                        </div>
                      </td>
                    </tr>
                  );
                })
              ) : (
                <tr>
                  <td className="px-4 py-6 text-muted-foreground" colSpan={7}>
                    No orders yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </LuxuryCard>
    </PageFrame>
  );
}

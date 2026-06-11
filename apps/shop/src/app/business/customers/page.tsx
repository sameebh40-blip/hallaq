import Link from "next/link";

import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getMyProfile } from "@hallaq/supabase/profile";

import { BusinessPageHeader } from "@/components/business/page-header";
import { getMyShopContext } from "@/lib/my-shop-context";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type CustomerStat = {
  id: string;
  name: string | null;
  phone: string | null;
  bookings: number;
  lastBookingAt: string | null;
};

export default async function BusinessCustomersPage({ searchParams }: { searchParams?: Promise<{ shopId?: string }> }) {
  const sp = searchParams ? await searchParams : undefined;
  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);
  const ctx = await getMyShopContext(supabase);
  const shopId = ctx.shop?.id ?? (profile?.role === "admin" ? (sp?.shopId ?? null) : null);
  if (!shopId) return <div className="text-sm text-muted-foreground">No shop selected.</div>;

  const { data: rows } = await supabase
    .from("bookings")
    .select("customer_profile_id, created_at")
    .eq("shop_id", shopId)
    .order("created_at", { ascending: false })
    .limit(4000);

  const stats = new Map<string, CustomerStat>();
  for (const r of rows ?? []) {
    if (!r.customer_profile_id) continue;
    const id = r.customer_profile_id;
    const existing = stats.get(id) ?? { id, name: null, phone: null, bookings: 0, lastBookingAt: null };
    existing.bookings += 1;
    if (!existing.lastBookingAt) existing.lastBookingAt = r.created_at ?? null;
    stats.set(id, existing);
  }

  const ids = [...stats.keys()];
  const { data: profiles } = ids.length
    ? await supabase.from("profiles").select("id, full_name, phone").in("id", ids.slice(0, 400))
    : { data: [] as Array<{ id: string; full_name: string | null; phone: string | null }> };

  for (const p of profiles ?? []) {
    const s = stats.get(p.id);
    if (!s) continue;
    s.name = p.full_name ?? null;
    s.phone = p.phone ?? null;
  }

  const list = [...stats.values()];
  list.sort((a, b) => {
    const al = a.lastBookingAt ? new Date(a.lastBookingAt).getTime() : 0;
    const bl = b.lastBookingAt ? new Date(b.lastBookingAt).getTime() : 0;
    return bl - al;
  });

  return (
    <div className="grid gap-4">
      <BusinessPageHeader
        title="Customers"
        subtitle="Customers are derived from real booking history (no mock data)."
        actions={
          <Link href="/business/bookings" className="text-sm text-primary hover:underline">
            View bookings
          </Link>
        }
      />

      <LuxuryCard className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[980px] text-sm">
            <thead className="text-xs text-muted-foreground">
              <tr className="border-b border-white/10">
                <th className="px-5 py-3 text-left font-medium">Customer</th>
                <th className="px-5 py-3 text-left font-medium">Phone</th>
                <th className="px-5 py-3 text-left font-medium">Bookings</th>
                <th className="px-5 py-3 text-left font-medium">Last booking</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/10">
              {list.length ? (
                list.slice(0, 400).map((c) => (
                  <tr key={c.id} className="hover:bg-white/5">
                    <td className="px-5 py-3">
                      <div className="font-medium">{(c.name ?? "").trim() || "Customer"}</div>
                      <div className="text-xs text-muted-foreground">{c.id}</div>
                    </td>
                    <td className="px-5 py-3 text-muted-foreground">{c.phone ?? "-"}</td>
                    <td className="px-5 py-3 text-muted-foreground">{c.bookings}</td>
                    <td className="px-5 py-3 text-muted-foreground">
                      {c.lastBookingAt ? Intl.DateTimeFormat("en", { dateStyle: "medium" }).format(new Date(c.lastBookingAt)) : "-"}
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={4} className="px-5 py-10 text-center text-muted-foreground">
                    No customers found yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </LuxuryCard>
    </div>
  );
}

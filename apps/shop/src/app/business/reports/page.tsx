import Link from "next/link";

import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { Button } from "@hallaq/ui/button";
import { getMyProfile } from "@hallaq/supabase/profile";

import { BusinessPageHeader } from "@/components/business/page-header";
import { getMyShopContext } from "@/lib/my-shop-context";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type RevenueRow = {
  day: string;
  gross_revenue: number | null;
  net_revenue: number | null;
  currency: string | null;
  bookings_count: number | null;
};

function toDateInputValue(date: Date) {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

export default async function BusinessReportsPage({
  searchParams
}: {
  searchParams?: Promise<{ from?: string; to?: string; shopId?: string }>;
}) {
  const sp = searchParams ? await searchParams : undefined;
  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);
  const ctx = await getMyShopContext(supabase);
  const shopId = ctx.shop?.id ?? (profile?.role === "admin" ? (sp?.shopId ?? null) : null);
  if (!shopId) return <div className="text-sm text-muted-foreground">No shop selected.</div>;

  const now = new Date();
  const defaultTo = toDateInputValue(now);
  const fromDate = (sp?.from ?? "").trim() || toDateInputValue(new Date(now.getFullYear(), now.getMonth(), now.getDate() - 30));
  const toDate = (sp?.to ?? "").trim() || defaultTo;

  const { data: revenue } = await supabase
    .from("shop_revenue_daily")
    .select("day, gross_revenue, net_revenue, currency, bookings_count")
    .eq("shop_id", shopId)
    .gte("day", fromDate)
    .lte("day", toDate)
    .order("day", { ascending: true })
    .limit(2000);

  const revenueRows = (revenue ?? []) as RevenueRow[];
  const totals = revenueRows.reduce(
    (acc, r) => {
      const gross = Number(r.gross_revenue ?? 0);
      const net = Number(r.net_revenue ?? 0);
      const bookings = Number(r.bookings_count ?? 0);
      acc.gross += gross;
      acc.net += net;
      acc.bookings += bookings;
      return acc;
    },
    { gross: 0, net: 0, bookings: 0 }
  );

  const exportBase = `/business/reports/export?shopId=${encodeURIComponent(shopId)}&from=${encodeURIComponent(fromDate)}&to=${encodeURIComponent(toDate)}`;
  const exportKinds = [
    { key: "revenue", label: "Revenue" },
    { key: "bookings", label: "Bookings" },
    { key: "orders", label: "Orders" },
    { key: "products", label: "Products" },
    { key: "reviews", label: "Reviews" }
  ];

  return (
    <div className="grid gap-4">
      <BusinessPageHeader
        title="Reports"
        subtitle="Exports and real revenue data from Supabase (no mock stats)."
        actions={
          <>
            <form method="get" className="flex items-center gap-2">
              {profile?.role === "admin" && !ctx.shop ? <input type="hidden" name="shopId" value={shopId} /> : null}
              <input type="date" name="from" defaultValue={fromDate} className="h-9 rounded-md border border-white/10 bg-white/5 px-3 text-sm" />
              <input type="date" name="to" defaultValue={toDate} className="h-9 rounded-md border border-white/10 bg-white/5 px-3 text-sm" />
              <Button type="submit" size="sm" variant="secondary">
                Apply
              </Button>
            </form>
            <Button asChild size="sm" variant="ghost">
              <Link href={`${exportBase}&kind=revenue&format=csv`}>Quick CSV</Link>
            </Button>
          </>
        }
      />

      <div className="grid gap-4 lg:grid-cols-5">
        {exportKinds.map((item) => (
          <LuxuryCard key={item.key} className="p-4">
            <div className="text-sm font-semibold">{item.label}</div>
            <div className="mt-1 text-xs text-muted-foreground">Export the current filtered range.</div>
            <div className="mt-4 flex flex-wrap gap-2">
              <Button asChild size="sm" variant="ghost">
                <Link href={`${exportBase}&kind=${item.key}&format=csv`}>CSV</Link>
              </Button>
              <Button asChild size="sm" variant="ghost">
                <Link href={`${exportBase}&kind=${item.key}&format=xlsx`}>XLSX</Link>
              </Button>
              <Button asChild size="sm" variant="ghost">
                <Link href={`${exportBase}&kind=${item.key}&format=pdf`}>PDF</Link>
              </Button>
            </div>
          </LuxuryCard>
        ))}
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <LuxuryCard className="p-5">
          <div className="text-sm text-muted-foreground">Gross revenue</div>
          <div className="pt-1 text-2xl font-semibold">{totals.gross.toFixed(3)} BHD</div>
        </LuxuryCard>
        <LuxuryCard className="p-5">
          <div className="text-sm text-muted-foreground">Net revenue</div>
          <div className="pt-1 text-2xl font-semibold">{totals.net.toFixed(3)} BHD</div>
        </LuxuryCard>
        <LuxuryCard className="p-5">
          <div className="text-sm text-muted-foreground">Bookings</div>
          <div className="pt-1 text-2xl font-semibold">{totals.bookings}</div>
        </LuxuryCard>
      </div>

      <LuxuryCard className="overflow-hidden">
        <div className="border-b border-white/10 px-5 py-4 text-sm font-semibold">Revenue (Daily)</div>
        <div className="overflow-x-auto">
          <table className="w-full min-w-[980px] text-sm">
            <thead className="text-xs text-muted-foreground">
              <tr className="border-b border-white/10">
                <th className="px-5 py-3 text-left font-medium">Day</th>
                <th className="px-5 py-3 text-left font-medium">Bookings</th>
                <th className="px-5 py-3 text-left font-medium">Gross</th>
                <th className="px-5 py-3 text-left font-medium">Net</th>
                <th className="px-5 py-3 text-left font-medium">Currency</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/10">
              {revenueRows.length ? (
                revenueRows.map((r) => (
                  <tr key={r.day} className="hover:bg-white/5">
                    <td className="px-5 py-3 font-medium">{r.day}</td>
                    <td className="px-5 py-3 text-muted-foreground">{Number(r.bookings_count ?? 0)}</td>
                    <td className="px-5 py-3 text-muted-foreground">{Number(r.gross_revenue ?? 0).toFixed(3)}</td>
                    <td className="px-5 py-3 text-muted-foreground">{Number(r.net_revenue ?? 0).toFixed(3)}</td>
                    <td className="px-5 py-3 text-muted-foreground">{r.currency ?? "BHD"}</td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={5} className="px-5 py-10 text-center text-muted-foreground">
                    No revenue data for this period.
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

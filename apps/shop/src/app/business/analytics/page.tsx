import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getMyProfile } from "@hallaq/supabase/profile";

import { getMyShopContext } from "@/lib/my-shop-context";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type BookingRow = {
  status: string | null;
  service_id: string | null;
  barber_id: string | null;
};

function sparkline(values: number[], width = 420, height = 120) {
  const v = values.filter((x) => Number.isFinite(x));
  if (!v.length) return { d: "", w: width, h: height };
  const min = Math.min(...v);
  const max = Math.max(...v);
  const span = max - min || 1;
  const step = v.length > 1 ? width / (v.length - 1) : width;
  const pts = v.map((x, i) => {
    const px = i * step;
    const py = height - ((x - min) / span) * height;
    return [px, py] as const;
  });
  const d = pts.map((p, i) => `${i === 0 ? "M" : "L"}${p[0].toFixed(2)},${p[1].toFixed(2)}`).join(" ");
  return { d, w: width, h: height };
}

export default async function BusinessAnalyticsPage({ searchParams }: { searchParams?: Promise<{ shopId?: string }> }) {
  const sp = searchParams ? await searchParams : undefined;
  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);
  const ctx = await getMyShopContext(supabase);
  const shopId = ctx.shop?.id ?? (profile?.role === "admin" ? (sp?.shopId ?? null) : null);
  if (!shopId) return <div className="text-sm text-muted-foreground">No shop selected.</div>;

  const now = new Date();
  const start30 = new Date(now);
  start30.setDate(start30.getDate() - 30);
  const start30Date = start30.toISOString().slice(0, 10);

  const { data: revenueRows } = await supabase
    .from("shop_revenue_daily")
    .select("day, gross_revenue, currency, bookings_count")
    .eq("shop_id", shopId)
    .gte("day", start30Date)
    .order("day", { ascending: true })
    .limit(2000);

  const chartValues =
    (revenueRows as Array<{ gross_revenue: number | null; currency: string | null }> | null)
      ?.filter((r) => (r.currency ?? "BHD") === "BHD")
      .map((r) => Number(r.gross_revenue ?? 0)) ?? [];
  const spk = sparkline(chartValues);

  const { data: bookingsRows } = await supabase
    .from("bookings")
    .select("id, status, service_id, barber_id, created_at")
    .eq("shop_id", shopId)
    .gte("created_at", start30.toISOString())
    .order("created_at", { ascending: false })
    .limit(5000);

  const statusCounts = new Map<string, number>();
  const serviceCounts = new Map<string, number>();
  const barberCounts = new Map<string, number>();
  for (const b of (bookingsRows ?? []) as BookingRow[]) {
    const s = String(b.status ?? "unknown");
    statusCounts.set(s, (statusCounts.get(s) ?? 0) + 1);
    if (b.service_id) serviceCounts.set(b.service_id, (serviceCounts.get(b.service_id) ?? 0) + 1);
    if (b.barber_id) barberCounts.set(b.barber_id, (barberCounts.get(b.barber_id) ?? 0) + 1);
  }

  const topServiceIds = [...serviceCounts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 8).map(([id]) => id);
  const topBarberIds = [...barberCounts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 8).map(([id]) => id);

  const { data: services } = topServiceIds.length
    ? await supabase.from("services").select("id, name_en, name").in("id", topServiceIds).limit(50)
    : { data: [] as Array<{ id: string; name_en: string | null; name: string | null }> };

  const { data: barbers } = topBarberIds.length
    ? await supabase.from("barbers").select("id, display_name").in("id", topBarberIds).limit(50)
    : { data: [] as Array<{ id: string; display_name: string | null }> };

  const serviceNameById = new Map((services ?? []).map((s) => [s.id, s.name_en ?? s.name ?? "Service"]));
  const barberNameById = new Map((barbers ?? []).map((b) => [b.id, b.display_name ?? "Barber"]));

  const statusList = [...statusCounts.entries()].sort((a, b) => b[1] - a[1]);
  const topServices = topServiceIds.map((id) => ({ id, name: serviceNameById.get(id) ?? "Service", count: serviceCounts.get(id) ?? 0 }));
  const topBarbers = topBarberIds.map((id) => ({ id, name: barberNameById.get(id) ?? "Barber", count: barberCounts.get(id) ?? 0 }));

  return (
    <div className="grid gap-4">
      <LuxuryCard className="p-4">
        <div className="text-base font-semibold">Analytics</div>
        <div className="text-sm text-muted-foreground">Last 30 days performance (realtime synced data).</div>
      </LuxuryCard>

      <div className="grid gap-4 lg:grid-cols-3">
        <LuxuryCard className="p-5 lg:col-span-2">
          <div className="text-sm text-muted-foreground">Revenue trend (30d)</div>
          <div className="pt-4">
            {spk.d ? (
              <svg className="h-[140px] w-full" viewBox={`0 0 ${spk.w} ${spk.h}`} preserveAspectRatio="none">
                <path d={spk.d} fill="none" stroke="hsl(var(--gold))" strokeWidth="2" />
              </svg>
            ) : (
              <div className="text-sm text-muted-foreground">No revenue data yet.</div>
            )}
          </div>
        </LuxuryCard>
        <LuxuryCard className="p-5">
          <div className="text-sm text-muted-foreground">Bookings by status</div>
          <div className="mt-3 grid gap-2">
            {statusList.length ? (
              statusList.slice(0, 10).map(([s, c]) => (
                <div key={s} className="flex items-center justify-between text-sm">
                  <div className="text-muted-foreground">{s}</div>
                  <div className="font-medium">{c}</div>
                </div>
              ))
            ) : (
              <div className="text-sm text-muted-foreground">No bookings yet.</div>
            )}
          </div>
        </LuxuryCard>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <LuxuryCard className="p-5">
          <div className="text-sm font-semibold">Top services</div>
          <div className="mt-3 grid gap-2">
            {topServices.length ? (
              topServices.map((s) => (
                <div key={s.id} className="flex items-center justify-between text-sm">
                  <div className="text-muted-foreground">{s.name}</div>
                  <div className="font-medium">{s.count}</div>
                </div>
              ))
            ) : (
              <div className="text-sm text-muted-foreground">No service data yet.</div>
            )}
          </div>
        </LuxuryCard>
        <LuxuryCard className="p-5">
          <div className="text-sm font-semibold">Top barbers</div>
          <div className="mt-3 grid gap-2">
            {topBarbers.length ? (
              topBarbers.map((b) => (
                <div key={b.id} className="flex items-center justify-between text-sm">
                  <div className="text-muted-foreground">{b.name}</div>
                  <div className="font-medium">{b.count}</div>
                </div>
              ))
            ) : (
              <div className="text-sm text-muted-foreground">No barber data yet.</div>
            )}
          </div>
        </LuxuryCard>
      </div>
    </div>
  );
}

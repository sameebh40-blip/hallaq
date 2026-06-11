import Link from "next/link";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";

import { KpiCard } from "@/components/kpi-card";
import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type Tone = "success" | "warning" | "danger";

function formatBytes(bytes: number) {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  let v = bytes;
  let i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i += 1;
  }
  return `${v.toFixed(i === 0 ? 0 : 1)} ${units[i]}`;
}

function statusLabel(tone: Tone) {
  if (tone === "success") return "✅ Healthy";
  if (tone === "warning") return "⚠ Warning";
  return "❌ Broken";
}

export default async function SystemHealthCenterPage() {
  const supabase = await createSupabaseServerClient();

  const now = new Date();
  const start = new Date(now);
  start.setUTCHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setUTCDate(end.getUTCDate() + 1);

  const startIso = start.toISOString();
  const endIso = end.toISOString();

  const t0 = Date.now();
  const [
    totalUsers,
    totalCustomers,
    totalBarbers,
    totalShops,
    newSignupsToday,
    newBookingsToday,
    cancelledBookingsToday,
    pendingApprovalsShops,
    pendingApprovalsReels,
    pendingApprovalsBarbers,
    errorLogsToday,
    failedBookingLogsToday,
    dbSizeBytes,
    storageBytes
  ] = await Promise.all([
    supabase.from("profiles").select("id", { count: "exact", head: true }).limit(1),
    supabase.from("customers").select("id", { count: "exact", head: true }).limit(1),
    supabase.from("barbers").select("id", { count: "exact", head: true }).limit(1),
    supabase.from("barbershops").select("id", { count: "exact", head: true }).is("deleted_at", null).limit(1),
    supabase.from("profiles").select("id", { count: "exact", head: true }).gte("created_at", startIso).lt("created_at", endIso).limit(1),
    supabase.from("bookings").select("id", { count: "exact", head: true }).gte("created_at", startIso).lt("created_at", endIso).limit(1),
    supabase.from("bookings").select("id", { count: "exact", head: true }).eq("status", "cancelled").gte("updated_at", startIso).lt("updated_at", endIso).limit(1),
    supabase.from("barbershops").select("id", { count: "exact", head: true }).eq("status", "pending").limit(1),
    supabase.from("reels").select("id", { count: "exact", head: true }).eq("status", "pending").limit(1),
    supabase.from("barbers").select("id", { count: "exact", head: true }).eq("is_verified", false).is("deleted_at", null).limit(1),
    supabase
      .from("system_logs")
      .select("id", { count: "exact", head: true })
      .in("severity", ["error", "critical"])
      .gte("created_at", startIso)
      .lt("created_at", endIso)
      .limit(1),
    supabase
      .from("system_logs")
      .select("id", { count: "exact", head: true })
      .in("severity", ["error", "critical"])
      .gte("created_at", startIso)
      .lt("created_at", endIso)
      .or("action.ilike.%create_booking%,action.ilike.%confirm_booking%,action.ilike.%booking%")
      .limit(1),
    supabase.rpc("admin_get_database_size_bytes"),
    supabase.rpc("admin_get_storage_usage_bytes")
  ]);
  const apiMs = Date.now() - t0;

  const bookingsTodayRows = await supabase
    .from("bookings")
    .select("shop_id, barber_id")
    .gte("start_at", startIso)
    .lt("start_at", endIso)
    .limit(20000);

  const shopsActiveSet = new Set<string>();
  const barbersActiveSet = new Set<string>();
  for (const r of (bookingsTodayRows.data ?? []) as Array<Record<string, unknown>>) {
    const shopId = String(r.shop_id ?? "").trim();
    const barberId = String(r.barber_id ?? "").trim();
    if (shopId) shopsActiveSet.add(shopId);
    if (barberId) barbersActiveSet.add(barberId);
  }

  const pendingApprovals =
    (pendingApprovalsShops.count ?? 0) + (pendingApprovalsReels.count ?? 0) + (pendingApprovalsBarbers.count ?? 0);

  const dbBytes = typeof dbSizeBytes.data === "number" ? dbSizeBytes.data : 0;
  const stBytes = typeof storageBytes.data === "number" ? storageBytes.data : 0;

  const cards = [
    { title: "Total Users", value: String(totalUsers.count ?? 0), tone: totalUsers.error ? ("danger" as const) : ("success" as const) },
    {
      title: "Total Customers",
      value: String(totalCustomers.count ?? 0),
      tone: totalCustomers.error ? ("warning" as const) : ("success" as const)
    },
    { title: "Total Barbers", value: String(totalBarbers.count ?? 0), tone: totalBarbers.error ? ("danger" as const) : ("success" as const) },
    { title: "Total Shops", value: String(totalShops.count ?? 0), tone: totalShops.error ? ("danger" as const) : ("success" as const) },
    { title: "Active Shops Today", value: String(shopsActiveSet.size), tone: "success" as const },
    { title: "Active Barbers Today", value: String(barbersActiveSet.size), tone: "success" as const },
    { title: "New Signups Today", value: String(newSignupsToday.count ?? 0), tone: newSignupsToday.error ? ("warning" as const) : ("success" as const) },
    { title: "New Bookings Today", value: String(newBookingsToday.count ?? 0), tone: newBookingsToday.error ? ("warning" as const) : ("success" as const) },
    {
      title: "Failed Bookings",
      value: String(failedBookingLogsToday.count ?? 0),
      tone: (failedBookingLogsToday.count ?? 0) > 0 ? ("warning" as const) : ("success" as const)
    },
    {
      title: "Cancelled Bookings",
      value: String(cancelledBookingsToday.count ?? 0),
      tone: (cancelledBookingsToday.count ?? 0) > 0 ? ("warning" as const) : ("success" as const)
    },
    {
      title: "Pending Approvals",
      value: String(pendingApprovals),
      tone: pendingApprovals > 0 ? ("warning" as const) : ("success" as const)
    },
    { title: "Storage Usage", value: formatBytes(stBytes), tone: storageBytes.error ? ("warning" as const) : ("success" as const) },
    { title: "Database Size", value: formatBytes(dbBytes), tone: dbSizeBytes.error ? ("warning" as const) : ("success" as const) },
    { title: "API Response Time", value: `${apiMs} ms`, tone: apiMs > 1500 ? ("warning" as const) : ("success" as const) },
    {
      title: "Error Count Today",
      value: String(errorLogsToday.count ?? 0),
      tone: (errorLogsToday.count ?? 0) > 0 ? ("warning" as const) : ("success" as const)
    }
  ];

  return (
    <PageFrame
      title="System Health Center"
      subtitle="Live platform monitoring powered by real Supabase data."
      actions={
        <>
          <Button asChild variant="secondary" size="sm">
            <Link href="/error-center">Error Center</Link>
          </Button>
          <Button asChild variant="secondary" size="sm">
            <Link href="/missing-images">Missing Images</Link>
          </Button>
          <Button asChild variant="secondary" size="sm">
            <Link href="/data-integrity">Data Integrity</Link>
          </Button>
        </>
      }
    >
      <div className="grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-3">
        {cards.map((c) => (
          <KpiCard key={c.title} title={c.title} value={c.value} delta={{ label: statusLabel(c.tone), tone: c.tone }} />
        ))}
      </div>
      <div className="pt-5 text-xs text-muted-foreground">
        Window: {start.toISOString().slice(0, 10)} (UTC)
      </div>
    </PageFrame>
  );
}

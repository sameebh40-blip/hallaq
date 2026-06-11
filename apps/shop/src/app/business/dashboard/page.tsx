import Link from "next/link";

import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getMyProfile } from "@hallaq/supabase/profile";

import { createAppSupabaseServerClient } from "@/lib/supabase";
import { getMyShopContext } from "@/lib/my-shop-context";

export const dynamic = "force-dynamic";

async function safeCount(query: PromiseLike<{ count: number | null }>) {
  const { count } = await query;
  return typeof count === "number" ? count : 0;
}

function formatBhd(value: number) {
  const n = Number.isFinite(value) ? value : 0;
  return `${n.toFixed(3)} BHD`;
}

function sparkline(values: number[], width = 220, height = 44) {
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

type BookingTodayRow = {
  id: string;
  start_at: string;
  status: string;
  total_price: number | string | null;
  currency: string | null;
  profiles: { full_name: string | null; phone: string | null } | null;
  services: { name_en: string | null; name: string | null } | null;
  barbers: { display_name: string | null } | null;
};

export default async function BusinessDashboardPage({
  searchParams
}: {
  searchParams?: Promise<{ shopId?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);
  const ctx = await getMyShopContext(supabase);

  const shopId = ctx.shop?.id ?? (profile?.role === "admin" ? (params?.shopId ?? null) : null);

  if (!shopId) {
    const { data: shops } = await supabase
      .from("barbershops")
      .select("id, name, area, is_verified, rating_avg, rating_count")
      .order("created_at", { ascending: false })
      .limit(400);

    return (
      <div className="grid gap-6">
        <div className="flex items-end justify-between gap-4">
          <div>
            <div className="text-xl font-semibold tracking-tight">Dashboard</div>
            <div className="text-sm text-muted-foreground">Select a shop to open the business dashboard.</div>
          </div>
        </div>
        <LuxuryCard className="overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[980px] text-sm">
              <thead className="text-xs text-muted-foreground">
                <tr className="border-b border-white/10">
                  <th className="px-4 py-3 text-left font-medium">Shop</th>
                  <th className="px-4 py-3 text-left font-medium">Area</th>
                  <th className="px-4 py-3 text-left font-medium">Rating</th>
                  <th className="px-4 py-3 text-right font-medium">Open</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/10">
                {(shops ?? []).map((s) => (
                  <tr key={s.id} className="hover:bg-white/5">
                    <td className="px-4 py-3">
                      <div className="font-medium">{s.name ?? "Shop"}</div>
                      <div className="text-xs text-muted-foreground">{s.is_verified ? "Verified" : "Unverified"}</div>
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">{s.area ?? "-"}</td>
                    <td className="px-4 py-3 text-muted-foreground">
                      {Number(s.rating_avg ?? 0).toFixed(2)} ({Number(s.rating_count ?? 0)})
                    </td>
                    <td className="px-4 py-3 text-right">
                      <Link
                        className="rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm transition hover:bg-white/10"
                        href={`/business/dashboard?shopId=${encodeURIComponent(s.id)}`}
                      >
                        Open
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </LuxuryCard>
      </div>
    );
  }

  const { data: shop } = await supabase
    .from("barbershops")
    .select("id, name, area, is_verified, rating_avg, rating_count, status")
    .eq("id", shopId)
    .maybeSingle();

  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
  const startUtc = startOfDay.toISOString();
  const endUtc = endOfDay.toISOString();

  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const monthStartDate = monthStart.toISOString().slice(0, 10);

  const start30 = new Date(now);
  start30.setDate(start30.getDate() - 30);
  const start30Date = start30.toISOString().slice(0, 10);

  const [todayBookings, upcomingBookings, activeBarbers, pendingOrders] = await Promise.all([
    safeCount(
      supabase
        .from("bookings")
        .select("*", { count: "exact", head: true })
        .eq("shop_id", shopId)
        .gte("start_at", startUtc)
        .lt("start_at", endUtc)
    ),
    safeCount(
      supabase
        .from("bookings")
        .select("*", { count: "exact", head: true })
        .eq("shop_id", shopId)
        .gte("start_at", now.toISOString())
    ),
    safeCount(supabase.from("barbers").select("*", { count: "exact", head: true }).eq("shop_id", shopId)),
    safeCount(
      supabase
        .from("orders")
        .select("*", { count: "exact", head: true })
        .eq("shop_id", shopId)
        .in("status", ["pending", "accepted", "processing"])
    )
  ]);

  const { data: revenueRows } = await supabase
    .from("shop_revenue_daily")
    .select("day, gross_revenue, currency")
    .eq("shop_id", shopId)
    .gte("day", start30Date)
    .order("day", { ascending: true })
    .limit(2000);

  const revenueBhd30d =
    (revenueRows as Array<{ gross_revenue: number | null; currency: string }> | null)?.reduce((acc, r) => {
      if ((r.currency ?? "BHD") !== "BHD") return acc;
      return acc + Number(r.gross_revenue ?? 0);
    }, 0) ?? 0;

  const revenueBhdMonth =
    (revenueRows as Array<{ day: string; gross_revenue: number | null; currency: string }> | null)?.reduce((acc, r) => {
      if ((r.currency ?? "BHD") !== "BHD") return acc;
      if (String(r.day ?? "") < monthStartDate) return acc;
      return acc + Number(r.gross_revenue ?? 0);
    }, 0) ?? 0;

  const todayRevenueBhd =
    (revenueRows as Array<{ day: string; gross_revenue: number | null; currency: string }> | null)?.reduce((acc, r) => {
      if ((r.currency ?? "BHD") !== "BHD") return acc;
      if (String(r.day ?? "") !== startUtc.slice(0, 10)) return acc;
      return acc + Number(r.gross_revenue ?? 0);
    }, 0) ?? 0;

  const chartValues =
    (revenueRows as Array<{ day: string; gross_revenue: number | null; currency: string }> | null)
      ?.filter((r) => (r.currency ?? "BHD") === "BHD")
      .map((r) => Number(r.gross_revenue ?? 0)) ?? [];
  const sp = sparkline(chartValues);

  const { data: bookingsToday } = await supabase
    .from("bookings")
    .select(
      "id, start_at, end_at, status, total_price, currency, customer_profile_id, barber_id, service_id, profiles(full_name, phone), barbers(display_name), services(name_en, name)"
    )
    .eq("shop_id", shopId)
    .gte("start_at", startUtc)
    .lt("start_at", endUtc)
    .order("start_at", { ascending: true })
    .limit(30);
  const bookingsTodayRows = (bookingsToday ?? []) as unknown as BookingTodayRow[];

  const customerCounts = new Map<string, number>();
  let page = 0;
  while (page < 10) {
    const from = page * 5000;
    const to = from + 4999;
    const { data } = await supabase
      .from("bookings")
      .select("customer_profile_id")
      .eq("shop_id", shopId)
      .range(from, to);
    const list = (data ?? []).map((r) => r.customer_profile_id).filter(Boolean) as string[];
    for (const id of list) customerCounts.set(id, (customerCounts.get(id) ?? 0) + 1);
    if (!data || data.length < 5000) break;
    page += 1;
  }
  const totalCustomers = customerCounts.size;
  const repeatCustomers = Array.from(customerCounts.values()).filter((c) => c > 1).length;

  const avgRating = Number(shop?.rating_avg ?? 0);
  const ratingCount = Number(shop?.rating_count ?? 0);

  return (
    <div className="grid gap-6">
      <div className="flex flex-col gap-1">
        <div className="text-2xl font-semibold tracking-tight">{shop?.name ?? "Dashboard"}</div>
        <div className="text-sm text-muted-foreground">
          {shop?.area ?? "Bahrain"} • {shop?.status ?? "active"} • {shop?.is_verified ? "Verified" : "Not verified"}
        </div>
      </div>

      <div className="grid gap-4 lg:grid-cols-4">
        <LuxuryCard className="relative overflow-hidden p-5">
          <div className="text-sm text-muted-foreground">Today’s Revenue</div>
          <div className="pt-1 text-2xl font-semibold">{formatBhd(todayRevenueBhd)}</div>
          <div className="pt-2 text-xs text-muted-foreground">Last 30 days: {formatBhd(revenueBhd30d)}</div>
          {sp.d ? (
            <svg className="absolute bottom-4 right-4 opacity-70" width={sp.w} height={sp.h} viewBox={`0 0 ${sp.w} ${sp.h}`}>
              <path d={sp.d} fill="none" stroke="hsl(var(--gold))" strokeWidth="2" />
            </svg>
          ) : null}
        </LuxuryCard>

        <LuxuryCard className="p-5">
          <div className="text-sm text-muted-foreground">Today’s Bookings</div>
          <div className="pt-1 text-2xl font-semibold">{todayBookings}</div>
          <div className="pt-2 text-xs text-muted-foreground">
            Upcoming: <span className="text-foreground">{upcomingBookings}</span>
          </div>
        </LuxuryCard>

        <LuxuryCard className="p-5">
          <div className="text-sm text-muted-foreground">Customers</div>
          <div className="pt-1 text-2xl font-semibold">{totalCustomers}</div>
          <div className="pt-2 text-xs text-muted-foreground">
            Repeat: <span className="text-foreground">{repeatCustomers}</span>
          </div>
        </LuxuryCard>

        <LuxuryCard className="p-5">
          <div className="text-sm text-muted-foreground">Active Barbers</div>
          <div className="pt-1 text-2xl font-semibold">{activeBarbers}</div>
          <div className="pt-2 text-xs text-muted-foreground">
            Pending orders: <span className="text-foreground">{pendingOrders}</span>
          </div>
        </LuxuryCard>
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <LuxuryCard className="p-5 lg:col-span-2">
          <div className="flex items-center justify-between gap-4">
            <div>
              <div className="text-sm text-muted-foreground">Revenue Overview</div>
              <div className="pt-1 text-xl font-semibold">{formatBhd(revenueBhdMonth)} this month</div>
            </div>
            <Link href="/business/reports" className="text-sm text-primary hover:underline">
              View reports
            </Link>
          </div>
          <div className="pt-4">
            {sp.d ? (
              <svg className="h-[120px] w-full" viewBox={`0 0 ${sp.w} ${sp.h}`} preserveAspectRatio="none">
                <path d={sp.d} fill="none" stroke="hsl(var(--gold))" strokeWidth="2" />
              </svg>
            ) : (
              <div className="text-sm text-muted-foreground">No revenue yet.</div>
            )}
          </div>
        </LuxuryCard>

        <LuxuryCard className="p-5">
          <div className="text-sm text-muted-foreground">Reviews Rating</div>
          <div className="pt-1 text-2xl font-semibold">{avgRating.toFixed(2)}</div>
          <div className="pt-2 text-xs text-muted-foreground">{ratingCount} reviews</div>
          <div className="pt-4">
            <Link href="/business/reviews" className="text-sm text-primary hover:underline">
              Manage reviews
            </Link>
          </div>
        </LuxuryCard>
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <LuxuryCard className="overflow-hidden p-0 lg:col-span-2">
          <div className="flex items-center justify-between gap-4 border-b border-white/10 px-5 py-4">
            <div>
              <div className="text-sm font-semibold">Today’s Schedule</div>
              <div className="text-xs text-muted-foreground">{startUtc.slice(0, 10)}</div>
            </div>
            <Link href="/business/calendar" className="text-sm text-primary hover:underline">
              Open calendar
            </Link>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full min-w-[820px] text-sm">
              <thead className="text-xs text-muted-foreground">
                <tr className="border-b border-white/10">
                  <th className="px-5 py-3 text-left font-medium">Time</th>
                  <th className="px-5 py-3 text-left font-medium">Customer</th>
                  <th className="px-5 py-3 text-left font-medium">Service</th>
                  <th className="px-5 py-3 text-left font-medium">Barber</th>
                  <th className="px-5 py-3 text-left font-medium">Status</th>
                  <th className="px-5 py-3 text-right font-medium">Total</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/10">
                {bookingsTodayRows.length ? (
                  bookingsTodayRows.map((b) => (
                    <tr key={b.id} className="hover:bg-white/5">
                      <td className="px-5 py-3 text-muted-foreground">
                        {new Date(b.start_at).toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" })}
                      </td>
                      <td className="px-5 py-3">
                        <div className="font-medium">{b.profiles?.full_name ?? "Customer"}</div>
                        <div className="text-xs text-muted-foreground">{b.profiles?.phone ?? ""}</div>
                      </td>
                      <td className="px-5 py-3 text-muted-foreground">{b.services?.name_en ?? b.services?.name ?? "-"}</td>
                      <td className="px-5 py-3 text-muted-foreground">{b.barbers?.display_name ?? "-"}</td>
                      <td className="px-5 py-3 text-muted-foreground">{b.status}</td>
                      <td className="px-5 py-3 text-right text-muted-foreground">
                        {b.currency === "BHD"
                          ? formatBhd(Number(b.total_price ?? 0))
                          : `${Number(b.total_price ?? 0)} ${b.currency ?? "BHD"}`}
                      </td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan={6} className="px-5 py-10 text-center text-muted-foreground">
                      No bookings for today yet.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </LuxuryCard>

        <LuxuryCard className="p-5">
          <div className="text-sm font-semibold">Quick Actions</div>
          <div className="pt-1 text-xs text-muted-foreground">High-impact actions for today.</div>
          <div className="grid gap-2 pt-4">
            <Link className="rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm transition hover:bg-white/10" href="/business/bookings/new">
              New booking
            </Link>
            <Link className="rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm transition hover:bg-white/10" href="/business/services">
              Add / update services
            </Link>
            <Link className="rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm transition hover:bg-white/10" href="/business/reels/upload">
              Upload a reel
            </Link>
            <Link className="rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm transition hover:bg-white/10" href="/business/reports">
              Export reports
            </Link>
          </div>
        </LuxuryCard>
      </div>
    </div>
  );
}

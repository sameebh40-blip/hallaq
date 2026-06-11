import { createSupabaseServerClient } from "@hallaq/supabase/server";

export type DashboardStats = {
  users: number;
  stores: number;
  barbers: number;
  bookings: number;
  revenueBhd: number;
  posts: number;
  reels: number;
  pendingApprovals: number;
};

export type DashboardSeriesPoint = { label: string; value: number };

export type DashboardSeries = {
  dailyBookings: DashboardSeriesPoint[];
  monthlyGrowth: DashboardSeriesPoint[];
  revenueGrowth: DashboardSeriesPoint[];
  userGrowth: DashboardSeriesPoint[];
  storeGrowth: DashboardSeriesPoint[];
  recentActivity: Array<{
    id: string;
    type: string;
    title: string;
    subtitle: string;
    at: string;
  }>;
};

type SupabaseServerClient = Awaited<ReturnType<typeof createSupabaseServerClient>>;

async function safeCount(supabase: SupabaseServerClient, table: string) {
  const { count } = await supabase.from(table).select("*", { count: "exact", head: true });
  return typeof count === "number" ? count : null;
}

export async function getDashboardData(): Promise<{ kpis: DashboardStats } & DashboardSeries> {
  const supabase = await createSupabaseServerClient();

  try {
    const [users, stores, barbers, bookings, reels] = await Promise.all([
      safeCount(supabase, "profiles"),
      safeCount(supabase, "barbershops"),
      safeCount(supabase, "barbers"),
      safeCount(supabase, "bookings"),
      safeCount(supabase, "reels")
    ]);

    const now = new Date();
    const start14 = new Date(now);
    start14.setDate(start14.getDate() - 13);

    const start6m = new Date(now);
    start6m.setMonth(start6m.getMonth() - 5, 1);
    start6m.setHours(0, 0, 0, 0);

    const [pendingShops, pendingReels, unverifiedBarbers, dailyBookingsRaw, monthlyBookingsRaw, userGrowthRaw, storeGrowthRaw, revenueDailyRaw, activityRaw] =
      await Promise.all([
        supabase.from("barbershops").select("*", { count: "exact", head: true }).eq("status", "pending"),
        supabase.from("reels").select("*", { count: "exact", head: true }).eq("status", "pending"),
        supabase.from("barbers").select("*", { count: "exact", head: true }).eq("is_verified", false),
        supabase.from("bookings").select("start_at").gte("start_at", start14.toISOString()).limit(5000),
        supabase.from("bookings").select("created_at").gte("created_at", start6m.toISOString()).limit(20000),
        supabase.from("profiles").select("created_at").gte("created_at", start6m.toISOString()).limit(20000),
        supabase.from("barbershops").select("created_at").gte("created_at", start6m.toISOString()).limit(20000),
        supabase.from("shop_revenue_daily").select("day, gross_revenue, currency").gte("day", start6m.toISOString().slice(0, 10)).limit(20000),
        supabase.from("admin_activity_logs").select("id, action, entity_type, created_at").order("created_at", { ascending: false }).limit(10),
      ]);

    const pendingApprovals =
      (pendingShops.count ?? 0) + (pendingReels.count ?? 0) + (unverifiedBarbers.count ?? 0);

    const dayLabel = (d: Date) =>
      Intl.DateTimeFormat("en", { month: "short", day: "numeric" }).format(d);
    const monthLabel = (d: Date) => Intl.DateTimeFormat("en", { month: "short" }).format(d);

    const dailyCounts = new Map<string, number>();
    for (const r of dailyBookingsRaw.data ?? []) {
      const key = String(r.start_at).slice(0, 10);
      dailyCounts.set(key, (dailyCounts.get(key) ?? 0) + 1);
    }

    const dailyBookings = Array.from({ length: 14 }).map((_, i) => {
      const d = new Date(start14);
      d.setDate(d.getDate() + i);
      const key = d.toISOString().slice(0, 10);
      return { label: dayLabel(d), value: dailyCounts.get(key) ?? 0 };
    });

    const monthBuckets = (raw: Array<{ created_at: string }> | null | undefined) => {
      const map = new Map<string, number>();
      for (const r of raw ?? []) {
        const key = String(r.created_at).slice(0, 7);
        map.set(key, (map.get(key) ?? 0) + 1);
      }
      return map;
    };

    const bookingsByMonth = monthBuckets(monthlyBookingsRaw.data as Array<{ created_at: string }> | null);
    const usersByMonth = monthBuckets(userGrowthRaw.data as Array<{ created_at: string }> | null);
    const storesByMonth = monthBuckets(storeGrowthRaw.data as Array<{ created_at: string }> | null);

    const months = Array.from({ length: 6 }).map((_, i) => {
      const d = new Date(start6m);
      d.setMonth(d.getMonth() + i);
      return d;
    });

    const monthlyGrowth = months.map((m) => {
      const key = m.toISOString().slice(0, 7);
      return { label: monthLabel(m), value: bookingsByMonth.get(key) ?? 0 };
    });

    const userGrowth = months.map((m) => {
      const key = m.toISOString().slice(0, 7);
      return { label: monthLabel(m), value: usersByMonth.get(key) ?? 0 };
    });

    const storeGrowth = months.map((m) => {
      const key = m.toISOString().slice(0, 7);
      return { label: monthLabel(m), value: storesByMonth.get(key) ?? 0 };
    });

    const revenueByMonth = new Map<string, number>();
    for (const r of (revenueDailyRaw.data as Array<{ day: string; gross_revenue: number | null; currency: string }> | null) ??
      []) {
      if (r.currency !== "BHD") continue;
      const key = String(r.day).slice(0, 7);
      const add = Number(r.gross_revenue ?? 0);
      revenueByMonth.set(key, (revenueByMonth.get(key) ?? 0) + add);
    }

    const revenueGrowth = months.map((m) => {
      const key = m.toISOString().slice(0, 7);
      return { label: monthLabel(m), value: Math.round(revenueByMonth.get(key) ?? 0) };
    });

    const revenueBhd = revenueGrowth.reduce((acc, p) => acc + p.value, 0);

    const recentActivity =
      (activityRaw.data ?? []).map((a) => ({
        id: a.id,
        type: a.entity_type,
        title: a.action,
        subtitle: a.entity_type,
        at: Intl.DateTimeFormat("en", { dateStyle: "medium", timeStyle: "short" }).format(
          new Date(a.created_at)
        ),
      })) ?? [];

    const kpis: DashboardStats = {
      users: users ?? 0,
      stores: stores ?? 0,
      barbers: barbers ?? 0,
      bookings: bookings ?? 0,
      revenueBhd,
      posts: reels ?? 0,
      reels: reels ?? 0,
      pendingApprovals,
    };

    return {
      kpis,
      dailyBookings,
      monthlyGrowth,
      revenueGrowth,
      userGrowth,
      storeGrowth,
      recentActivity
    };
  } catch {
    throw new Error("DashboardUnavailable");
  }
}

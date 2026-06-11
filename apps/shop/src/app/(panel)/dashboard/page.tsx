import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { getMyShop } from "@/lib/my-shop";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

async function safeCount(query: PromiseLike<{ count: number | null }>) {
  const { count } = await query;
  return typeof count === "number" ? count : 0;
}

export default async function ShopDashboardPage() {
  const supabase = await createAppSupabaseServerClient();
  const shop = await getMyShop(supabase);

  if (!shop) {
    return (
      <div className="text-sm text-muted-foreground">
        No shop assigned to this account yet. Ask an admin to assign you as owner.
      </div>
    );
  }

  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startUtc = startOfDay.toISOString();
  const nowUtc = now.toISOString();

  const start30 = new Date(now);
  start30.setDate(start30.getDate() - 30);
  const start30Date = start30.toISOString().slice(0, 10);

  const [todayBookings, upcomingBookings, posts, reviews] = await Promise.all([
    safeCount(
      supabase
        .from("bookings")
        .select("*", { count: "exact", head: true })
        .eq("shop_id", shop.id)
        .gte("start_at", startUtc)
        .lt("start_at", nowUtc)
    ),
    safeCount(
      supabase.from("bookings").select("*", { count: "exact", head: true }).eq("shop_id", shop.id).gte("start_at", nowUtc)
    ),
    safeCount(supabase.from("reels").select("*", { count: "exact", head: true }).eq("shop_id", shop.id)),
    safeCount(
      supabase
        .from("reviews")
        .select("*", { count: "exact", head: true })
        .eq("target_type", "shop")
        .eq("target_id", shop.id)
        .eq("status", "published")
    ),
  ]);

  const { data: revenueRows } = await supabase
    .from("shop_revenue_daily")
    .select("gross_revenue, currency")
    .eq("shop_id", shop.id)
    .gte("day", start30Date)
    .limit(2000);

  const revenueBhd30d =
    (revenueRows as Array<{ gross_revenue: number | null; currency: string }> | null)?.reduce((acc, r) => {
      if (r.currency !== "BHD") return acc;
      return acc + Number(r.gross_revenue ?? 0);
    }, 0) ?? 0;

  return (
    <div className="grid gap-4 md:grid-cols-2">
      <LuxuryCard className="p-5">
        <div className="text-sm text-muted-foreground">Revenue (30d)</div>
        <div className="pt-1 text-2xl font-semibold">{Math.round(revenueBhd30d)} BHD</div>
      </LuxuryCard>
      <LuxuryCard className="p-5">
        <div className="text-sm text-muted-foreground">Today bookings</div>
        <div className="pt-1 text-2xl font-semibold">{todayBookings}</div>
      </LuxuryCard>
      <LuxuryCard className="p-5">
        <div className="text-sm text-muted-foreground">Upcoming bookings</div>
        <div className="pt-1 text-2xl font-semibold">{upcomingBookings}</div>
      </LuxuryCard>
      <LuxuryCard className="p-5">
        <div className="text-sm text-muted-foreground">Posts</div>
        <div className="pt-1 text-2xl font-semibold">{posts}</div>
      </LuxuryCard>
      <LuxuryCard className="p-5">
        <div className="text-sm text-muted-foreground">Reviews</div>
        <div className="pt-1 text-2xl font-semibold">{reviews}</div>
      </LuxuryCard>
    </div>
  );
}

import Link from "next/link";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

export default async function AiAssistantPlaceholderPage() {
  const supabase = await createSupabaseServerClient();

  const now = new Date();
  const startToday = new Date(now);
  startToday.setUTCHours(0, 0, 0, 0);
  const startYesterday = new Date(startToday);
  startYesterday.setUTCDate(startYesterday.getUTCDate() - 1);
  const start7 = new Date(startToday);
  start7.setUTCDate(start7.getUTCDate() - 7);

  const [todayBookings, yesterdayBookings, weekBookings, pendingReels, hiddenReels, invisibleServices] = await Promise.all([
    supabase.from("bookings").select("id", { count: "exact", head: true }).gte("created_at", startToday.toISOString()).limit(1),
    supabase
      .from("bookings")
      .select("id", { count: "exact", head: true })
      .gte("created_at", startYesterday.toISOString())
      .lt("created_at", startToday.toISOString())
      .limit(1),
    supabase.from("bookings").select("id", { count: "exact", head: true }).gte("created_at", start7.toISOString()).limit(1),
    supabase.from("reels").select("id", { count: "exact", head: true }).eq("status", "pending").is("deleted_at", null).limit(1),
    supabase.from("reels").select("id", { count: "exact", head: true }).neq("status", "approved").is("deleted_at", null).limit(1),
    supabase.from("services").select("id", { count: "exact", head: true }).or("is_active.eq.false,active.eq.false").is("deleted_at", null).limit(1)
  ]);

  let missingProfilesCount: number | null = null;
  try {
    const admin = await createSupabaseAdminClient();
    const { data } = await admin.auth.admin.listUsers({ perPage: 1000, page: 1 });
    const ids = data.users.map((u) => u.id);
    const { data: profiles } = ids.length ? await admin.from("profiles").select("id").in("id", ids) : { data: [] as { id: string }[] };
    const set = new Set((profiles ?? []).map((p) => p.id));
    missingProfilesCount = ids.filter((id) => !set.has(id)).length;
  } catch {
    missingProfilesCount = null;
  }

  const recentBookings = await supabase
    .from("bookings")
    .select("id, status, created_at, shop_id, barber_id")
    .order("created_at", { ascending: false })
    .limit(10);

  const recentErrors = await supabase
    .from("system_logs")
    .select("id, page, action, error_message, severity, created_at")
    .in("severity", ["error", "critical"])
    .order("created_at", { ascending: false })
    .limit(10);

  return (
    <PageFrame
      title="AI Admin Assistant (Placeholder)"
      subtitle="Structured, SQL-based diagnostics until real AI is enabled."
      actions={
        <>
          <Button asChild size="sm" variant="secondary">
            <Link href="/system-health-center">System Health Center</Link>
          </Button>
          <Button asChild size="sm" variant="secondary">
            <Link href="/data-integrity">Data Integrity</Link>
          </Button>
        </>
      }
    >
      <div className="grid grid-cols-1 gap-4">
        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="text-sm font-semibold">Why bookings dropped today?</div>
          <div className="pt-2 grid grid-cols-1 gap-2 text-sm md:grid-cols-3">
            <div className="rounded-lg border border-white/10 bg-black/20 px-3 py-2">
              <div className="text-[11px] text-muted-foreground">Today</div>
              <div className="font-semibold">{(todayBookings.count ?? 0).toLocaleString()}</div>
            </div>
            <div className="rounded-lg border border-white/10 bg-black/20 px-3 py-2">
              <div className="text-[11px] text-muted-foreground">Yesterday</div>
              <div className="font-semibold">{(yesterdayBookings.count ?? 0).toLocaleString()}</div>
            </div>
            <div className="rounded-lg border border-white/10 bg-black/20 px-3 py-2">
              <div className="text-[11px] text-muted-foreground">Last 7 days</div>
              <div className="font-semibold">{(weekBookings.count ?? 0).toLocaleString()}</div>
            </div>
          </div>
          <div className="pt-2 text-xs text-muted-foreground">
            Next: inspect payment failures + spikes in system_logs for booking actions.
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="text-sm font-semibold">Find users with missing profiles</div>
          <div className="pt-1 text-sm text-muted-foreground">
            {missingProfilesCount == null ? "Requires SUPABASE_SERVICE_ROLE_KEY in apps/admin/.env.local" : `${missingProfilesCount} auth users missing profiles row`}
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="text-sm font-semibold">Find reels not visible to clients</div>
          <div className="pt-1 text-sm text-muted-foreground">
            Pending reels: {(pendingReels.count ?? 0).toLocaleString()} • Not approved: {(hiddenReels.count ?? 0).toLocaleString()}
          </div>
          <div className="pt-2">
            <Button asChild size="sm" variant="ghost">
              <Link href="/approvals">Open Approvals</Link>
            </Button>
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="text-sm font-semibold">Find services not visible in booking</div>
          <div className="pt-1 text-sm text-muted-foreground">Inactive services: {(invisibleServices.count ?? 0).toLocaleString()}</div>
          <div className="pt-2">
            <Button asChild size="sm" variant="ghost">
              <Link href="/services">Open Services</Link>
            </Button>
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="text-sm font-semibold">Recent bookings</div>
          <pre className="mt-3 max-h-[260px] overflow-auto rounded-lg border border-white/10 bg-black/30 p-3 text-[11px] text-muted-foreground">
            {JSON.stringify(recentBookings.data ?? [], null, 2)}
          </pre>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="text-sm font-semibold">Recent errors</div>
          <pre className="mt-3 max-h-[260px] overflow-auto rounded-lg border border-white/10 bg-black/30 p-3 text-[11px] text-muted-foreground">
            {JSON.stringify(recentErrors.data ?? [], null, 2)}
          </pre>
        </LuxuryCard>
      </div>
    </PageFrame>
  );
}


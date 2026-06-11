import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getT } from "@hallaq/ui/translations-server";

import { PageFrame } from "@/components/page-frame";
import { SimpleLineChart } from "@/components/simple-line-chart";
import { getDashboardData } from "@/lib/admin/dashboard";
import { getFunnelDaily, getTopPlatforms } from "@/lib/admin/analytics-rollups";

export default async function AnalyticsPage() {
  const t = await getT();
  const data = await getDashboardData();
  const funnel = await getFunnelDaily(30);
  const platforms = await getTopPlatforms(30);

  return (
    <PageFrame title={t("admin.nav.analytics")} subtitle="Growth, revenue, and engagement intelligence.">
      <div className="grid grid-cols-1 gap-3 xl:grid-cols-2">
        <LuxuryCard className="p-5">
          <SimpleLineChart
            id="analytics-growth"
            title="Monthly Growth"
            subtitle="Platform momentum"
            points={data.monthlyGrowth}
          />
        </LuxuryCard>
        <LuxuryCard className="p-5">
          <SimpleLineChart
            id="analytics-bookings"
            title="Bookings Trend"
            subtitle="Demand signal"
            points={data.dailyBookings}
          />
        </LuxuryCard>
        <LuxuryCard className="p-5">
          <SimpleLineChart
            id="analytics-revenue"
            title="Revenue"
            subtitle="BHD per month"
            points={data.revenueGrowth}
          />
        </LuxuryCard>
        <LuxuryCard className="p-5">
          <SimpleLineChart
            id="analytics-users"
            title="New Users"
            subtitle="Registrations"
            points={data.userGrowth}
          />
        </LuxuryCard>
        <LuxuryCard className="p-5">
          <SimpleLineChart
            id="analytics-funnel-conversion"
            title="Conversion %"
            subtitle="booking_completed ÷ home_view (sessions)"
            points={funnel.conversionPoints}
          />
        </LuxuryCard>
        <LuxuryCard className="p-5">
          <SimpleLineChart id="analytics-funnel-home" title="Home Views" subtitle="Distinct sessions" points={funnel.homePoints} />
        </LuxuryCard>
        <LuxuryCard className="p-5">
          <SimpleLineChart
            id="analytics-funnel-booking-completed"
            title="Bookings Completed"
            subtitle="Distinct sessions"
            points={funnel.completedPoints}
          />
        </LuxuryCard>
        <LuxuryCard className="p-5">
          <div className="flex flex-col gap-4">
            <div className="flex flex-col gap-1">
              <div className="text-sm font-semibold tracking-tight">Top Platforms</div>
              <div className="text-xs text-muted-foreground">Sessions in the last 30 days</div>
            </div>
            <div className="space-y-2 text-sm">
              {platforms.length ? (
                platforms.map((p) => (
                  <div key={p.platform} className="flex items-center justify-between gap-3 rounded-lg border border-white/10 bg-white/5 px-3 py-2">
                    <div className="font-medium">{p.platform}</div>
                    <div className="text-muted-foreground">{p.sessions}</div>
                  </div>
                ))
              ) : (
                <div className="text-sm text-muted-foreground">No device rollup data yet. Run refresh_analytics_rollups() after events start flowing.</div>
              )}
            </div>
          </div>
        </LuxuryCard>
      </div>
    </PageFrame>
  );
}

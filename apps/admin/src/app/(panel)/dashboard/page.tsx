import {
  BadgeCheck,
  Banknote,
  CalendarCheck2,
  Store,
  UserRound,
  Users,
  Video
} from "lucide-react";

import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getT } from "@hallaq/ui/translations-server";

import { KpiCard } from "@/components/kpi-card";
import { SimpleLineChart } from "@/components/simple-line-chart";
import { getDashboardData } from "@/lib/admin/dashboard";

function formatCompactNumber(value: number) {
  return Intl.NumberFormat("en", { notation: "compact", maximumFractionDigits: 1 }).format(value);
}

function formatBhd(value: number) {
  return `${Intl.NumberFormat("en", { maximumFractionDigits: 0 }).format(value)} BHD`;
}

export default async function DashboardPage() {
  const t = await getT();
  let data: Awaited<ReturnType<typeof getDashboardData>> | null = null;
  let loadError: string | null = null;
  try {
    data = await getDashboardData();
  } catch (e) {
    loadError = e instanceof Error ? e.message : "Dashboard unavailable";
  }

  if (!data) {
    return (
      <div className="mx-auto flex w-full max-w-[1400px] flex-col gap-4 px-1 md:px-2">
        <LuxuryCard className="p-5">
          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold tracking-tight">Dashboard unavailable</div>
            <div className="text-xs text-muted-foreground">
              This usually means Supabase is not configured, migrations are missing, or the current user does not have access.
            </div>
            <div className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-xs text-muted-foreground">
              {loadError}
            </div>
          </div>
        </LuxuryCard>
      </div>
    );
  }

  return (
    <div className="mx-auto flex w-full max-w-[1400px] flex-col gap-4 px-1 md:px-2">
      <div className="flex flex-col gap-1 px-1">
        <div className="text-2xl font-semibold tracking-tight">{t("admin.dashboard.title")}</div>
        <div className="text-sm text-muted-foreground">{t("admin.dashboard.subtitle")}</div>
      </div>

      <div className="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-4">
        <KpiCard
          title={t("admin.dashboard.kpis.totalUsers")}
          value={formatCompactNumber(data.kpis.users)}
          delta={{ label: "+12.4% this month", tone: "success" }}
          icon={<Users className="h-5 w-5" />}
        />
        <KpiCard
          title={t("admin.dashboard.kpis.totalStores")}
          value={formatCompactNumber(data.kpis.stores)}
          delta={{ label: "+3.1% growth", tone: "success" }}
          icon={<Store className="h-5 w-5" />}
        />
        <KpiCard
          title={t("admin.dashboard.kpis.totalBarbers")}
          value={formatCompactNumber(data.kpis.barbers)}
          delta={{ label: "Stable", tone: "warning" }}
          icon={<UserRound className="h-5 w-5" />}
        />
        <KpiCard
          title={t("admin.dashboard.kpis.totalBookings")}
          value={formatCompactNumber(data.kpis.bookings)}
          delta={{ label: "+18.9% today", tone: "success" }}
          icon={<CalendarCheck2 className="h-5 w-5" />}
        />
        <KpiCard
          title={t("admin.dashboard.kpis.totalRevenue")}
          value={formatBhd(data.kpis.revenueBhd)}
          delta={{ label: "+6.2% WoW", tone: "success" }}
          icon={<Banknote className="h-5 w-5" />}
        />
        <KpiCard
          title={t("admin.dashboard.kpis.totalPosts")}
          value={formatCompactNumber(data.kpis.posts)}
          delta={{ label: "Content pipeline", tone: "warning" }}
          icon={<Video className="h-5 w-5" />}
        />
        <KpiCard
          title={t("admin.dashboard.kpis.totalReels")}
          value={formatCompactNumber(data.kpis.reels)}
          delta={{ label: "+9.0% engagement", tone: "success" }}
          icon={<Video className="h-5 w-5" />}
        />
        <KpiCard
          title={t("admin.dashboard.kpis.pendingApprovals")}
          value={formatCompactNumber(data.kpis.pendingApprovals)}
          delta={{ label: "Needs review", tone: "danger" }}
          icon={<BadgeCheck className="h-5 w-5" />}
        />
      </div>

      <div className="grid grid-cols-1 gap-3 xl:grid-cols-2">
        <LuxuryCard className="p-5">
          <SimpleLineChart
            id="daily-bookings"
            title="Daily Bookings"
            subtitle="Last 14 days"
            points={data.dailyBookings}
          />
        </LuxuryCard>
        <LuxuryCard className="p-5">
          <SimpleLineChart
            id="revenue-growth"
            title="Revenue Growth"
            subtitle="Last 6 months"
            points={data.revenueGrowth}
          />
        </LuxuryCard>
        <LuxuryCard className="p-5">
          <SimpleLineChart
            id="user-growth"
            title="User Growth"
            subtitle="New registrations"
            points={data.userGrowth}
          />
        </LuxuryCard>
        <LuxuryCard className="p-5">
          <SimpleLineChart
            id="store-growth"
            title="Store Growth"
            subtitle="Verified onboarding"
            points={data.storeGrowth}
          />
        </LuxuryCard>
      </div>

      <LuxuryCard className="p-5">
        <div className="flex items-center justify-between gap-4">
          <div className="flex flex-col gap-1">
            <div className="text-sm font-semibold tracking-tight">Recent Activity</div>
            <div className="text-xs text-muted-foreground">Latest events across the platform.</div>
          </div>
        </div>

        <div className="mt-4 divide-y divide-white/10">
          {data.recentActivity.map((a) => (
            <div key={a.id} className="flex items-start justify-between gap-4 py-3">
              <div className="flex flex-col gap-1">
                <div className="text-sm">
                  <span className="text-primary">{a.type}</span>
                  <span className="text-muted-foreground"> • </span>
                  <span className="font-medium">{a.title}</span>
                </div>
                <div className="text-xs text-muted-foreground">{a.subtitle}</div>
              </div>
              <div className="text-xs text-muted-foreground">{a.at}</div>
            </div>
          ))}
        </div>
      </LuxuryCard>
    </div>
  );
}

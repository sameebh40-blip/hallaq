import Link from "next/link";

import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getT } from "@hallaq/ui/translations-server";

import { PageFrame } from "@/components/page-frame";

export default async function ReportsPage() {
  const t = await getT();
  return (
    <PageFrame title={t("admin.reports.title")} subtitle={t("admin.reports.subtitle")}>
      <div className="flex flex-col gap-4">
        <LuxuryCard className="p-4">
          <div className="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
            <div className="flex flex-col gap-1">
              <div className="text-sm font-medium">Exports</div>
              <div className="text-xs text-muted-foreground">CSV</div>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              {[
                { type: "users", label: "Users" },
                { type: "bookings", label: "Bookings" },
                { type: "stores", label: "Stores" },
                { type: "barbers", label: "Barbers" },
                { type: "revenue", label: "Revenue" },
                { type: "reviews", label: "Reviews" }
              ].map((r) => (
                <Button key={r.type} asChild size="sm" variant="secondary">
                  <Link href={`/reports/export?type=${encodeURIComponent(r.type)}`}>
                    {t("admin.reports.exportCsv")} • {r.label}
                  </Link>
                </Button>
              ))}
            </div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="overflow-hidden">
          <div className="border-b border-white/10 px-4 py-3 text-sm font-medium">Notes</div>
          <div className="px-4 py-4 text-sm text-muted-foreground">
            Exports are generated directly from Supabase with admin-only access. If you need custom columns, filters,
            or date ranges, tell me which report and I will add it.
          </div>
        </LuxuryCard>
      </div>
    </PageFrame>
  );
}

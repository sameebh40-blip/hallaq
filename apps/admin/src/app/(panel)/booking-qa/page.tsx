import Link from "next/link";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type QaReport = {
  tables: Record<string, boolean>;
  rpcs: Record<string, boolean>;
  cron: { available: boolean };
  push: unknown;
};

function allOk(obj: Record<string, boolean> | undefined) {
  if (!obj) return false;
  return Object.values(obj).every(Boolean);
}

function badge(ok: boolean) {
  return ok ? "text-emerald-300 border-emerald-500/30" : "text-rose-300 border-rose-500/30";
}

export default async function BookingQaPage() {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("admin_booking_qa_report");
  const report = (data ?? null) as unknown as QaReport | null;

  const tablesOk = allOk(report?.tables);
  const rpcsOk = allOk(report?.rpcs);

  return (
    <PageFrame title="Booking QA" subtitle="Automated pass/fail checks for booking integrity, reminders, and push delivery.">
      {error ? (
        <LuxuryCard className="border border-red-500/40 bg-red-500/10 p-4 text-sm font-semibold text-red-200">
          {error.message}
        </LuxuryCard>
      ) : null}

      <div className="grid gap-4 lg:grid-cols-3">
        <LuxuryCard className="p-5">
          <div className="text-sm font-semibold">Tables</div>
          <div className="pt-1 text-xs text-muted-foreground">Required booking/push tables exist.</div>
          <div className="mt-4 grid gap-2 text-sm">
            <div className={`inline-flex items-center justify-between rounded-full border px-3 py-2 ${badge(tablesOk)}`}>
              <span className="text-muted-foreground">Overall</span>
              <span className="font-semibold">{tablesOk ? "PASS" : "FAIL"}</span>
            </div>
            {Object.entries(report?.tables ?? {}).map(([k, v]) => (
              <div key={k} className="flex items-center justify-between">
                <span className="text-muted-foreground">{k}</span>
                <span className="font-semibold">{v ? "OK" : "Missing"}</span>
              </div>
            ))}
          </div>
        </LuxuryCard>

        <LuxuryCard className="p-5">
          <div className="text-sm font-semibold">RPCs</div>
          <div className="pt-1 text-xs text-muted-foreground">Required functions are deployed.</div>
          <div className="mt-4 grid gap-2 text-sm">
            <div className={`inline-flex items-center justify-between rounded-full border px-3 py-2 ${badge(rpcsOk)}`}>
              <span className="text-muted-foreground">Overall</span>
              <span className="font-semibold">{rpcsOk ? "PASS" : "FAIL"}</span>
            </div>
            {Object.entries(report?.rpcs ?? {}).map(([k, v]) => (
              <div key={k} className="flex items-center justify-between">
                <span className="text-muted-foreground">{k}</span>
                <span className="font-semibold">{v ? "OK" : "Missing"}</span>
              </div>
            ))}
          </div>
        </LuxuryCard>

        <LuxuryCard className="p-5">
          <div className="text-sm font-semibold">Cron</div>
          <div className="pt-1 text-xs text-muted-foreground">Reminder + worker scheduling readiness.</div>
          <div className="mt-4 grid gap-2 text-sm">
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">cron available</span>
              <span className="font-semibold">{report?.cron.available ? "Yes" : "No"}</span>
            </div>
            <div className="pt-2 text-xs text-muted-foreground">
              If cron is not available, reminders and push processing won’t run automatically.
            </div>
            <div className="pt-3 flex flex-wrap gap-2">
              <Button asChild variant="secondary" size="sm">
                <Link href="/push-health">Open Push Health</Link>
              </Button>
              <Button asChild variant="secondary" size="sm">
                <Link href="/system-health">Open System Health</Link>
              </Button>
            </div>
          </div>
        </LuxuryCard>
      </div>

      <div className="mt-4 flex flex-wrap gap-2">
        <Button asChild variant="secondary" size="sm">
          <Link href="/data/bookings">Open bookings table</Link>
        </Button>
        <Button asChild variant="secondary" size="sm">
          <Link href="/data/booking_reminder_log">Open booking_reminder_log</Link>
        </Button>
        <Button asChild variant="secondary" size="sm">
          <Link href="/data/push_queue">Open push_queue</Link>
        </Button>
      </div>
    </PageFrame>
  );
}


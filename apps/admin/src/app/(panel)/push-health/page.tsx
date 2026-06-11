import Link from "next/link";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type PushHealthReport = {
  push_queue: {
    pending_total: number;
    pending_due: number;
    processing_total: number;
    sent_total: number;
    failed_total: number;
    oldest_pending_created_at: string | null;
    oldest_due_created_at: string | null;
    oldest_pending_minutes: number | null;
    oldest_due_minutes: number | null;
  };
  config: {
    push_url_set: boolean;
    push_secret_set: boolean;
  };
  cron: {
    cron_available: boolean;
    push_worker_job: boolean;
    booking_reminders_job: boolean;
  };
};

function statLabel(value: number | null | undefined) {
  const n = typeof value === "number" && Number.isFinite(value) ? value : 0;
  return n.toLocaleString();
}

function ageLabel(mins: number | null) {
  if (mins == null) return "—";
  if (mins < 60) return `${mins}m`;
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  return `${h}h ${m}m`;
}

export default async function PushHealthPage() {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("admin_get_push_delivery_health");
  const report = (data ?? null) as unknown as PushHealthReport | null;

  return (
    <PageFrame title="Push Health" subtitle="Monitor push queue backlog, cron status, and config readiness.">
      {error ? (
        <LuxuryCard className="border border-red-500/40 bg-red-500/10 p-4 text-sm font-semibold text-red-200">
          {error.message}
        </LuxuryCard>
      ) : null}

      <div className="grid gap-4 lg:grid-cols-3">
        <LuxuryCard className="p-5">
          <div className="text-sm font-semibold">Queue</div>
          <div className="pt-1 text-xs text-muted-foreground">Pending / due / processing.</div>
          <div className="mt-4 grid gap-2 text-sm">
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">Pending</span>
              <span className="font-semibold">{statLabel(report?.push_queue.pending_total)}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">Due now</span>
              <span className="font-semibold">{statLabel(report?.push_queue.pending_due)}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">Processing</span>
              <span className="font-semibold">{statLabel(report?.push_queue.processing_total)}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">Sent</span>
              <span className="font-semibold">{statLabel(report?.push_queue.sent_total)}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">Failed</span>
              <span className="font-semibold">{statLabel(report?.push_queue.failed_total)}</span>
            </div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="p-5">
          <div className="text-sm font-semibold">Backlog Age</div>
          <div className="pt-1 text-xs text-muted-foreground">Oldest pending items (created_at).</div>
          <div className="mt-4 grid gap-2 text-sm">
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">Oldest pending</span>
              <span className="font-semibold">{ageLabel(report?.push_queue.oldest_pending_minutes ?? null)}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">Oldest due</span>
              <span className="font-semibold">{ageLabel(report?.push_queue.oldest_due_minutes ?? null)}</span>
            </div>
            <div className="pt-2 text-xs text-muted-foreground">
              If oldest due keeps growing, the worker is not running or is failing authentication.
            </div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="p-5">
          <div className="text-sm font-semibold">Config + Cron</div>
          <div className="pt-1 text-xs text-muted-foreground">Push URL/secret presence and job scheduling.</div>
          <div className="mt-4 grid gap-2 text-sm">
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">push_url set</span>
              <span className="font-semibold">{report?.config.push_url_set ? "Yes" : "No"}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">push_secret set</span>
              <span className="font-semibold">{report?.config.push_secret_set ? "Yes" : "No"}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">cron available</span>
              <span className="font-semibold">{report?.cron.cron_available ? "Yes" : "No"}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">push_worker job</span>
              <span className="font-semibold">{report?.cron.push_worker_job ? "Yes" : "No"}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">booking_reminders job</span>
              <span className="font-semibold">{report?.cron.booking_reminders_job ? "Yes" : "No"}</span>
            </div>
          </div>
        </LuxuryCard>
      </div>

      <div className="mt-4 flex flex-wrap gap-2">
        <Button asChild variant="secondary" size="sm">
          <Link href="/data/push_queue">Open push_queue table</Link>
        </Button>
        <Button asChild variant="secondary" size="sm">
          <Link href="/data/notifications">Open notifications table</Link>
        </Button>
        <Button asChild variant="secondary" size="sm">
          <Link href="/appointments">Open appointments</Link>
        </Button>
      </div>
    </PageFrame>
  );
}


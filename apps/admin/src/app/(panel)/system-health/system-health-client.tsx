"use client";

import { useActionState, useMemo } from "react";

import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { runFullCircleTest, runFullSystemTest, type DiagnosticRun } from "./actions";

function statusIcon(status: DiagnosticRun["items"][number]["status"]) {
  if (status === "ok") return "✅";
  if (status === "warning") return "⚠️";
  if (status === "skipped") return "⚠️";
  return "❌";
}

function statusTone(status: DiagnosticRun["items"][number]["status"]) {
  if (status === "ok") return "text-emerald-200";
  if (status === "warning") return "text-amber-200";
  if (status === "skipped") return "text-muted-foreground";
  return "text-rose-200";
}

function RunResults({ title, state }: { title: string; state: DiagnosticRun | null }) {
  const rows = useMemo(() => state?.items ?? [], [state]);

  const summary = useMemo(() => {
    const totals = { ok: 0, warning: 0, broken: 0, skipped: 0 };
    for (const r of rows) totals[r.status] += 1;
    return totals;
  }, [rows]);

  if (!state) return null;

  return (
    <LuxuryCard className="p-5">
      <div className="flex flex-col gap-3">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="text-sm font-semibold">{title}</div>
          <div className="text-xs text-muted-foreground">
            {summary.ok} ok • {summary.warning} warnings • {summary.broken} broken • {summary.skipped} skipped
          </div>
        </div>
        <div className="text-xs text-muted-foreground">
          Run {state.runId} • {state.startedAt} → {state.finishedAt}
        </div>
        <div className="grid gap-2 text-sm">
          {rows.map((r) => (
            <div key={r.id} className="flex items-start justify-between gap-4 rounded-lg border border-white/10 bg-white/5 px-3 py-2">
              <div className="min-w-0">
                <div className="truncate">{r.label}</div>
                {r.detail ? <div className="break-all text-xs text-muted-foreground">{r.detail}</div> : null}
              </div>
              <div className={`shrink-0 text-right text-xs ${statusTone(r.status)}`}>
                {statusIcon(r.status)} {r.status.toUpperCase()}
              </div>
            </div>
          ))}
        </div>
      </div>
    </LuxuryCard>
  );
}

export function SystemHealthClient() {
  const [systemState, runSystem, systemPending] = useActionState<DiagnosticRun | null>(runFullSystemTest, null);
  const [circleState, runCircle, circlePending] = useActionState<DiagnosticRun | null>(
    runFullCircleTest as unknown as (state: DiagnosticRun | null) => Promise<DiagnosticRun | null>,
    null
  );

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-end gap-2">
        <form action={runSystem}>
          <Button type="submit" className="h-11" disabled={systemPending || circlePending}>
            Run Full System Test
          </Button>
        </form>
        <form action={runCircle}>
          <Button type="submit" variant="secondary" className="h-11" disabled={systemPending || circlePending}>
            Run Full Circle Test
          </Button>
        </form>
      </div>

      <RunResults title="Full System Test Results" state={systemState} />
      <RunResults title="Full Circle Test Results" state={circleState} />
    </div>
  );
}

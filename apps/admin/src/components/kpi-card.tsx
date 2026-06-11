import type { ReactNode } from "react";

import { cn } from "@hallaq/ui/cn";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

export function KpiCard({
  title,
  value,
  delta,
  icon,
  className
}: {
  title: string;
  value: string;
  delta?: { label: string; tone?: "success" | "warning" | "danger" };
  icon?: ReactNode;
  className?: string;
}) {
  return (
    <LuxuryCard className={cn("p-5", className)}>
      <div className="relative z-10 flex items-start justify-between gap-4">
        <div className="flex flex-col gap-2">
          <div className="text-xs font-medium tracking-wide text-muted-foreground">{title}</div>
          <div className="text-2xl font-semibold tracking-tight">{value}</div>
          {delta ? (
            <div
              className={cn(
                "w-fit rounded-full border px-2.5 py-1 text-[11px]",
                delta.tone === "success"
                  ? "border-emerald-500/25 bg-emerald-500/10 text-emerald-200"
                  : delta.tone === "warning"
                    ? "border-amber-500/25 bg-amber-500/10 text-amber-100"
                    : delta.tone === "danger"
                      ? "border-rose-500/25 bg-rose-500/10 text-rose-200"
                      : "border-white/10 bg-white/5 text-muted-foreground"
              )}
            >
              {delta.label}
            </div>
          ) : null}
        </div>
        {icon ? (
          <div className="grid h-10 w-10 place-items-center rounded-lg border border-white/10 bg-white/5 text-primary">
            {icon}
          </div>
        ) : null}
      </div>
    </LuxuryCard>
  );
}


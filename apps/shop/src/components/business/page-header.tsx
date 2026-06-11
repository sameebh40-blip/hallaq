import type { ReactNode } from "react";

import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { cn } from "@hallaq/ui/cn";

export function BusinessPageHeader({
  title,
  subtitle,
  actions,
  className
}: {
  title: string;
  subtitle?: string;
  actions?: ReactNode;
  className?: string;
}) {
  return (
    <LuxuryCard className={cn("p-4", className)}>
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div className="flex flex-col gap-1">
          <div className="text-base font-semibold">{title}</div>
          {subtitle ? <div className="text-sm text-muted-foreground">{subtitle}</div> : null}
        </div>
        {actions ? <div className="flex items-center gap-2">{actions}</div> : null}
      </div>
    </LuxuryCard>
  );
}


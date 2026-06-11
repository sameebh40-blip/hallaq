import type { ReactNode } from "react";

import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { cn } from "@hallaq/ui/cn";

export function PageFrame({
  title,
  subtitle,
  actions,
  children,
  className
}: {
  title: string;
  subtitle?: string;
  actions?: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("mx-auto flex w-full max-w-[1400px] flex-col gap-4 px-1 md:px-2", className)}>
      <div className="flex flex-col gap-1 px-1">
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col gap-1">
            <div className="text-2xl font-semibold tracking-tight">{title}</div>
            {subtitle ? <div className="text-sm text-muted-foreground">{subtitle}</div> : null}
          </div>
          {actions ? <div className="flex items-center gap-2">{actions}</div> : null}
        </div>
      </div>
      <LuxuryCard className="p-5">{children}</LuxuryCard>
    </div>
  );
}


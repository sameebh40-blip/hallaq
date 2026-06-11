import type { HTMLAttributes } from "react";

import { cn } from "./cn";

export function LuxuryCard({
  className,
  ...props
}: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        "relative overflow-hidden rounded-lg border border-white/10 bg-white/5 shadow-soft backdrop-blur",
        "before:pointer-events-none before:absolute before:inset-0 before:bg-glass-sheen before:opacity-70 before:content-['']",
        "after:pointer-events-none after:absolute after:-inset-24 after:bg-[radial-gradient(circle_at_top,hsl(var(--gold)/0.20),transparent_60%)] after:opacity-70 after:content-['']",
        className
      )}
      {...props}
    />
  );
}

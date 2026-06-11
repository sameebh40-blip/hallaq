import type { ReactNode } from "react";
import Link from "next/link";

import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { HallaqGoldLogo } from "@/components/hallaq-logo";

export default function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <main className="relative min-h-dvh">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(900px_600px_at_20%_0%,hsl(var(--gold)/0.18),transparent_60%),radial-gradient(700px_480px_at_85%_0%,hsl(var(--gold)/0.10),transparent_55%)]" />

      <div className="relative mx-auto grid min-h-dvh max-w-6xl grid-cols-1 items-center gap-6 px-4 py-10 lg:grid-cols-2">
        <div className="hidden flex-col gap-6 lg:flex">
          <div className="flex items-center gap-4">
            <HallaqGoldLogo assetKey="login_logo" className="h-14 w-14" />
            <div className="flex flex-col leading-tight">
              <div className="text-sm font-semibold tracking-[0.28em] text-primary">HALLAQ</div>
              <div className="text-3xl font-semibold tracking-tight">Super Admin Panel</div>
            </div>
          </div>

          <LuxuryCard className="p-6">
            <div className="flex flex-col gap-3">
              <div className="text-sm font-medium">Enterprise security</div>
              <div className="text-sm text-muted-foreground">
                Admin-only access. Protected routes, session management, and audit-ready workflows.
              </div>
              <div className="mt-2 grid grid-cols-3 gap-3 text-xs text-muted-foreground">
                <div className="rounded-lg border border-white/10 bg-white/5 p-3">RBAC</div>
                <div className="rounded-lg border border-white/10 bg-white/5 p-3">Logs</div>
                <div className="rounded-lg border border-white/10 bg-white/5 p-3">Policies</div>
              </div>
            </div>
          </LuxuryCard>
        </div>

        <div className="flex flex-col gap-5">
          <div className="flex items-center justify-between">
            <Link href="/dashboard" className="flex items-center gap-3 lg:hidden">
              <HallaqGoldLogo assetKey="login_logo" className="h-10 w-10" />
              <div className="flex flex-col leading-tight">
                <div className="text-sm font-semibold tracking-wide">HALLAQ</div>
                <div className="text-xs text-muted-foreground">Admin</div>
              </div>
            </Link>

            <div className="flex items-center gap-2">
              <Button asChild variant="ghost" size="sm">
                <Link href="/locale?value=ar">AR</Link>
              </Button>
              <Button asChild variant="ghost" size="sm">
                <Link href="/locale?value=en">EN</Link>
              </Button>
            </div>
          </div>

          <LuxuryCard className="p-6">{children}</LuxuryCard>

          <div className="text-center text-xs text-muted-foreground">
            <span className="text-primary">Hallaq</span>
            <span className="text-muted-foreground"> • </span>
            <Link href="/dashboard" className="underline underline-offset-4">
              Admin portal
            </Link>
          </div>
        </div>
      </div>
    </main>
  );
}

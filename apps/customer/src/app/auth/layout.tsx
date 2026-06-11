import type { ReactNode } from "react";
import Link from "next/link";

import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { Button } from "@hallaq/ui/button";

export default function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <main className="mx-auto flex min-h-dvh max-w-lg flex-col justify-center gap-6 px-4 py-12">
      <div className="flex items-center justify-between">
        <div className="text-sm font-medium tracking-wide">HALLAQ</div>
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
        <Link href="/" className="underline underline-offset-4">
          Home
        </Link>
      </div>
    </main>
  );
}


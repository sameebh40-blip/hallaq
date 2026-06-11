"use client";

import Link from "next/link";

import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

export default function GlobalError({ reset }: { error: Error; reset: () => void }) {
  return (
    <main className="mx-auto flex min-h-dvh max-w-lg flex-col justify-center gap-6 px-6 py-12">
      <LuxuryCard className="p-6">
        <div className="flex flex-col gap-3">
          <div className="text-lg font-semibold">Something went wrong</div>
          <div className="text-sm text-muted-foreground">Please try again.</div>
          <div className="flex items-center gap-2 pt-2">
            <Button onClick={() => reset()} variant="secondary">
              Retry
            </Button>
            <Button asChild variant="ghost">
              <Link href="/">Home</Link>
            </Button>
          </div>
        </div>
      </LuxuryCard>
    </main>
  );
}

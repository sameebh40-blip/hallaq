import Link from "next/link";

import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

export default function NotFound() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-lg flex-col justify-center gap-6 px-6 py-12">
      <LuxuryCard className="p-6">
        <div className="flex flex-col gap-3">
          <div className="text-lg font-semibold">Page not found</div>
          <div className="text-sm text-muted-foreground">The page you requested does not exist.</div>
          <div className="pt-2">
            <Button asChild variant="secondary">
              <Link href="/">Go home</Link>
            </Button>
          </div>
        </div>
      </LuxuryCard>
    </main>
  );
}


import Link from "next/link";

import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

export default function AccessDeniedPage() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-lg flex-col justify-center gap-6 px-4 py-12">
      <LuxuryCard className="p-6">
        <div className="flex flex-col gap-3">
          <div className="text-lg font-semibold">Access denied</div>
          <div className="text-sm text-muted-foreground">
            This area is only for admins.
          </div>
          <div className="flex items-center gap-2 pt-2">
            <Button asChild variant="secondary">
              <Link href="/auth/sign-in">Sign in</Link>
            </Button>
            <Button asChild variant="ghost">
              <Link href="/dashboard">Back</Link>
            </Button>
          </div>
        </div>
      </LuxuryCard>
    </main>
  );
}

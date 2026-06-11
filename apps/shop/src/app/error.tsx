"use client";

import { useEffect } from "react";

import Link from "next/link";

import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

export default function GlobalError({ error, reset }: { error: Error; reset: () => void }) {
  useEffect(() => {
    console.error(error);
    const page = typeof window !== "undefined" ? window.location.pathname : null;
    void fetch("/shop/api/system-logs", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        page,
        action: "global_error",
        error_message: error.message,
        stack_trace: error.stack,
        severity: error.name === "SupabaseNotConfiguredError" ? "critical" : "error",
        meta: { name: error.name }
      })
    }).catch(() => null);
  }, [error]);

  const isSupabaseNotConfigured = error.name === "SupabaseNotConfiguredError";

  return (
    <main className="mx-auto flex min-h-dvh max-w-lg flex-col justify-center gap-6 px-4 py-12">
      <LuxuryCard className="p-6">
        <div className="flex flex-col gap-3">
          <div className="text-lg font-semibold">
            {isSupabaseNotConfigured ? "Service unavailable" : "This page didn’t load"}
          </div>
          <div className="text-sm text-muted-foreground">
            {isSupabaseNotConfigured
              ? "This dashboard is not ready yet. Please try again in a moment."
              : "Please try again."}
          </div>
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

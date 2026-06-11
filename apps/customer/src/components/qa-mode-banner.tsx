"use client";

import { useState } from "react";

import { Button } from "@hallaq/ui/button";

export function QaModeBanner({ exitTo }: { exitTo?: string }) {
  const [busy, setBusy] = useState(false);

  return (
    <div className="fixed inset-x-0 top-0 z-50 border-b border-black/10 bg-black text-white">
      <div className="mx-auto flex max-w-md items-center justify-between gap-3 px-4 py-2 text-xs font-semibold">
        <div>QA MODE ACTIVE</div>
        <Button
          type="button"
          variant="secondary"
          size="sm"
          className="h-7"
          disabled={busy}
          onClick={async () => {
            if (busy) return;
            setBusy(true);
            try {
              await fetch("/api/qa/exit", { method: "POST" });
            } finally {
              window.location.href = exitTo ?? "/";
            }
          }}
        >
          Exit
        </Button>
      </div>
    </div>
  );
}


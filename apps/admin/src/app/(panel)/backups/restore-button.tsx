"use client";

import { useMemo, useState } from "react";

import { Button } from "@hallaq/ui/button";
import { cn } from "@hallaq/ui/cn";
import { Input } from "@hallaq/ui/input";

export function RestoreButton({ backupLogId }: { backupLogId: string }) {
  const [open, setOpen] = useState(false);
  const [confirm, setConfirm] = useState("");
  const [busy, setBusy] = useState(false);
  const canSubmit = useMemo(() => confirm.trim() === "RESTORE" && !busy, [confirm, busy]);

  return (
    <>
      <Button type="button" size="sm" variant="secondary" onClick={() => setOpen(true)}>
        Restore
      </Button>
      {open ? (
        <div className="fixed inset-0 z-50 grid place-items-center bg-black/60 px-4">
          <div className="w-full max-w-md rounded-xl border border-white/10 bg-[#0b0b0b] p-5 text-white shadow-[0_20px_80px_rgba(0,0,0,0.55)]">
            <div className="text-sm font-semibold">Restore From Backup</div>
            <div className="pt-2 text-xs text-white/70">
              This is a destructive operation. Type <span className="font-mono text-white">RESTORE</span> to continue.
            </div>
            <div className="pt-4">
              <Input
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                placeholder="Type RESTORE"
                className="h-11 bg-white/5 text-white"
              />
            </div>
            <div className="flex items-center justify-end gap-2 pt-4">
              <Button
                type="button"
                variant="ghost"
                onClick={() => {
                  if (busy) return;
                  setOpen(false);
                  setConfirm("");
                }}
              >
                Cancel
              </Button>
              <Button
                type="button"
                className={cn("h-11", !canSubmit && "opacity-60")}
                disabled={!canSubmit}
                onClick={async () => {
                  if (!canSubmit) return;
                  setBusy(true);
                  try {
                    const res = await fetch("/api/backups/restore", {
                      method: "POST",
                      headers: { "content-type": "application/json" },
                      body: JSON.stringify({ backup_log_id: backupLogId, confirm: confirm.trim() })
                    });
                    if (!res.ok) return;
                    window.location.reload();
                  } finally {
                    setBusy(false);
                  }
                }}
              >
                Confirm Restore
              </Button>
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}


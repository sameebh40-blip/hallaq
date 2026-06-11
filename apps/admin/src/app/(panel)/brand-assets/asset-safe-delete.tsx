"use client";

import { useEffect, useMemo, useState } from "react";

import { createSupabaseBrowserClient } from "@hallaq/supabase/browser";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

type UsageRow = {
  entity: string;
  field: string;
  usage_count: number;
};

export function AssetSafeDelete({
  open,
  assetKey,
  label,
  isActive,
  onClose,
  onConfirm
}: {
  open: boolean;
  assetKey: string | null;
  label: string | null;
  isActive: boolean;
  onClose: () => void;
  onConfirm: () => Promise<void>;
}) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [rows, setRows] = useState<UsageRow[]>([]);
  const [busy, setBusy] = useState(false);

  const nonZero = useMemo(() => rows.filter((r) => (r.usage_count ?? 0) > 0), [rows]);
  const blockedByUsage = nonZero.length > 0;
  const title = label || assetKey || "Asset";

  useEffect(() => {
    if (!open || !assetKey) return;
    setLoading(true);
    setError("");
    void (async () => {
      try {
        const supabase = createSupabaseBrowserClient();
        const { data, error } = await supabase.rpc("brand_asset_usage", { p_asset_key: assetKey });
        if (error) throw error;
        setRows((data ?? []) as UsageRow[]);
      } catch (e) {
        setError(e instanceof Error ? e.message : "Failed to load usage");
        setRows([]);
      } finally {
        setLoading(false);
      }
    })();
  }, [open, assetKey]);

  if (!open || !assetKey) return null;

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/70 p-4">
      <LuxuryCard className="w-full max-w-[760px] border border-white/10 bg-[#070707] p-4 md:p-5">
        <div className="flex flex-col gap-4">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div className="flex flex-col gap-1">
              <div className="text-base font-semibold">Safe Delete</div>
              <div className="text-xs text-muted-foreground">{title}</div>
              <div className="text-[11px] text-muted-foreground">{assetKey}</div>
            </div>
            <div className="flex items-center gap-2">
              <Button type="button" variant="secondary" onClick={onClose} disabled={busy}>
                Cancel
              </Button>
              <Button
                type="button"
                variant="ghost"
                disabled={busy || isActive || blockedByUsage}
                onClick={async () => {
                  setBusy(true);
                  setError("");
                  try {
                    await onConfirm();
                    onClose();
                  } catch (e) {
                    setError(e instanceof Error ? e.message : "Delete failed");
                  } finally {
                    setBusy(false);
                  }
                }}
              >
                Delete
              </Button>
            </div>
          </div>

          {isActive ? (
            <LuxuryCard className="border border-amber-500/25 bg-amber-500/10 p-3 text-sm text-amber-200">
              This asset is active. Deactivate it first, then delete.
            </LuxuryCard>
          ) : null}

          {blockedByUsage ? (
            <LuxuryCard className="border border-amber-500/25 bg-amber-500/10 p-3 text-sm text-amber-200">
              This asset is currently used by live records. Replace those records (or apply a different default) before deleting.
            </LuxuryCard>
          ) : null}

          {error ? <LuxuryCard className="border border-rose-500/25 bg-rose-500/10 p-3 text-sm text-rose-200">{error}</LuxuryCard> : null}

          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Usage</div>
            {loading ? <div className="text-sm text-muted-foreground">Scanning usage…</div> : null}
            {!loading && !nonZero.length ? <div className="text-sm text-muted-foreground">No direct usage found.</div> : null}

            {nonZero.length ? (
              <div className="grid grid-cols-1 gap-2">
                {nonZero.map((r) => (
                  <div key={`${r.entity}.${r.field}`} className="flex items-center justify-between rounded-lg border border-white/10 bg-white/5 px-3 py-2">
                    <div className="text-xs font-semibold">
                      {r.entity}.{r.field}
                    </div>
                    <div className="text-xs text-muted-foreground">{Number(r.usage_count).toLocaleString()}</div>
                  </div>
                ))}
              </div>
            ) : null}
          </div>

          <div className="text-xs text-muted-foreground">
            Delete clears the active brand asset URL from the database. Version history remains available for restore.
          </div>
        </div>
      </LuxuryCard>
    </div>
  );
}

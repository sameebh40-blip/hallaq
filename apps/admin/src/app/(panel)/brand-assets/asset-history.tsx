"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import { createSupabaseBrowserClient } from "@hallaq/supabase/browser";
import { Button } from "@hallaq/ui/button";
import { cn } from "@hallaq/ui/cn";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { SafeImage } from "@hallaq/brand-assets/react";

type VersionRow = {
  id: string;
  asset_key: string;
  asset_url: string | null;
  bucket: string | null;
  path: string | null;
  version_number: number;
  created_by: string | null;
  created_at: string;
  is_active: boolean;
};

function formatDate(value: string | null | undefined) {
  const v = typeof value === "string" ? value.trim() : "";
  if (!v) return "—";
  const d = new Date(v);
  return Number.isFinite(d.getTime()) ? d.toLocaleString() : "—";
}

export function AssetHistory({
  open,
  assetKey,
  assetLabel,
  onClose,
  onRestored
}: {
  open: boolean;
  assetKey: string | null;
  assetLabel: string | null;
  onClose: () => void;
  onRestored: () => Promise<void>;
}) {
  const [rows, setRows] = useState<VersionRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [busyVersion, setBusyVersion] = useState<number | null>(null);
  const [error, setError] = useState("");

  const title = assetLabel || assetKey || "Asset History";

  const load = useCallback(async () => {
    if (!assetKey) return;
    setError("");
    setLoading(true);
    try {
      const supabase = createSupabaseBrowserClient();
      const { data, error } = await supabase
        .from("asset_versions")
        .select("id, asset_key, asset_url, bucket, path, version_number, created_by, created_at, is_active")
        .eq("asset_key", assetKey)
        .order("version_number", { ascending: false })
        .limit(50);
      if (error) throw error;
      setRows((data ?? []) as VersionRow[]);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load version history");
    } finally {
      setLoading(false);
    }
  }, [assetKey]);

  useEffect(() => {
    if (!open) return;
    void load();
  }, [open, load]);

  const compare = useMemo(() => {
    const active = rows.find((r) => r.is_active) ?? null;
    const previous = rows.find((r) => !r.is_active && r.asset_url) ?? null;
    return { active, previous };
  }, [rows]);

  if (!open || !assetKey) return null;

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/70 p-4">
      <LuxuryCard className="w-full max-w-[1100px] border border-white/10 bg-[#070707] p-4 md:p-5">
        <div className="flex flex-col gap-4">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div className="flex flex-col gap-1">
              <div className="text-base font-semibold">{title}</div>
              <div className="text-xs text-muted-foreground">{assetKey}</div>
            </div>
            <Button type="button" variant="secondary" onClick={onClose}>
              Close
            </Button>
          </div>

          {error ? <LuxuryCard className="border border-rose-500/25 bg-rose-500/10 p-3 text-sm text-rose-200">{error}</LuxuryCard> : null}

          {compare.active && compare.previous ? (
            <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
              <LuxuryCard className="border border-white/10 bg-white/5 p-3">
                <div className="text-[11px] font-semibold text-muted-foreground">Active</div>
                <div className="mt-2 overflow-hidden rounded-lg border border-white/10 bg-black/30">
                  <div className="relative aspect-[16/9] w-full">
                    <SafeImage src={compare.active.asset_url} fallbackKey={assetKey} alt="" className="h-full w-full object-cover" unoptimized />
                  </div>
                </div>
              </LuxuryCard>
              <LuxuryCard className="border border-white/10 bg-white/5 p-3">
                <div className="text-[11px] font-semibold text-muted-foreground">Previous</div>
                <div className="mt-2 overflow-hidden rounded-lg border border-white/10 bg-black/30">
                  <div className="relative aspect-[16/9] w-full">
                    <SafeImage src={compare.previous.asset_url} fallbackKey={assetKey} alt="" className="h-full w-full object-cover" unoptimized />
                  </div>
                </div>
              </LuxuryCard>
            </div>
          ) : null}

          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Versions</div>
            {loading ? <div className="text-sm text-muted-foreground">Loading…</div> : null}

            <div className="grid grid-cols-1 gap-2">
              {rows.map((r) => {
                const busy = busyVersion === r.version_number;
                return (
                  <LuxuryCard key={r.id} className="border border-white/10 bg-white/5 p-3">
                    <div className="flex flex-wrap items-center justify-between gap-3">
                      <div className="flex items-center gap-3">
                        <div className="h-12 w-16 overflow-hidden rounded-md border border-white/10 bg-black/30">
                          <SafeImage src={r.asset_url} fallbackKey={assetKey} alt="" className="h-full w-full object-cover" unoptimized />
                        </div>
                        <div className="flex flex-col gap-1">
                          <div className="text-xs font-semibold">v{r.version_number}</div>
                          <div className="text-[11px] text-muted-foreground">{formatDate(r.created_at)}</div>
                        </div>
                        {r.is_active ? (
                          <span className="rounded-full border border-emerald-500/30 bg-emerald-500/10 px-2 py-0.5 text-[11px] font-semibold text-emerald-200">
                            Active
                          </span>
                        ) : null}
                      </div>
                      <div className="flex items-center gap-2">
                        <Button asChild type="button" variant="ghost" disabled={!r.asset_url}>
                          <a href={r.asset_url ?? "#"} target="_blank" rel="noopener noreferrer">
                            Preview
                          </a>
                        </Button>
                        <Button
                          type="button"
                          className={cn(r.is_active ? "pointer-events-none opacity-60" : "")}
                          onClick={async () => {
                            if (r.is_active) return;
                            setError("");
                            setBusyVersion(r.version_number);
                            try {
                              const supabase = createSupabaseBrowserClient();
                              const {
                                data: { user }
                              } = await supabase.auth.getUser();
                              const userId = user?.id ?? null;
                              const { error } = await supabase.rpc("restore_brand_asset_version", {
                                p_asset_key: assetKey,
                                p_version_number: r.version_number,
                                p_user_id: userId
                              });
                              if (error) throw error;
                              await onRestored();
                              await load();
                            } catch (e) {
                              setError(e instanceof Error ? e.message : "Restore failed");
                            } finally {
                              setBusyVersion(null);
                            }
                          }}
                          disabled={busy}
                        >
                          Restore
                        </Button>
                      </div>
                    </div>
                  </LuxuryCard>
                );
              })}
            </div>
          </div>
        </div>
      </LuxuryCard>
    </div>
  );
}

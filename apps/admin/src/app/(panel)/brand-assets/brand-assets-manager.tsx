"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { createSupabaseBrowserClient } from "@hallaq/supabase/browser";
import { Button } from "@hallaq/ui/button";
import { cn } from "@hallaq/ui/cn";
import { Input } from "@hallaq/ui/input";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { SafeImage, useBrandAssets } from "@hallaq/brand-assets/react";
import type { BrandAssetRow } from "@hallaq/brand-assets";

import { optimizeImageFile } from "@/lib/media/optimize-image-file";
import { ADMIN_RASTER_IMAGE_EXTENSIONS, getLowercaseExtension } from "@/lib/media/upload-constraints";

import { AssetEditor, type BrandAssetDefinition } from "./asset-editor";
import { AssetHistory } from "./asset-history";
import { AssetSafeDelete } from "./asset-safe-delete";

type AssetRow = Pick<BrandAssetRow, "asset_key" | "asset_url" | "is_active" | "updated_at" | "created_at" | "updated_by"> & {
  bucket?: string | null;
  path?: string | null;
};

type DefinitionRow = BrandAssetDefinition;

type AssetItem = {
  definition: DefinitionRow;
  asset: AssetRow | null;
};

function sanitizeFilename(name: string) {
  const v = String(name || "file").trim();
  return v.replaceAll(/[^\w.\-]+/g, "_");
}

function formatDate(value: string | null | undefined) {
  const v = typeof value === "string" ? value.trim() : "";
  if (!v) return "—";
  const d = new Date(v);
  return Number.isFinite(d.getTime()) ? d.toLocaleString() : "—";
}

function normalizeUrl(value: unknown) {
  const v = typeof value === "string" ? value.trim() : "";
  return v || null;
}

function canUploadFile(file: File) {
  if (!file || file.size <= 0) return false;
  const type = (file.type ?? "").toLowerCase();
  if (type.startsWith("image/") && type !== "image/svg+xml") return true;
  return ADMIN_RASTER_IMAGE_EXTENSIONS.includes(getLowercaseExtension(file.name) as (typeof ADMIN_RASTER_IMAGE_EXTENSIONS)[number]);
}

function canOptimizeRaster(mimeType: string, fileName: string) {
  const type = (mimeType ?? "").toLowerCase();
  if (type.startsWith("image/") && type !== "image/svg+xml") return true;
  return ADMIN_RASTER_IMAGE_EXTENSIONS.includes(getLowercaseExtension(fileName) as (typeof ADMIN_RASTER_IMAGE_EXTENSIONS)[number]);
}

function toErrorMessage(e: unknown) {
  if (e instanceof Error) return e.message;
  if (e && typeof e === "object" && "message" in e) {
    const m = (e as { message?: unknown }).message;
    if (typeof m === "string" && m.trim()) return m.trim();
  }
  return "Failed to load brand assets";
}

export function BrandAssetsManager() {
  const { refresh: refreshBrandAssets, loading: brandAssetsLoading, version } = useBrandAssets();
  const [definitions, setDefinitions] = useState<DefinitionRow[]>([]);
  const [assets, setAssets] = useState<Map<string, AssetRow>>(new Map());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string>("");
  const [busyKey, setBusyKey] = useState<string>("");
  const [ok, setOk] = useState<string>("");
  const [editorOpen, setEditorOpen] = useState(false);
  const [editorDefinition, setEditorDefinition] = useState<DefinitionRow | null>(null);
  const [editorFile, setEditorFile] = useState<File | null>(null);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [historyKey, setHistoryKey] = useState<string | null>(null);
  const [historyLabel, setHistoryLabel] = useState<string | null>(null);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleteDefinition, setDeleteDefinition] = useState<DefinitionRow | null>(null);
  const [deleteActive, setDeleteActive] = useState(false);
  const objectUrlRefs = useRef<Map<string, string>>(new Map());
  const fileInputRefs = useRef<Map<string, HTMLInputElement>>(new Map());

  const sections = useMemo(() => {
    const map = new Map<string, AssetItem[]>();
    for (const d of definitions) {
      const section = d.section || "Assets";
      const list = map.get(section) ?? [];
      list.push({ definition: d, asset: assets.get(d.asset_key) ?? null });
      map.set(section, list);
    }
    return Array.from(map.entries()).map(([section, items]) => ({ section, items }));
  }, [definitions, assets]);

  const loadAll = useCallback(async () => {
    setError("");
    setOk("");
    setLoading(true);
    try {
      const supabase = createSupabaseBrowserClient();

      const [{ data: defs, error: defsError }, { data: assetRows, error: assetsError }] = await Promise.all([
        supabase
          .from("brand_asset_definitions")
          .select("asset_key, section, label, folder, crop_ratio")
          .order("section", { ascending: true })
          .order("label", { ascending: true }),
        supabase
          .from("brand_assets")
          .select("asset_key, asset_url, is_active, updated_at, created_at, updated_by, bucket, path")
          .order("asset_key", { ascending: true })
      ]);

      if (defsError) throw defsError;
      if (assetsError) throw assetsError;

      const defRows = (defs ?? []) as DefinitionRow[];
      const map = new Map<string, AssetRow>();
      for (const r of (assetRows ?? []) as AssetRow[]) map.set(String(r.asset_key), r);

      setDefinitions(defRows);
      setAssets(map);
    } catch (e) {
      setError(toErrorMessage(e));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadAll();
    return () => {
      const refs = objectUrlRefs.current;
      for (const url of refs.values()) URL.revokeObjectURL(url);
      refs.clear();
    };
  }, [loadAll]);

  async function uploadAsset(definition: DefinitionRow, input: { blob: Blob; fileName: string; mimeType: string }) {
    setError("");
    setOk("");
    setBusyKey(definition.asset_key);
    try {
      const supabase = createSupabaseBrowserClient();
      const {
        data: { user }
      } = await supabase.auth.getUser();
      const userId = user?.id ?? null;
      let uploadBlob = input.blob;
      let uploadFileName = input.fileName;
      let uploadMimeType = input.mimeType;

      if (canOptimizeRaster(input.mimeType, input.fileName)) {
        const optimized = await optimizeImageFile(
          new File([input.blob], input.fileName || "asset.jpg", {
            type: input.mimeType || "image/jpeg",
            lastModified: Date.now()
          })
        );
        uploadBlob = optimized.file;
        uploadFileName = optimized.file.name;
        uploadMimeType = optimized.file.type || input.mimeType;
      }

      const timestamp = Date.now();
      const safeName = sanitizeFilename(uploadFileName);
      const objectPath = `${definition.folder}/${definition.asset_key}/${timestamp}_${safeName}`;

      const { error: uploadError } = await supabase.storage.from("brand-assets").upload(objectPath, uploadBlob, {
        cacheControl: "3600",
        upsert: false,
        contentType: uploadMimeType || undefined
      });

      if (uploadError) throw uploadError;

      const publicUrl = supabase.storage.from("brand-assets").getPublicUrl(objectPath).data.publicUrl;

      const { error: upsertError } = await supabase.from("brand_assets").upsert(
        {
          asset_key: definition.asset_key,
          asset_name: definition.label,
          asset_type: null,
          asset_url: publicUrl,
          is_active: true,
          bucket: "brand-assets",
          path: objectPath,
          updated_by: userId,
          updated_at: new Date().toISOString()
        },
        { onConflict: "asset_key" }
      );

      if (upsertError) throw upsertError;

      setOk(
        uploadBlob.size < input.blob.size
          ? `Updated ${definition.asset_key} and compressed it automatically.`
          : `Updated ${definition.asset_key}`
      );
      await Promise.allSettled([loadAll(), refreshBrandAssets()]);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not prepare this upload.");
    } finally {
      setBusyKey("");
    }
  }

  async function removeAsset(definition: DefinitionRow) {
    setError("");
    setOk("");
    setBusyKey(definition.asset_key);
    try {
      const supabase = createSupabaseBrowserClient();
      const {
        data: { user }
      } = await supabase.auth.getUser();
      const userId = user?.id ?? null;

      const { error: updateError } = await supabase
        .from("brand_assets")
        .update({ asset_url: null, bucket: null, path: null, updated_by: userId, updated_at: new Date().toISOString() })
        .eq("asset_key", definition.asset_key);

      if (updateError) throw updateError;

      setOk(`Removed ${definition.asset_key}`);
      await Promise.allSettled([loadAll(), refreshBrandAssets()]);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Remove failed");
    } finally {
      setBusyKey("");
    }
  }

  async function toggleActive(definition: DefinitionRow, row: AssetRow | null) {
    if (!row) return;
    setError("");
    setOk("");
    setBusyKey(row.asset_key);
    try {
      const supabase = createSupabaseBrowserClient();
      const {
        data: { user }
      } = await supabase.auth.getUser();
      const userId = user?.id ?? null;

      const next = !row.is_active;
      const { error: updateError } = await supabase
        .from("brand_assets")
        .update({ is_active: next, updated_by: userId, updated_at: new Date().toISOString() })
        .eq("asset_key", row.asset_key);

      if (updateError) throw updateError;

      setOk(`${row.asset_key} is now ${next ? "active" : "inactive"}`);
      await Promise.allSettled([loadAll(), refreshBrandAssets()]);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Update failed");
    } finally {
      setBusyKey("");
    }
  }

  async function restorePrevious(definition: DefinitionRow) {
    setError("");
    setOk("");
    setBusyKey(definition.asset_key);
    try {
      const supabase = createSupabaseBrowserClient();
      const {
        data: { user }
      } = await supabase.auth.getUser();
      const userId = user?.id ?? null;

      const { data, error } = await supabase
        .from("asset_versions")
        .select("version_number, is_active, asset_url")
        .eq("asset_key", definition.asset_key)
        .order("version_number", { ascending: false })
        .limit(25);

      if (error) throw error;
      const prev = (data ?? []).find((r: { version_number: number; is_active: boolean; asset_url: string | null }) => !r.is_active && !!r.asset_url);
      if (!prev) throw new Error("No previous version found");

      const { error: rpcError } = await supabase.rpc("restore_brand_asset_version", {
        p_asset_key: definition.asset_key,
        p_version_number: prev.version_number,
        p_user_id: userId
      });
      if (rpcError) throw rpcError;

      setOk(`Restored previous version for ${definition.asset_key}`);
      await Promise.allSettled([loadAll(), refreshBrandAssets()]);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Restore failed");
    } finally {
      setBusyKey("");
    }
  }

  async function manualRefresh() {
    setError("");
    setOk("");
    await Promise.allSettled([loadAll(), refreshBrandAssets()]);
    setOk("Refreshed");
  }

  if (loading) {
    return <div className="text-sm text-muted-foreground">Loading brand assets…</div>;
  }

  return (
    <div className="flex flex-col gap-5">
      {error ? <LuxuryCard className="border border-rose-500/25 bg-rose-500/10 p-4 text-sm text-rose-200">{error}</LuxuryCard> : null}
      {ok ? <LuxuryCard className="border border-emerald-500/25 bg-emerald-500/10 p-4 text-sm text-emerald-200">{ok}</LuxuryCard> : null}

      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-col gap-1">
          <div className="text-sm font-semibold">Cache version</div>
          <div className="text-xs text-muted-foreground">{version ?? "—"}</div>
        </div>
        <Button type="button" variant="secondary" onClick={manualRefresh} disabled={brandAssetsLoading}>
          Refresh Apps
        </Button>
      </div>

      <div className="flex flex-col gap-6">
        {sections.map(({ section, items }) => (
          <div key={section} className="flex flex-col gap-3">
            <div className="flex items-center justify-between gap-3">
              <div className="text-base font-semibold">{section}</div>
              <div className="text-xs text-muted-foreground">{items.length} assets</div>
            </div>
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
              {items.map(({ definition, asset }) => {
                const key = definition.asset_key;
                const busy = busyKey === key;
                const currentUrl = normalizeUrl(asset?.asset_url);
                const active = asset?.is_active ?? true;

                return (
                  <LuxuryCard key={key} className="border border-white/10 bg-white/5 p-4">
                    <div className="flex items-start justify-between gap-3">
                      <div className="flex flex-col gap-1">
                        <div className="text-sm font-semibold">{definition.label}</div>
                        <div className="text-[11px] text-muted-foreground">{definition.asset_key}</div>
                      </div>
                      <button
                        type="button"
                        onClick={() => void toggleActive(definition, asset)}
                        disabled={busy || !asset}
                        className={cn(
                          "rounded-full border px-3 py-1 text-[11px] font-semibold",
                          active ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-200" : "border-white/10 bg-white/5 text-muted-foreground"
                        )}
                      >
                        {active ? "Active" : "Inactive"}
                      </button>
                    </div>

                    <div className="mt-3 overflow-hidden rounded-lg border border-white/10 bg-black/20">
                      <div className="relative aspect-[16/9] w-full">
                        <SafeImage
                          src={currentUrl}
                          fallbackKey={key}
                          alt={definition.label}
                          className="h-full w-full object-cover"
                          unoptimized
                        />
                      </div>
                    </div>

                    <div className="mt-3 flex flex-col gap-2">
                      <div className="text-[11px] text-muted-foreground">Last updated: {formatDate(asset?.updated_at)}</div>
                      <div className="flex flex-wrap items-center gap-2">
                        <Input
                          ref={(el) => {
                            const map = fileInputRefs.current;
                            if (el) map.set(key, el);
                            else map.delete(key);
                          }}
                          type="file"
                          accept="image/png,image/jpeg,image/webp"
                          className="sr-only"
                          onChange={(e) => {
                            const file = e.currentTarget.files?.[0] ?? null;
                            e.currentTarget.value = "";
                            if (!file) return;
                            if (!canUploadFile(file)) {
                              setError("Unsupported file. Use png/jpg/jpeg/webp.");
                              return;
                            }
                            const objectUrl = URL.createObjectURL(file);
                            const prev = objectUrlRefs.current.get(key);
                            if (prev) URL.revokeObjectURL(prev);
                            objectUrlRefs.current.set(key, objectUrl);
                            setEditorDefinition(definition);
                            setEditorFile(file);
                            setEditorOpen(true);
                          }}
                        />
                        <Button type="button" variant="secondary" disabled={busy} onClick={() => fileInputRefs.current.get(key)?.click()}>
                          Upload / Replace
                        </Button>
                        <Button asChild type="button" variant="ghost" disabled={busy || !currentUrl}>
                          <a href={currentUrl ?? "#"} target="_blank" rel="noopener noreferrer">
                            Preview
                          </a>
                        </Button>
                        <Button
                          type="button"
                          variant="ghost"
                          disabled={busy}
                          onClick={() => {
                            setDeleteDefinition(definition);
                            setDeleteActive(active);
                            setDeleteOpen(true);
                          }}
                        >
                          Delete
                        </Button>
                        <Button type="button" variant="ghost" disabled={busy} onClick={() => void restorePrevious(definition)}>
                          Restore Previous
                        </Button>
                        <Button
                          type="button"
                          variant="ghost"
                          disabled={busy}
                          onClick={() => {
                            setHistoryKey(key);
                            setHistoryLabel(definition.label);
                            setHistoryOpen(true);
                          }}
                        >
                          History
                        </Button>
                      </div>
                    </div>
                  </LuxuryCard>
                );
              })}
            </div>
          </div>
        ))}
      </div>

      <AssetEditor
        open={editorOpen}
        definition={editorDefinition}
        file={editorFile}
        onCancel={() => {
          setEditorOpen(false);
          setEditorDefinition(null);
          setEditorFile(null);
        }}
        onSave={async (result) => {
          if (!editorDefinition) return;
          setEditorOpen(false);
          setEditorFile(null);
          await uploadAsset(editorDefinition, result);
          setEditorDefinition(null);
        }}
      />

      <AssetHistory
        open={historyOpen}
        assetKey={historyKey}
        assetLabel={historyLabel}
        onClose={() => {
          setHistoryOpen(false);
          setHistoryKey(null);
          setHistoryLabel(null);
        }}
        onRestored={async () => {
          await Promise.allSettled([loadAll(), refreshBrandAssets()]);
        }}
      />

      <AssetSafeDelete
        open={deleteOpen}
        assetKey={deleteDefinition?.asset_key ?? null}
        label={deleteDefinition?.label ?? null}
        isActive={deleteActive}
        onClose={() => {
          setDeleteOpen(false);
          setDeleteDefinition(null);
          setDeleteActive(false);
        }}
        onConfirm={async () => {
          if (!deleteDefinition) return;
          await removeAsset(deleteDefinition);
          setDeleteOpen(false);
          setDeleteDefinition(null);
          setDeleteActive(false);
        }}
      />
    </div>
  );
}

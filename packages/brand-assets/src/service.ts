import { createSupabaseBrowserClient } from "@hallaq/supabase/browser";

import { EMERGENCY_FALLBACK_IMAGE, getLocalizedAssetKey, resolveBrandAssetKey, type BrandAssetsMap, type BrandAssetRow } from "./keys";

type CachePayload = {
  version: string | null;
  assets: BrandAssetsMap;
};

const CACHE_KEY = "hallaq_brand_assets_cache_v1";

function safeJsonParse(value: string | null): CachePayload | null {
  if (!value) return null;
  try {
    const parsed = JSON.parse(value) as unknown;
    if (!parsed || typeof parsed !== "object") return null;
    const v = (parsed as { version?: unknown }).version;
    const a = (parsed as { assets?: unknown }).assets;
    if (v !== null && typeof v !== "string") return null;
    if (!a || typeof a !== "object") return null;
    const assets = a as Record<string, unknown>;
    const out: BrandAssetsMap = {};
    for (const [k, val] of Object.entries(assets)) {
      if (typeof val === "string" && val.trim()) out[k] = val.trim();
    }
    return { version: v ?? null, assets: out };
  } catch {
    return null;
  }
}

export type BrandAssetsSnapshot = {
  version: string | null;
  assets: BrandAssetsMap;
};

type Listener = (snapshot: BrandAssetsSnapshot) => void;

export class BrandAssetsService {
  private initialized = false;
  private loading = false;
  private version: string | null = null;
  private assets: BrandAssetsMap = {};
  private listeners = new Set<Listener>();
  private realtimeUnsub: (() => void) | null = null;

  getSnapshot(): BrandAssetsSnapshot {
    return { version: this.version, assets: this.assets };
  }

  isLoading() {
    return this.loading;
  }

  getUrl(key: string, emergencyFallback: string = EMERGENCY_FALLBACK_IMAGE) {
    const url = this.assets[resolveBrandAssetKey(key)];
    return url || emergencyFallback;
  }

  getOptionalUrl(key: string) {
    return this.assets[resolveBrandAssetKey(key)] ?? null;
  }

  getUrlLocalized(baseKey: string, locale: string, emergencyFallback: string = EMERGENCY_FALLBACK_IMAGE) {
    const localized = getLocalizedAssetKey(baseKey, locale);
    const localizedUrl = this.assets[localized];
    if (localizedUrl) return localizedUrl;
    return this.getUrl(baseKey, emergencyFallback);
  }

  getOptionalUrlLocalized(baseKey: string, locale: string) {
    const localized = getLocalizedAssetKey(baseKey, locale);
    return this.assets[localized] ?? this.getOptionalUrl(baseKey);
  }

  subscribe(listener: Listener) {
    this.listeners.add(listener);
    listener(this.getSnapshot());
    return () => {
      this.listeners.delete(listener);
    };
  }

  private emit() {
    const snap = this.getSnapshot();
    for (const l of this.listeners) l(snap);
  }

  async init() {
    if (this.initialized) return;
    this.initialized = true;
    await this.refresh({ allowCache: true, ensureRealtime: true });
  }

  async refresh({
    allowCache,
    ensureRealtime
  }: {
    allowCache: boolean;
    ensureRealtime: boolean;
  }) {
    if (this.loading) return;
    this.loading = true;
    this.emit();

    try {
      const supabase = createSupabaseBrowserClient();

      const cached = allowCache ? safeJsonParse(globalThis.localStorage?.getItem(CACHE_KEY) ?? null) : null;

      const { data: latestRow } = await supabase
        .from("brand_assets")
        .select("updated_at")
        .eq("is_active", true)
        .order("updated_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      const latestVersion = (latestRow?.updated_at ?? null) as string | null;

      if (cached && cached.version && latestVersion && cached.version === latestVersion && Object.keys(cached.assets).length) {
        this.version = cached.version;
        this.assets = cached.assets;
      } else {
        const { data } = await supabase
          .from("brand_assets")
          .select("asset_key, asset_url, is_active, updated_at")
          .eq("is_active", true);

        const map: BrandAssetsMap = {};
        for (const row of (data ?? []) as Array<Pick<BrandAssetRow, "asset_key" | "asset_url" | "is_active">>) {
          const key = String(row.asset_key ?? "").trim();
          const url = typeof row.asset_url === "string" ? row.asset_url.trim() : "";
          if (key && url) map[key] = url;
        }

        this.version = latestVersion;
        this.assets = map;
        globalThis.localStorage?.setItem(CACHE_KEY, JSON.stringify({ version: this.version, assets: this.assets } satisfies CachePayload));
      }

      if (ensureRealtime && !this.realtimeUnsub) {
        const channel = supabase
          .channel("brand-assets-live")
          .on(
            "postgres_changes",
            { event: "*", schema: "public", table: "brand_assets" },
            async () => await this.refresh({ allowCache: false, ensureRealtime: true })
          )
          .subscribe();

        this.realtimeUnsub = () => {
          supabase.removeChannel(channel);
        };
      }
    } finally {
      this.loading = false;
      this.emit();
    }
  }

  destroy() {
    this.realtimeUnsub?.();
    this.realtimeUnsub = null;
    this.listeners.clear();
    this.initialized = false;
    this.loading = false;
  }
}

export const brandAssetsService = new BrandAssetsService();

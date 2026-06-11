"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode
} from "react";

import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

export type FeatureFlagRow = {
  key: string;
  description: string | null;
  enabled: boolean;
  updated_at: string;
};

type CachedFeatureFlags = {
  cachedAt: number;
  rows: FeatureFlagRow[];
};

type FeatureFlagsContextValue = {
  loaded: boolean;
  rows: FeatureFlagRow[];
  byKey: Record<string, FeatureFlagRow>;
  isEnabled: (flagKey: string, defaultValue?: boolean) => boolean;
  refresh: () => Promise<void>;
};

const FeatureFlagsContext = createContext<FeatureFlagsContextValue | null>(null);

function safeParseCached(value: string | null): CachedFeatureFlags | null {
  if (!value) return null;
  try {
    const parsed = JSON.parse(value) as Partial<CachedFeatureFlags>;
    if (!parsed || typeof parsed !== "object") return null;
    if (typeof parsed.cachedAt !== "number" || !Array.isArray(parsed.rows)) return null;
    return { cachedAt: parsed.cachedAt, rows: parsed.rows as FeatureFlagRow[] };
  } catch {
    return null;
  }
}

function buildByKey(rows: FeatureFlagRow[]) {
  const byKey: Record<string, FeatureFlagRow> = {};
  rows.forEach((r) => {
    if (r?.key) byKey[r.key] = r;
  });
  return byKey;
}

export function FeatureFlagsProvider({
  children,
  createClient,
  storageKey = "hallaq_feature_flags_v1",
  refreshMs = 5 * 60 * 1000
}: {
  children: ReactNode;
  createClient: () => SupabaseClient;
  storageKey?: string;
  refreshMs?: number;
}) {
  const supabaseRef = useRef<SupabaseClient | null>(null);
  const channelRef = useRef<RealtimeChannel | null>(null);
  const refreshTimerRef = useRef<number | null>(null);
  const inFlightRef = useRef<Promise<void> | null>(null);

  const cached = useMemo(() => {
    if (typeof window === "undefined") return null;
    return safeParseCached(window.localStorage.getItem(storageKey));
  }, [storageKey]);

  const [rows, setRows] = useState<FeatureFlagRow[]>(() => cached?.rows ?? []);
  const [loaded, setLoaded] = useState(() => Boolean(cached?.rows?.length));

  const byKey = useMemo(() => buildByKey(rows), [rows]);

  const refresh = useCallback(async () => {
    if (inFlightRef.current) return inFlightRef.current;
    const p = (async () => {
      try {
        if (!supabaseRef.current) supabaseRef.current = createClient();
        const supabase = supabaseRef.current;
        const { data, error } = await supabase
          .from("feature_flags")
          .select("key, description, enabled, updated_at")
          .order("key", { ascending: true });

        if (error) throw error;

        const nextRows = (data ?? []) as FeatureFlagRow[];
        setRows(nextRows);
        setLoaded(true);
        if (typeof window !== "undefined") {
          const payload: CachedFeatureFlags = { cachedAt: Date.now(), rows: nextRows };
          window.localStorage.setItem(storageKey, JSON.stringify(payload));
        }
      } finally {
        inFlightRef.current = null;
      }
    })();

    inFlightRef.current = p;
    return p;
  }, [createClient, storageKey]);

  useEffect(() => {
    let alive = true;
    if (!supabaseRef.current) supabaseRef.current = createClient();
    const supabase = supabaseRef.current;

    (async () => {
      try {
        await refresh();
      } catch {
        if (alive) setLoaded(true);
      }
    })();

    channelRef.current = supabase
      .channel("feature-flags")
      .on("postgres_changes", { event: "*", schema: "public", table: "feature_flags" }, () => {
        void refresh();
      })
      .subscribe();

    refreshTimerRef.current = window.setInterval(() => {
      void refresh();
    }, refreshMs);

    return () => {
      alive = false;
      if (refreshTimerRef.current) window.clearInterval(refreshTimerRef.current);
      refreshTimerRef.current = null;
      if (channelRef.current) supabase.removeChannel(channelRef.current);
      channelRef.current = null;
    };
  }, [createClient, refresh, refreshMs]);

  const isEnabled = useCallback(
    (flagKey: string, defaultValue = false) => byKey[flagKey]?.enabled ?? defaultValue,
    [byKey]
  );

  const value = useMemo<FeatureFlagsContextValue>(
    () => ({
      loaded,
      rows,
      byKey,
      isEnabled,
      refresh
    }),
    [byKey, isEnabled, loaded, refresh, rows]
  );

  return <FeatureFlagsContext.Provider value={value}>{children}</FeatureFlagsContext.Provider>;
}

export function useFeatureFlags() {
  const ctx = useContext(FeatureFlagsContext);
  if (!ctx) throw new Error("useFeatureFlags must be used within FeatureFlagsProvider");
  return ctx;
}

export function useFeatureFlagEnabled(flagKey: string, defaultValue = false) {
  const { isEnabled } = useFeatureFlags();
  return isEnabled(flagKey, defaultValue);
}

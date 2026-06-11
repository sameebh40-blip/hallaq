"use client";

import type { CSSProperties, ReactEventHandler } from "react";
import { createContext, useContext, useEffect, useMemo, useState } from "react";
import Image from "next/image";

import { EMERGENCY_FALLBACK_IMAGE, type BrandAssetsMap } from "./keys";
import { brandAssetsService } from "./service";

type BrandAssetsContextValue = {
  assets: BrandAssetsMap;
  version: string | null;
  loading: boolean;
  refresh: () => Promise<void>;
  getUrl: (key: string, emergencyFallback?: string) => string;
  getOptionalUrl: (key: string) => string | null;
  getUrlLocalized: (baseKey: string, locale: string, emergencyFallback?: string) => string;
  getOptionalUrlLocalized: (baseKey: string, locale: string) => string | null;
};

const BrandAssetsContext = createContext<BrandAssetsContextValue | null>(null);

export function BrandAssetsProvider({ children }: { children: React.ReactNode }) {
  const [snapshot, setSnapshot] = useState(() => brandAssetsService.getSnapshot());
  const [loading, setLoading] = useState(() => brandAssetsService.isLoading());

  useEffect(() => {
    void brandAssetsService.init();
    return brandAssetsService.subscribe((s) => {
      setSnapshot(s);
      setLoading(brandAssetsService.isLoading());
    });
  }, []);

  const value = useMemo<BrandAssetsContextValue>(() => {
    return {
      assets: snapshot.assets,
      version: snapshot.version,
      loading,
      refresh: async () => await brandAssetsService.refresh({ allowCache: false, ensureRealtime: true }),
      getUrl: (key: string, emergencyFallback: string = EMERGENCY_FALLBACK_IMAGE) => brandAssetsService.getUrl(key, emergencyFallback),
      getOptionalUrl: (key: string) => brandAssetsService.getOptionalUrl(key),
      getUrlLocalized: (baseKey: string, locale: string, emergencyFallback: string = EMERGENCY_FALLBACK_IMAGE) =>
        brandAssetsService.getUrlLocalized(baseKey, locale, emergencyFallback),
      getOptionalUrlLocalized: (baseKey: string, locale: string) => brandAssetsService.getOptionalUrlLocalized(baseKey, locale)
    };
  }, [snapshot, loading]);

  return <BrandAssetsContext.Provider value={value}>{children}</BrandAssetsContext.Provider>;
}

export function useBrandAssets() {
  const ctx = useContext(BrandAssetsContext);
  return (
    ctx ?? {
      assets: {},
      version: null,
      loading: false,
      refresh: async () => {},
      getUrl: (_key: string, emergencyFallback: string = EMERGENCY_FALLBACK_IMAGE) => emergencyFallback,
      getOptionalUrl: (_key: string) => null,
      getUrlLocalized: (_baseKey: string, _locale: string, emergencyFallback: string = EMERGENCY_FALLBACK_IMAGE) => emergencyFallback,
      getOptionalUrlLocalized: (_baseKey: string, _locale: string) => null
    }
  );
}

export function useBrandAssetUrl(key: string, emergencyFallback: string = EMERGENCY_FALLBACK_IMAGE) {
  const { getUrl } = useBrandAssets();
  return getUrl(key, emergencyFallback);
}

export function useBrandAssetUrlLocalized(baseKey: string, locale: string, emergencyFallback: string = EMERGENCY_FALLBACK_IMAGE) {
  const { getUrlLocalized } = useBrandAssets();
  return getUrlLocalized(baseKey, locale, emergencyFallback);
}

type SafeImageProps = Omit<React.ImgHTMLAttributes<HTMLImageElement>, "src" | "onError"> & {
  src?: string | null;
  fallbackSrc?: string;
  fallbackKey?: string;
  emergencyFallbackSrc?: string;
  unoptimized?: boolean;
  onError?: ReactEventHandler<HTMLImageElement>;
};

type SafeImageLocalizedProps = Omit<SafeImageProps, "fallbackSrc" | "fallbackKey"> & {
  fallbackBaseKey: string;
  locale: string;
};

function toNumber(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value !== "string") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function inferObjectFit(className: string) {
  const v = className ?? "";
  if (v.includes("object-contain")) return "contain";
  if (v.includes("object-fill")) return "fill";
  if (v.includes("object-scale-down")) return "scale-down";
  if (v.includes("object-none")) return "none";
  if (v.includes("object-cover")) return "cover";
  return null;
}

function safeUrl(value: unknown) {
  const u = typeof value === "string" ? value.trim() : "";
  return u || null;
}

function isBlobOrDataUrl(url: string) {
  return url.startsWith("blob:") || url.startsWith("data:");
}

function isSvgUrl(url: string) {
  const u = url.toLowerCase();
  if (u.includes("image/svg+xml")) return true;
  try {
    const parsed = new URL(url);
    return parsed.pathname.toLowerCase().endsWith(".svg");
  } catch {
    return u.endsWith(".svg");
  }
}

export function SafeImage({
  src,
  fallbackSrc,
  fallbackKey,
  emergencyFallbackSrc = EMERGENCY_FALLBACK_IMAGE,
  unoptimized = false,
  onError,
  className,
  style,
  width,
  height,
  ...props
}: SafeImageProps) {
  const { getUrl } = useBrandAssets();
  const fallback = useMemo(() => {
    return safeUrl(fallbackSrc) ?? (fallbackKey ? getUrl(fallbackKey, emergencyFallbackSrc) : emergencyFallbackSrc);
  }, [fallbackSrc, fallbackKey, getUrl, emergencyFallbackSrc]);

  const requested = safeUrl(src);
  const [current, setCurrent] = useState<string>(fallback);

  useEffect(() => {
    setCurrent(fallback);
    if (!requested || requested === fallback) return;

    let cancelled = false;
    let timeout: number | null = null;
    let attempt = 0;
    const maxAttempts = 3;

    const tryLoad = () => {
      if (cancelled) return;
      attempt += 1;
      const pre = new window.Image();
      pre.decoding = "async";
      const cacheBusted =
        attempt <= 1 ? requested : `${requested}${requested.includes("?") ? "&" : "?"}__retry=${attempt}&__ts=${Date.now()}`;
      pre.src = cacheBusted;
      pre.onload = () => {
        if (cancelled) return;
        setCurrent(requested);
      };
      pre.onerror = () => {
        if (cancelled) return;
        if (attempt < maxAttempts) {
          timeout = window.setTimeout(tryLoad, 250 * attempt);
          return;
        }
        setCurrent(fallback);
      };
    };

    tryLoad();
    return () => {
      cancelled = true;
      if (timeout) window.clearTimeout(timeout);
    };
  }, [requested, fallback, onError]);

  const w = toNumber(width);
  const h = toNumber(height);
  const objectFit = inferObjectFit(className ?? "");
  const wrapperClassName = className ? `relative block overflow-hidden ${className}` : "relative block overflow-hidden";
  const useImg = unoptimized || isBlobOrDataUrl(current) || isSvgUrl(current);

  return (
    <span className={wrapperClassName} style={style as CSSProperties | undefined}>
      {useImg ? (
        <img
          {...(props as Omit<React.ImgHTMLAttributes<HTMLImageElement>, "src" | "onError">)}
          alt={props.alt ?? ""}
          src={current}
          width={w ?? undefined}
          height={h ?? undefined}
          style={{ ...(style as CSSProperties | undefined), ...(objectFit ? { objectFit } : null) }}
          onError={(e) => {
            setCurrent(fallback);
            onError?.(e);
          }}
          className="h-full w-full"
        />
      ) : (
        <Image
          {...(props as Omit<React.ComponentProps<typeof Image>, "src" | "alt" | "width" | "height" | "fill" | "onError">)}
          alt={props.alt ?? ""}
          src={current}
          width={w ?? undefined}
          height={h ?? undefined}
          fill={!w || !h}
          sizes={props.sizes ?? "100vw"}
          style={objectFit ? { objectFit } : undefined}
          onError={(e) => {
            setCurrent(fallback);
            onError?.(e);
          }}
        />
      )}
    </span>
  );
}

export function SafeImageLocalized({ fallbackBaseKey, locale, emergencyFallbackSrc = EMERGENCY_FALLBACK_IMAGE, ...props }: SafeImageLocalizedProps) {
  const { getUrlLocalized } = useBrandAssets();
  const fallbackSrc = getUrlLocalized(fallbackBaseKey, locale, emergencyFallbackSrc);
  return <SafeImage {...props} fallbackSrc={fallbackSrc} emergencyFallbackSrc={emergencyFallbackSrc} />;
}

import { cache } from "react";

import type { createSupabaseServerClient } from "./server";

export type StorageBucket =
  | "avatars"
  | "profile-covers"
  | "barber-images"
  | "shop-images"
  | "portfolio"
  | "reels"
  | "reels-media"
  | "post-media"
  | "review-images"
  | "review-photos"
  | "service-images"
  | "products"
  | "product-images"
  | "offer-images"
  | "before-after"
  | "claim-proofs"
  | "haircut-history"
  | "ai-style"
  | "awards"
  | "style-library"
  | "backups";

export type StorageObjectRef<B extends StorageBucket = StorageBucket> =
  | { bucket: B; path: string }
  | string
  | null
  | undefined;

const PUBLIC_BUCKETS: ReadonlySet<StorageBucket> = new Set<StorageBucket>([
  "avatars",
  "profile-covers",
  "barber-images",
  "shop-images",
  "portfolio",
  "reels",
  "reels-media",
  "post-media",
  "review-images",
  "review-photos",
  "service-images",
  "products",
  "product-images",
  "offer-images",
  "before-after",
  "haircut-history",
  "ai-style",
  "awards",
  "style-library"
]);

function isHttpUrl(v: string) {
  return v.startsWith("http://") || v.startsWith("https://");
}

export function parsePublicStorageUrl(url: string): { bucket: string; path: string } | null {
  const u = (url ?? "").trim();
  if (!u) return null;
  try {
    const parsed = new URL(u);
    const marker = "/storage/v1/object/public/";
    const idx = parsed.pathname.indexOf(marker);
    if (idx < 0) return null;
    const rest = parsed.pathname.slice(idx + marker.length);
    const [bucket, ...parts] = rest.split("/").filter(Boolean);
    const path = parts.join("/");
    if (!bucket || !path) return null;
    return { bucket, path };
  } catch {
    return null;
  }
}

const signedUrlCache = new Map<string, { url: string; exp: number }>();

function getCached(key: string) {
  const hit = signedUrlCache.get(key);
  if (!hit) return null;
  if (Date.now() > hit.exp) {
    signedUrlCache.delete(key);
    return null;
  }
  return hit.url;
}

function setCached(key: string, url: string, ttlMs: number) {
  signedUrlCache.set(key, { url, exp: Date.now() + ttlMs });
}

const signedOrUrlCachedPerRequest = cache(
  async function signedOrUrlImpl(
    supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>,
    bucket: StorageBucket,
    path: string,
    expiresInSeconds: number
  ) {
    const p = (path ?? "").trim();
    if (!p) return null;

    const cacheKey = `${bucket}:${expiresInSeconds}:${p}`;
    const cached = getCached(cacheKey);
    if (cached) return cached;

    const { data, error } = await supabase.storage.from(bucket).createSignedUrl(p, expiresInSeconds);
    if (!error && data?.signedUrl) {
      setCached(cacheKey, data.signedUrl, Math.max(5_000, (expiresInSeconds - 30) * 1000));
      return data.signedUrl;
    }

    if (PUBLIC_BUCKETS.has(bucket)) {
      const { data: pub } = supabase.storage.from(bucket).getPublicUrl(p);
      const publicUrl = pub?.publicUrl ?? null;
      if (publicUrl) setCached(cacheKey, publicUrl, 24 * 60 * 60 * 1000);
      return publicUrl;
    }

    return null;
  }
);

export async function signedOrUrl<B extends StorageBucket>(
  supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>,
  bucket: B,
  ref: StorageObjectRef<B>,
  opts?: { expiresInSeconds?: number }
): Promise<string | null> {
  const expiresInSeconds = opts?.expiresInSeconds ?? 60 * 60;

  if (ref == null) return null;

  if (typeof ref === "object") {
    const p = (ref.path ?? "").trim();
    if (!p) return null;
    return signedOrUrlCachedPerRequest(supabase, ref.bucket, p, expiresInSeconds);
  }

  const raw = String(ref ?? "").trim();
  if (!raw) return null;
  if (isHttpUrl(raw)) return raw;

  return signedOrUrlCachedPerRequest(supabase, bucket, raw, expiresInSeconds);
}

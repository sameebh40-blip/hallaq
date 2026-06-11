import { signedOrUrl, type StorageBucket } from "@hallaq/supabase/storage";
import { createAppSupabaseServerClient } from "@/lib/supabase";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { DiscoverFeed, type DiscoverItem } from "@/app/discover/discover-feed";

export const dynamic = "force-dynamic";

const DISCOVER_MEDIA_BUCKETS: ReadonlySet<StorageBucket> = new Set<StorageBucket>(["post-media", "reels-media", "reels"]);

function asBucket(value: string | null): StorageBucket | null {
  const v = String(value ?? "").trim();
  if (!v) return null;
  return (DISCOVER_MEDIA_BUCKETS.has(v as StorageBucket) ? (v as StorageBucket) : null) ?? null;
}

export default async function DiscoverPage() {
  const supabase = await createAppSupabaseServerClient();

  const select =
    "id, caption, media_url, media_path, thumbnail_url, thumbnail_path, media_type, media_bucket, thumbnail_bucket, shop_id, barber_id, likes_count, comments_count, saves_count, status, barbers(id, display_name, avatar_url, avatar_path, shop_id, status, is_active, deleted_at, barbershops(id, name, logo_url, logo_path, status, is_active, deleted_at)), barbershops(id, name, logo_url, logo_path, status, is_active, deleted_at)";

  const errorText = (e: unknown) => String((e as { message?: unknown } | null)?.message ?? "").toLowerCase();
  const maybeMissing = (e: unknown, column: string) => errorText(e).includes(`column`) && errorText(e).includes(column.toLowerCase());

  const fetchPostsStrict = () =>
    supabase
      .from("posts")
      .select(select)
      .eq("status", "approved")
      .eq("is_active", true)
      .or("media_url.not.is.null,media_path.not.is.null")
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(30);

  const fetchPostsLoose = () =>
    supabase
      .from("posts")
      .select(select)
      .eq("status", "approved")
      .or("media_url.not.is.null,media_path.not.is.null")
      .order("created_at", { ascending: false })
      .limit(30);

  const fetchReelsFallback = () =>
    supabase
      .from("reels")
      .select(select)
      .eq("status", "approved")
      .or("media_url.not.is.null,media_path.not.is.null")
      .order("created_at", { ascending: false })
      .limit(30);

  let reels: Array<Record<string, unknown>> | null = null;
  let error: unknown = null;

  {
    const r1 = await fetchPostsStrict();
    reels = (r1.data ?? null) as Array<Record<string, unknown>> | null;
    error = r1.error ?? null;
  }

  if (error && (maybeMissing(error, "is_active") || maybeMissing(error, "deleted_at") || maybeMissing(error, "media_bucket"))) {
    const r2 = await fetchPostsLoose();
    reels = (r2.data ?? null) as Array<Record<string, unknown>> | null;
    error = r2.error ?? null;
  }

  if (error) {
    const r3 = await fetchReelsFallback();
    reels = (r3.data ?? null) as Array<Record<string, unknown>> | null;
    error = r3.error ?? null;
  }

  const base = (reels ?? []) as Array<Record<string, unknown>>;
  const shopsLookup = new Map<string, Record<string, unknown>>();
  const shopCandidateIds = Array.from(
    new Set(
      base
        .map((row) => {
          const joined = row.barbershops ? (row.barbershops as Record<string, unknown>) : null;
          const id = String(joined?.id ?? row.shop_id ?? "").trim();
          return id || null;
        })
        .filter((value): value is string => Boolean(value))
    )
  );

  if (shopCandidateIds.length) {
    const fetchShopsStrict = () =>
      supabase
        .from("barbershops")
        .select("id, name, logo_url, logo_path, status, is_active, deleted_at")
        .in("id", shopCandidateIds)
        .eq("status", "approved")
        .eq("is_active", true)
        .is("deleted_at", null);

    const fetchShopsLoose = () =>
      supabase
        .from("barbershops")
        .select("id, name, logo_url, logo_path, status")
        .in("id", shopCandidateIds)
        .eq("status", "approved");

    let shopsVisible: Array<Record<string, unknown>> | null = null;
    {
      const r1 = await fetchShopsStrict();
      shopsVisible = (r1.data ?? null) as Array<Record<string, unknown>> | null;
      if (r1.error && (maybeMissing(r1.error, "is_active") || maybeMissing(r1.error, "deleted_at"))) {
        const r2 = await fetchShopsLoose();
        shopsVisible = (r2.data ?? null) as Array<Record<string, unknown>> | null;
      }
    }
    for (const s of (shopsVisible ?? []) as Array<Record<string, unknown>>) {
      if (s.id) shopsLookup.set(String(s.id), s);
    }
  }

  const items = (
    await Promise.all(
    base.map(async (r) => {
      const mediaPath = String(r.media_path ?? r.media_url ?? "").trim() || null;
      const thumbPath = String(r.thumbnail_path ?? r.thumbnail_url ?? "").trim() || null;
      const mediaBucket = String(r.media_bucket ?? "").trim() || null;
      const thumbBucket = String(r.thumbnail_bucket ?? "").trim() || null;

      const signFromBuckets = async (buckets: StorageBucket[], path: string | null) => {
        if (!path) return null;
        for (const b of buckets) {
          const u = await signedOrUrl(supabase, b, path);
          if (u) return u;
        }
        return null;
      };

      const signedMediaBuckets: StorageBucket[] = [];
      const mediaBucketTyped = asBucket(mediaBucket);
      if (mediaBucketTyped) signedMediaBuckets.push(mediaBucketTyped);
      signedMediaBuckets.push("post-media", "reels-media", "reels");

      const signedThumbBuckets: StorageBucket[] = [];
      const thumbBucketTyped = asBucket(thumbBucket);
      if (thumbBucketTyped) signedThumbBuckets.push(thumbBucketTyped);
      signedThumbBuckets.push("post-media", "reels-media", "reels");

      const signedMedia = await signFromBuckets(signedMediaBuckets, mediaPath);
      const signedThumb = thumbPath
        ? await signFromBuckets(signedThumbBuckets, thumbPath)
        : null;

      const barber = r.barbers ? (r.barbers as Record<string, unknown>) : null;
      const shopJoined = r.barbershops ? (r.barbershops as Record<string, unknown>) : null;
      const shopIdCandidate = String(shopJoined?.id ?? r.shop_id ?? "").trim();
      const shopResolved = shopIdCandidate ? shopsLookup.get(shopIdCandidate) ?? null : null;
      const barberPublic =
        Boolean(barber?.id) && barber?.status === "approved" && barber?.is_active === true && barber?.deleted_at == null;
      const shopPublic = Boolean(shopResolved?.id);
      const authorType: "barber" | "shop" | null = barberPublic ? "barber" : shopPublic ? "shop" : null;
      const authorId = authorType === "barber" ? String(barber?.id ?? "") : authorType === "shop" ? String(shopResolved?.id ?? "") : "";
      const authorName =
        authorType === "barber"
          ? String(barber?.display_name ?? "Barber")
          : String(shopResolved?.name ?? "Shop");
      const shopName =
        authorType === "barber"
          ? String((barber?.barbershops as Record<string, unknown> | null)?.name ?? "").trim() || null
          : null;

      const authorAvatarPath =
        authorType === "barber"
          ? (String(barber?.avatar_path ?? barber?.avatar_url ?? "").trim() || null)
          : (String(shopResolved?.logo_path ?? shopResolved?.logo_url ?? "").trim() || null);
      const authorAvatar =
        authorType === "barber"
          ? (await signedOrUrl(supabase, "barber-images", authorAvatarPath)) ?? ""
          : (await signedOrUrl(supabase, "shop-images", authorAvatarPath)) ?? "";

      const isVideo = r.media_type === "video";
      const mediaType: "image" | "video" = isVideo && !!signedMedia ? "video" : "image";
      const mediaUrl = mediaType === "video" ? signedMedia! : (signedThumb ?? signedMedia ?? "");

      if (!authorType || !authorId) {
        return null;
      }

      return {
        id: String(r.id),
        caption: (r.caption ?? null) as string | null,
        mediaType,
        mediaUrl,
        posterUrl: signedThumb,
        authorType,
        authorId,
        authorName,
        shopName,
        authorAvatarUrl: authorAvatar,
        likesCount: Number(r.likes_count ?? 0),
        commentsCount: Number(r.comments_count ?? 0),
        savesCount: Number(r.saves_count ?? 0)
      };
    })
  )).filter((item): item is DiscoverItem => Boolean(item));

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col px-4 py-4 pb-24">
      <div className="pb-3 text-lg font-semibold text-foreground">Discover</div>
      {error ? (
        <div className="mb-3 rounded-2xl border bg-card p-4 text-sm text-muted-foreground">
          Could not load reels right now.
        </div>
      ) : null}
      {items.length ? (
        <DiscoverFeed items={items} />
      ) : (
        <div className="rounded-2xl border bg-card p-6 text-sm text-muted-foreground">No reels yet.</div>
      )}
      <CustomerBottomNav />
    </main>
  );
}

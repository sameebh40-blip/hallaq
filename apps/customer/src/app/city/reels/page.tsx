import { signedOrUrl } from "@hallaq/supabase/storage";
import { getT } from "@hallaq/ui/translations-server";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { RealtimeRefresh } from "@/components/realtime-refresh";
import { createAppSupabaseServerClient } from "@/lib/supabase";

import { DiscoverFeed, type DiscoverItem } from "@/app/discover/discover-feed";

export const dynamic = "force-dynamic";

export default async function CityReelsPage() {
  const t = await getT();
  const supabase = await createAppSupabaseServerClient();

  const { data: reels, error } = await supabase
    .from("posts")
    .select(
      "id, caption, media_url, media_path, thumbnail_url, thumbnail_path, media_type, shop_id, barber_id, likes_count, comments_count, saves_count, status, barbers(id, display_name, avatar_url, avatar_path, shop_id, barbershops(name, logo_url, logo_path)), barbershops(id, name, logo_url, logo_path)"
    )
    .eq("status", "approved")
    .eq("is_active", true)
    .or("media_url.not.is.null,media_path.not.is.null")
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(40);

  const base = (reels ?? []) as Array<Record<string, unknown>>;
  const items: DiscoverItem[] = await Promise.all(
    base.map(async (r) => {
      const mediaPath = String(r.media_path ?? r.media_url ?? "").trim() || null;
      const thumbPath = String(r.thumbnail_path ?? r.thumbnail_url ?? "").trim() || null;

      const signedMedia =
        (await signedOrUrl(supabase, "reels", mediaPath)) ?? (await signedOrUrl(supabase, "reels-media", mediaPath));
      const signedThumb = thumbPath
        ? (await signedOrUrl(supabase, "reels", thumbPath)) ?? (await signedOrUrl(supabase, "reels-media", thumbPath))
        : null;

      const barber = r.barbers ? (r.barbers as Record<string, unknown>) : null;
      const shop = r.barbershops ? (r.barbershops as Record<string, unknown>) : null;
      const authorType: "barber" | "shop" = barber?.id ? "barber" : "shop";
      const authorId = authorType === "barber" ? String(barber?.id ?? "") : String(shop?.id ?? r.shop_id ?? "");
      const authorName = authorType === "barber" ? String(barber?.display_name ?? "Barber") : String(shop?.name ?? "Shop");
      const shopName =
        authorType === "barber" ? String((barber?.barbershops as Record<string, unknown> | null)?.name ?? "").trim() || null : null;

      const authorAvatarPath =
        authorType === "barber"
          ? (String(barber?.avatar_path ?? barber?.avatar_url ?? "").trim() || null)
          : (String(shop?.logo_path ?? shop?.logo_url ?? "").trim() || null);
      const authorAvatar =
        authorType === "barber"
          ? (await signedOrUrl(supabase, "barber-images", authorAvatarPath)) ?? ""
          : (await signedOrUrl(supabase, "shop-images", authorAvatarPath)) ?? "";

      const isVideo = r.media_type === "video";
      const mediaType: "image" | "video" = isVideo && !!signedMedia ? "video" : "image";
      const mediaUrl = mediaType === "video" ? signedMedia! : (signedMedia ?? signedThumb ?? "");

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
  );

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col px-4 py-4 pb-24">
      <RealtimeRefresh tables={["posts"]} />
      <div className="pb-3">
        <div className="text-[13px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">{t("customer.city.title")}</div>
        <div className="mt-1 text-sm font-semibold text-foreground">Best Reels</div>
      </div>
      {error ? (
        <div className="mb-3 rounded-[26px] border bg-card p-4 text-sm text-muted-foreground">
          Could not load reels right now.
        </div>
      ) : null}
      {items.length ? (
        <DiscoverFeed items={items} />
      ) : (
        <div className="rounded-[26px] border bg-card p-6 text-sm text-muted-foreground">No reels yet.</div>
      )}
      <CustomerBottomNav />
    </main>
  );
}

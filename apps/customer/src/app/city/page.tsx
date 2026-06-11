import { getServerLocale, getT } from "@hallaq/ui/translations-server";

import { signedOrUrl } from "@hallaq/supabase/storage";

import { createAppSupabaseServerClient } from "@/lib/supabase";

import { RealtimeRefresh } from "@/components/realtime-refresh";
import { CityHome, type CityHomeBarber, type CityHomeOffer, type CityHomeReel, type CityHomeShop } from "./city-home";

export const dynamic = "force-dynamic";

type Barber = CityHomeBarber & { avatar_path?: string | null };
type Shop = CityHomeShop & { cover_path?: string | null; logo_path?: string | null; created_at?: string | null };
type Reel = CityHomeReel & {
  thumbnail_path?: string | null;
  media_url?: string | null;
  media_path?: string | null;
  thumbnail_url?: string | null;
};

type OfferRow = {
  id: string;
  title?: string | null;
  discount_percent?: number | null;
  valid_to?: string | null;
  shop_id?: string | null;
  barbershops?: { id: string; name?: string | null; cover_url?: string | null; cover_path?: string | null } | null;
};

function trimUrl(url: unknown) {
  const u = typeof url === "string" ? url.trim() : "";
  return u || null;
}

export default async function CityHomePage() {
  const [t, locale] = await Promise.all([getT(), getServerLocale()]);
  const supabase = await createAppSupabaseServerClient();

  const [{ data: barbers, error: barbersError }, { data: shops, error: shopsError }, { data: reels, error: reelsError }, { data: offers, error: offersError }] =
    await Promise.all([
      supabase
        .from("barbers")
        .select("id, display_name, avatar_url, avatar_path, rating_avg, followers_count")
        .eq("status", "approved")
        .eq("is_active", true)
        .is("deleted_at", null)
        .order("rating_avg", { ascending: false })
        .limit(12),
      supabase
        .from("barbershops")
        .select("id, name, area, cover_url, cover_path, logo_url, logo_path, rating_avg, created_at")
        .eq("status", "approved")
        .is("deleted_at", null)
        .order("created_at", { ascending: false })
        .limit(10),
      supabase
        .from("reels")
        .select("id, caption, thumbnail_url, thumbnail_path, media_url, media_path, likes_count, comments_count, status")
        .eq("status", "approved")
        .order("created_at", { ascending: false })
        .limit(10),
      supabase
        .from("offers")
        .select("id, title, discount_percent, valid_to, shop_id, barbershops(id, name, cover_url, cover_path)")
        .eq("active", true)
        .eq("is_active", true)
        .eq("status", "approved")
        .order("created_at", { ascending: false })
        .limit(10)
    ]);

  const { data: banners, error: bannersError } = await supabase
    .from("city_banners")
    .select("id, title, subtitle, image_url, href, is_active, sort_order")
    .eq("is_active", true)
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: false })
    .limit(8);

  const { data: styles, error: stylesError } = await supabase
    .from("style_library")
    .select("id, name_en, name_ar, cover_url, cover_path, views_count")
    .eq("is_active", true)
    .eq("status", "approved")
    .order("views_count", { ascending: false })
    .order("created_at", { ascending: false })
    .limit(12);

  const topBarbersRaw = (barbersError ? [] : (barbers ?? [])) as Barber[];
  const topBarbers = await Promise.all(
    topBarbersRaw.slice(0, 6).map(async (b) => {
      const avatar = await signedOrUrl(supabase, "barber-images", b.avatar_path ?? b.avatar_url);
      return { ...b, avatar_url: trimUrl(avatar) };
    })
  );

  const newShopsRaw = (shopsError ? [] : (shops ?? [])) as Shop[];
  const newShops = await Promise.all(
    newShopsRaw.slice(0, 6).map(async (s) => {
      const cover = await signedOrUrl(supabase, "shop-images", s.cover_path ?? s.cover_url);
      const logo = await signedOrUrl(supabase, "shop-images", s.logo_path ?? s.logo_url);
      return { ...s, cover_url: trimUrl(cover), logo_url: trimUrl(logo) };
    })
  );

  const reelsRaw = (reelsError ? [] : (reels ?? [])) as Reel[];
  const bestReels = await Promise.all(
    reelsRaw.slice(0, 6).map(async (r) => {
      const ref = r.thumbnail_path ?? r.thumbnail_url ?? r.media_path ?? r.media_url;
      const poster = (await signedOrUrl(supabase, "reels", ref)) ?? (await signedOrUrl(supabase, "reels-media", ref));
      return { ...r, thumbnail_url: trimUrl(poster) };
    })
  );

  const offersRaw: OfferRow[] = offersError
      ? []
      : ((offers ?? []) as unknown[]).map((row) => {
          const r = row as Record<string, unknown>;
          const embedded = (r.barbershops ?? null) as unknown;
          const shop =
            embedded && Array.isArray(embedded)
              ? ((embedded[0] ?? null) as Record<string, unknown> | null)
              : (embedded as Record<string, unknown> | null);
          return {
            id: String(r.id),
            title: (r.title as string | null | undefined) ?? null,
            discount_percent: (r.discount_percent as number | null | undefined) ?? null,
            valid_to: (r.valid_to as string | null | undefined) ?? null,
            shop_id: (r.shop_id as string | null | undefined) ?? null,
            barbershops: shop
              ? {
                  id: String(shop.id),
                  name: (shop.name as string | null | undefined) ?? null,
                  cover_url: (shop.cover_url as string | null | undefined) ?? null,
                  cover_path: (shop.cover_path as string | null | undefined) ?? null
                }
              : null
          } satisfies OfferRow;
        });
  const cityOffers: CityHomeOffer[] = await Promise.all(
    offersRaw.slice(0, 3).map(async (o) => {
      const cover = await signedOrUrl(supabase, "shop-images", o.barbershops?.cover_path ?? o.barbershops?.cover_url);
      return {
        id: o.id,
        title: o.title ?? null,
        discount_percent: o.discount_percent ?? null,
        valid_to: o.valid_to ?? null,
        barbershops: o.barbershops
          ? { ...o.barbershops, cover_url: trimUrl(cover) }
          : o.barbershops
      };
    })
  );

  const cityStyles = await Promise.all(
    ((styles ?? []) as Array<Record<string, unknown>>).slice(0, 4).map(async (s) => {
      const cover = await signedOrUrl(supabase, "style-library", String(s.cover_path ?? s.cover_url ?? "").trim() || null);
      const name = String((locale === "ar" ? s.name_ar : s.name_en) ?? s.name_en ?? s.name_ar ?? "Style");
      return { id: String(s.id), name, coverUrl: trimUrl(cover), views: Number(s.views_count ?? 0) };
    })
  );

  const heroItems = ((banners ?? []) as Array<Record<string, unknown>>)
    .map((b) => {
      const id = String(b.id ?? "");
      const title = String(b.title ?? "").trim();
      const subtitle = String(b.subtitle ?? "").trim();
      const imageUrl = String(b.image_url ?? "").trim();
      const href = String(b.href ?? "/city").trim() || "/city";
      if (!id || !imageUrl) return null;
      return { id, title: title || "Hallaq City", subtitle: subtitle || "Discover Bahrain’s Grooming Scene", imageUrl, href, fallbackKey: "default_hallaq_city_banner" };
    })
    .filter(Boolean) as Array<{ id: string; title: string; subtitle: string; imageUrl: string; href: string; fallbackKey?: string }>;

  return (
    <>
      <RealtimeRefresh tables={["barbers", "barbershops", "reels", "offers"]} />
      <CityHome
        tTitle={t("customer.city.title")}
        tSubtitle={t("customer.city.subtitle")}
        tSearchPlaceholder={t("customer.city.searchPlaceholder")}
        heroItems={heroItems}
        topBarbers={topBarbers}
        newShops={newShops}
        bestReels={bestReels}
        offers={cityOffers}
        styles={cityStyles}
        hadDataErrors={Boolean(barbersError || shopsError || reelsError || offersError || stylesError || bannersError)}
      />
    </>
  );
}

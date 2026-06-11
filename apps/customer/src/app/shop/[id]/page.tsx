import { notFound } from "next/navigation";

import { signedOrUrl } from "@hallaq/supabase/storage";

import { RealtimeRefresh } from "@/components/realtime-refresh";
import { ShopProfileView, type ShopProfileData } from "@/app/shop/[id]/shop-profile";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type ShopRouteParams = {
  source?: string;
  reelId?: string;
  tab?: string;
  serviceId?: string;
  offerId?: string;
  barberId?: string;
};

function asStorageRef(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function safeParam(value: string | null | undefined) {
  const next = String(value ?? "").trim();
  return next || null;
}

function toShopBackHref(id: string, params: ShopRouteParams | undefined) {
  const source = safeParam(params?.source);
  const reelId = safeParam(params?.reelId);
  if (source === "reel" && reelId) return `/discover?reel=${encodeURIComponent(reelId)}`;
  if (source === "qr") return "/scan";
  if (source === "search") return "/search";
  if (source === "booking") return `/booking/new?shopId=${encodeURIComponent(id)}`;
  return "/discover";
}

function toInitialShopTab(params: ShopRouteParams | undefined) {
  const explicit = safeParam(params?.tab);
  if (explicit === "overview" || explicit === "barbers" || explicit === "services" || explicit === "portfolio" || explicit === "reviews" || explicit === "availability" || explicit === "offers" || explicit === "location") return explicit;
  if (safeParam(params?.offerId)) return "offers" as const;
  if (safeParam(params?.serviceId)) return "services" as const;
  if (safeParam(params?.barberId)) return "barbers" as const;
  if (safeParam(params?.reelId)) return "portfolio" as const;
  return "overview" as const;
}

export default async function ShopProfilePage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams?: Promise<ShopRouteParams>;
}) {
  const { id } = await params;
  const routeParams = searchParams ? await searchParams : undefined;
  const supabase = await createAppSupabaseServerClient();

  const { data: shopPublic } = await supabase
    .from("barbershops")
    .select("*")
    .eq("id", id)
    .eq("status", "approved")
    .eq("is_active", true)
    .is("deleted_at", null)
    .maybeSingle();

  const { data: shopAny } =
    shopPublic
      ? { data: null }
      : await supabase
          .from("barbershops")
          .select("*")
          .eq("id", id)
          .is("deleted_at", null)
          .maybeSingle();

  const shop = (shopPublic ?? shopAny) as typeof shopPublic | (typeof shopAny & { status?: string | null; is_active?: boolean | null });
  const shop_is_public = Boolean(shopPublic);
  if (!shop) notFound();

  const [
    { data: services },
    { data: barbers },
    { data: portfolio },
    { data: reels },
    { data: beforeAfter },
    { data: reviews },
    { data: offers },
    { data: customerRows },
    { data: health },
  ] = await Promise.all([
    supabase
      .from("services")
      .select("id, name_en, name_ar, description_en, description_ar, category, price_bhd, duration_minutes, image_url, active, is_active, status, deleted_at")
      .eq("shop_id", shop.id)
      .eq("is_active", true)
      .eq("status", "approved")
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(50),
    supabase
      .from("barbers")
      .select("id, display_name, avatar_url, avatar_path, rating_avg, rating_count, experience_years, specialty, is_verified, available_now")
      .eq("shop_id", shop.id)
      .eq("status", "approved")
      .eq("is_active", true)
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(30),
    supabase
      .from("portfolio_items")
      .select("id, media_type, media_url, media_path, thumbnail_url, thumbnail_path, caption, caption_en, category, created_at")
      .eq("owner_type", "shop")
      .eq("owner_id", shop.id)
      .eq("status", "approved")
      .order("created_at", { ascending: false })
      .limit(18),
    supabase
      .from("posts")
      .select("id, media_type, media_url, media_path, thumbnail_url, thumbnail_path, caption, created_at")
      .eq("shop_id", shop.id)
      .eq("status", "approved")
      .eq("is_active", true)
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(8),
    supabase
      .from("before_after_items")
      .select("id, before_image_path, after_image_path, caption, category, created_at")
      .eq("shop_id", shop.id)
      .not("approved_at", "is", null)
      .is("rejected_at", null)
      .order("created_at", { ascending: false })
      .limit(8),
    supabase
      .from("reviews")
      .select("id, rating, text, comment, reply_text, replied_at, created_at, is_verified, image_url, image_path, profiles(full_name, avatar_url, avatar_path)")
      .eq("target_type", "shop")
      .eq("target_id", shop.id)
      .eq("status", "approved")
      .eq("is_verified", true)
      .order("created_at", { ascending: false })
      .limit(25),
    supabase
      .from("offers")
      .select("id, title, description, offer_type, discount_percent, discount_amount, valid_from, valid_to, banner_url, banner_path, package_details")
      .eq("shop_id", shop.id)
      .eq("status", "approved")
      .eq("is_active", true)
      .order("created_at", { ascending: false })
      .limit(20),
    supabase.from("bookings").select("customer_profile_id").eq("shop_id", shop.id).in("status", ["confirmed", "completed"]).limit(5000),
    supabase.rpc("business_health_score", { p_entity_type: "shop", p_entity_id: shop.id }),
  ]);

  const logo = await signedOrUrl(supabase, "shop-images", shop.logo_path ?? shop.logo_url);
  const cover = await signedOrUrl(supabase, "shop-images", shop.cover_path ?? shop.cover_url);

  const barberCards = await Promise.all(
    (barbers ?? []).map(async (barber) => ({
      id: String(barber.id),
      display_name: barber.display_name ?? null,
      avatar_url: (await signedOrUrl(supabase, "barber-images", barber.avatar_path ?? barber.avatar_url)) ?? null,
      rating_avg: Number(barber.rating_avg ?? 0),
      rating_count: Number(barber.rating_count ?? 0),
      experience_years: barber.experience_years ?? null,
      specialty: barber.specialty ?? null,
      is_verified: Boolean(barber.is_verified),
      available_now: Boolean(barber.available_now),
    }))
  );

  const reviewRows = (reviews ?? []) as unknown as Array<{
    id: string;
    rating: number;
    text: string | null;
    comment: string | null;
    reply_text: string | null;
    replied_at: string | null;
    created_at: string;
    is_verified: boolean | null;
    image_url: string | null;
    image_path: string | null;
    profiles:
      | { full_name: string | null; avatar_url: string | null; avatar_path: string | null }
      | Array<{ full_name: string | null; avatar_url: string | null; avatar_path: string | null }>
      | null;
  }>;

  const signedReviews = await Promise.all(
    reviewRows.map(async (review) => ({
      id: String(review.id),
      rating: Number(review.rating ?? 0),
      text: review.text ?? null,
      comment: review.comment ?? null,
      reply_text: review.reply_text ?? null,
      replied_at: review.replied_at ?? null,
      created_at: review.created_at,
      is_verified: Boolean(review.is_verified),
      image_url:
        (await signedOrUrl(supabase, "review-images", review.image_path ?? review.image_url)) ??
        (await signedOrUrl(supabase, "review-photos", review.image_path ?? review.image_url)) ??
        review.image_url ??
        null,
      customer: {
        name: (Array.isArray(review.profiles) ? review.profiles[0]?.full_name : review.profiles?.full_name) ?? null,
        avatar:
          (await signedOrUrl(
            supabase,
            "avatars",
            Array.isArray(review.profiles)
              ? review.profiles[0]?.avatar_path ?? review.profiles[0]?.avatar_url
              : review.profiles?.avatar_path ?? review.profiles?.avatar_url
          )) ?? null,
      },
    }))
  );

  const reviewBreakdown = new Map<number, number>([
    [1, 0],
    [2, 0],
    [3, 0],
    [4, 0],
    [5, 0],
  ]);
  signedReviews.forEach((review) => reviewBreakdown.set(review.rating, (reviewBreakdown.get(review.rating) ?? 0) + 1));

  const signedPortfolio = await Promise.all(
    ((portfolio ?? []) as Array<Record<string, unknown>>).map(async (item) => ({
      id: String(item.id),
      media_type: item.media_type === "video" ? ("video" as const) : ("image" as const),
      media_url: (await signedOrUrl(supabase, "portfolio", asStorageRef(item.media_path) ?? asStorageRef(item.media_url))) ?? null,
      thumb_url:
        (await signedOrUrl(supabase, "portfolio", asStorageRef(item.thumbnail_path) ?? asStorageRef(item.thumbnail_url))) ??
        (await signedOrUrl(supabase, "portfolio", asStorageRef(item.media_path) ?? asStorageRef(item.media_url))) ??
        null,
      category: (item.category as string | null) ?? null,
      caption: ((item.caption ?? item.caption_en ?? null) as string | null) ?? null,
      created_at: (item.created_at as string | null) ?? null,
      kind: "portfolio" as const,
    }))
  );

  const signedReels = await Promise.all(
    ((reels ?? []) as Array<Record<string, unknown>>).map(async (item) => ({
      id: String(item.id),
      media_type: item.media_type === "video" ? ("video" as const) : ("image" as const),
      media_url:
        (await signedOrUrl(supabase, "reels-media", asStorageRef(item.media_path) ?? asStorageRef(item.media_url))) ??
        (await signedOrUrl(supabase, "reels", asStorageRef(item.media_path) ?? asStorageRef(item.media_url))) ??
        null,
      thumb_url:
        (await signedOrUrl(supabase, "reels-media", asStorageRef(item.thumbnail_path) ?? asStorageRef(item.thumbnail_url))) ??
        (await signedOrUrl(supabase, "reels", asStorageRef(item.thumbnail_path) ?? asStorageRef(item.thumbnail_url))) ??
        null,
      category: "reel",
      caption: (item.caption as string | null) ?? null,
      created_at: (item.created_at as string | null) ?? null,
      kind: "reel" as const,
    }))
  );

  const signedBeforeAfter = await Promise.all(
    ((beforeAfter ?? []) as Array<Record<string, unknown>>).map(async (item) => ({
      id: String(item.id),
      media_type: "image" as const,
      media_url: (await signedOrUrl(supabase, "before-after", asStorageRef(item.after_image_path))) ?? null,
      thumb_url: (await signedOrUrl(supabase, "before-after", asStorageRef(item.before_image_path))) ?? null,
      before_url: (await signedOrUrl(supabase, "before-after", asStorageRef(item.before_image_path))) ?? null,
      after_url: (await signedOrUrl(supabase, "before-after", asStorageRef(item.after_image_path))) ?? null,
      category: (item.category as string | null) ?? "Transformation",
      caption: (item.caption as string | null) ?? null,
      created_at: (item.created_at as string | null) ?? null,
      kind: "before_after" as const,
    }))
  );

  const mediaItems = [...signedPortfolio, ...signedReels, ...signedBeforeAfter].sort(
    (left, right) => new Date(right.created_at ?? 0).getTime() - new Date(left.created_at ?? 0).getTime()
  );

  const offerItems = await Promise.all(
    ((offers ?? []) as Array<Record<string, unknown>>).map(async (offer) => ({
      id: String(offer.id),
      title: (offer.title as string | null) ?? null,
      description: (offer.description as string | null) ?? null,
      offer_type: (offer.offer_type as string | null) ?? null,
      discount_percent: offer.discount_percent == null ? null : Number(offer.discount_percent),
      discount_amount: offer.discount_amount == null ? null : Number(offer.discount_amount),
      valid_from: (offer.valid_from as string | null) ?? null,
      valid_to: (offer.valid_to as string | null) ?? null,
      banner_url:
        (await signedOrUrl(supabase, "offer-images", asStorageRef(offer.banner_path) ?? asStorageRef(offer.banner_url))) ??
        (offer.banner_url as string | null) ??
        null,
      package_label:
        typeof (offer.package_details as { details?: unknown } | null)?.details === "string"
          ? String((offer.package_details as { details?: unknown }).details)
          : null,
    }))
  );

  const uniqueCustomers = new Set(
    ((customerRows ?? []) as Array<{ customer_profile_id: string | null }>)
      .map((row) => row.customer_profile_id)
      .filter((value): value is string => Boolean(value))
  );

  const metrics = (health as { metrics?: Record<string, unknown> } | null)?.metrics ?? {};

  const data: ShopProfileData = {
    shop: {
      id: shop.id,
      name: shop.name ?? null,
      description: shop.description ?? null,
      about_us: (shop as { about_us?: string | null }).about_us ?? null,
      story: (shop as { story?: string | null }).story ?? null,
      years_in_business: (shop as { years_in_business?: number | null }).years_in_business ?? null,
      specialties: ((shop as { specialties?: string[] | null }).specialties ?? []) as string[],
      awards: ((shop as { awards?: string[] | null }).awards ?? []) as string[],
      languages: ((shop as { languages?: string[] | null }).languages ?? []) as string[],
      area: shop.area ?? null,
      address: shop.address ?? null,
      phone: (shop as { phone?: string | null }).phone ?? null,
      whatsapp: (shop as { whatsapp?: string | null }).whatsapp ?? null,
      instagram: (shop as { instagram?: string | null }).instagram ?? null,
      opening_hours: ((shop as { opening_hours?: Record<string, string> | null }).opening_hours ?? null) as Record<string, string> | null,
      google_maps_url: (shop as { google_maps_url?: string | null }).google_maps_url ?? null,
      lat: typeof (shop as { lat?: number | null }).lat === "number" ? (shop as { lat: number }).lat : null,
      lng: typeof (shop as { lng?: number | null }).lng === "number" ? (shop as { lng: number }).lng : null,
      is_verified: Boolean((shop as { is_verified?: boolean | null }).is_verified),
      rating_avg: Number((shop as { rating_avg?: number | null }).rating_avg ?? 0),
      rating_count: Number((shop as { rating_count?: number | null }).rating_count ?? 0),
      followers_count: Number((shop as { followers_count?: number | null }).followers_count ?? 0),
      logo_url: logo ?? null,
      cover_url: cover ?? null,
    },
    stats: {
      barbers_count: barberCards.length,
      customers_count: uniqueCustomers.size || null,
      completion_rate: metrics.completionRate != null ? Number(metrics.completionRate) : null,
      bookings_30d: metrics.bookings30d != null ? Number(metrics.bookings30d) : null,
    },
    barbers: barberCards,
    services: ((services ?? []) as Array<Record<string, unknown>>).map((service) => ({
      id: String(service.id),
      name_en: (service.name_en as string | null) ?? null,
      name_ar: (service.name_ar as string | null) ?? null,
      description_en: (service.description_en as string | null) ?? null,
      description_ar: (service.description_ar as string | null) ?? null,
      category: (service.category as string | null) ?? null,
      price_bhd: (service.price_bhd as number | string | null) ?? null,
      duration_minutes: (service.duration_minutes as number | null) ?? null,
      image_url: (service.image_url as string | null) ?? null,
    })),
    portfolio: mediaItems,
    reviews: signedReviews,
    review_breakdown: Array.from(reviewBreakdown.entries()).map(([stars, count]) => ({
      stars: stars as 1 | 2 | 3 | 4 | 5,
      count,
    })),
    offers: offerItems,
    shop_is_public,
    entry: {
      source: safeParam(routeParams?.source),
      reelId: safeParam(routeParams?.reelId),
      initialTab: toInitialShopTab(routeParams),
      serviceId: safeParam(routeParams?.serviceId),
      offerId: safeParam(routeParams?.offerId),
      barberId: safeParam(routeParams?.barberId),
    },
    backHref: toShopBackHref(shop.id, routeParams),
  };

  return (
    <>
      <RealtimeRefresh tables={["barbershops", "barbers", "services", "portfolio_items", "posts", "reviews", "offers", "follows", "bookings"]} />
      <ShopProfileView data={data} />
    </>
  );
}

import { notFound } from "next/navigation";

import { signedOrUrl } from "@hallaq/supabase/storage";

import { BarberProfileView, type BarberProfileData } from "@/app/barber/[id]/barber-profile";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type BarberRouteParams = {
  source?: string;
  reelId?: string;
  tab?: string;
  serviceId?: string;
  offerId?: string;
};

type ShopRow = {
  id: string;
  name: string | null;
  area: string | null;
  address: string | null;
  phone: string | null;
  whatsapp: string | null;
  instagram: string | null;
  opening_hours: Record<string, string> | null;
  google_maps_url: string | null;
  lat: number | null;
  lng: number | null;
  is_verified: boolean | null;
  logo_url: string | null;
  logo_path: string | null;
};

function asStorageRef(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function safeParam(value: string | null | undefined) {
  const next = String(value ?? "").trim();
  return next || null;
}

function toBarberBackHref(id: string, params: BarberRouteParams | undefined) {
  const source = safeParam(params?.source);
  const reelId = safeParam(params?.reelId);
  if (source === "reel" && reelId) return `/discover?reel=${encodeURIComponent(reelId)}`;
  if (source === "qr") return "/scan";
  if (source === "search") return "/search";
  if (source === "booking") return `/booking/new?barberId=${encodeURIComponent(id)}`;
  return "/discover";
}

function toInitialBarberTab(params: BarberRouteParams | undefined) {
  const explicit = safeParam(params?.tab);
  if (explicit === "portfolio" || explicit === "services" || explicit === "reviews" || explicit === "availability" || explicit === "offers" || explicit === "about") return explicit;
  if (safeParam(params?.offerId)) return "offers" as const;
  if (safeParam(params?.serviceId)) return "services" as const;
  if (safeParam(params?.reelId)) return "portfolio" as const;
  return "portfolio" as const;
}

export default async function BarberProfilePage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams?: Promise<BarberRouteParams>;
}) {
  const { id } = await params;
  const routeParams = searchParams ? await searchParams : undefined;
  const supabase = await createAppSupabaseServerClient();

  const { data: barber } = await supabase
    .from("barbers")
    .select(
      "id, profile_id, display_name, bio, specialty, specialties, experience_years, area, address, shop_id, avatar_url, avatar_path, cover_url, cover_path, is_verified, rating_avg, rating_count, followers_count, instagram, tiktok, available_now, lat, lng"
    )
    .eq("id", id)
    .eq("status", "approved")
    .eq("is_active", true)
    .is("deleted_at", null)
    .maybeSingle();

  if (!barber) notFound();

  const [
    { data: shop },
    { data: barberProfile },
    { data: services },
    { data: portfolio },
    { data: reels },
    { data: beforeAfter },
    { data: reviews },
    { data: offers },
    { data: workingHours },
    { data: publicStats },
  ] = await Promise.all([
    barber.shop_id
      ? supabase
          .from("barbershops")
          .select("id, name, area, address, phone, whatsapp, instagram, opening_hours, google_maps_url, lat, lng, is_verified, logo_url, logo_path")
          .eq("id", barber.shop_id)
          .maybeSingle()
      : Promise.resolve<{ data: ShopRow | null }>({ data: null }),
    supabase.from("profiles").select("phone").eq("id", barber.profile_id).maybeSingle(),
    supabase
      .from("barber_services_effective")
      .select("id, name_en, name_ar, description_en, description_ar, price_bhd, duration_minutes, image_url, category, shop_id, barber_ref, status, deleted_at")
      .eq("barber_ref", barber.id)
      .or("status.eq.approved,status.is.null")
      .is("deleted_at", null)
      .order("is_popular", { ascending: false })
      .order("created_at", { ascending: false })
      .limit(50),
    supabase
      .from("portfolio_items")
      .select("id, media_type, media_url, media_path, thumbnail_url, thumbnail_path, caption, caption_en, category, created_at")
      .eq("owner_type", "barber")
      .eq("owner_id", barber.id)
      .eq("status", "approved")
      .order("created_at", { ascending: false })
      .limit(18),
    supabase
      .from("posts")
      .select("id, media_type, media_url, media_path, thumbnail_url, thumbnail_path, caption, created_at")
      .eq("barber_id", barber.id)
      .eq("status", "approved")
      .eq("is_active", true)
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(8),
    supabase
      .from("before_after_items")
      .select("id, before_image_path, after_image_path, caption, category, created_at")
      .eq("barber_id", barber.id)
      .not("approved_at", "is", null)
      .is("rejected_at", null)
      .order("created_at", { ascending: false })
      .limit(8),
    supabase
      .from("reviews")
      .select("id, rating, text, comment, reply_text, replied_at, created_at, is_verified, image_url, image_path, customer_profile_id, profiles(full_name, avatar_url, avatar_path)")
      .eq("target_type", "barber")
      .eq("target_id", barber.id)
      .eq("status", "approved")
      .eq("is_verified", true)
      .order("created_at", { ascending: false })
      .limit(25),
    barber.shop_id
      ? supabase
          .from("offers")
          .select("id, title, description, offer_type, discount_percent, discount_amount, valid_from, valid_to, banner_url, banner_path, package_details, barber_id")
          .eq("shop_id", barber.shop_id)
          .eq("status", "approved")
          .eq("is_active", true)
          .order("created_at", { ascending: false })
          .limit(20)
      : Promise.resolve<{ data: Array<Record<string, unknown>> }>({ data: [] }),
    supabase
      .from("barber_working_hours")
      .select("weekday, start_time, end_time, enabled")
      .eq("barber_id", barber.id)
      .order("weekday", { ascending: true })
      .limit(20),
    supabase.rpc("get_barber_public_stats", { p_barber_id: barber.id }),
  ]);

  const avatarUrl = (await signedOrUrl(supabase, "barber-images", barber.avatar_path ?? barber.avatar_url)) ?? null;
  const coverUrl = (await signedOrUrl(supabase, "barber-images", barber.cover_path ?? barber.cover_url)) ?? null;

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
    profiles: { full_name: string | null; avatar_url: string | null; avatar_path: string | null } | null;
  }>;

  const signedReviews = await Promise.all(
    reviewRows.map(async (r) => {
      const avatar =
        (await signedOrUrl(supabase, "avatars", r.profiles?.avatar_path ?? r.profiles?.avatar_url)) ?? null;
      const reviewImage =
        (await signedOrUrl(supabase, "review-images", r.image_path ?? r.image_url)) ??
        (await signedOrUrl(supabase, "review-photos", r.image_path ?? r.image_url)) ??
        r.image_url ??
        null;
      return {
        id: String(r.id),
        rating: Number(r.rating ?? 0),
        text: r.text ?? null,
        comment: r.comment ?? null,
        reply_text: r.reply_text ?? null,
        replied_at: r.replied_at ?? null,
        created_at: r.created_at,
        is_verified: Boolean(r.is_verified),
        image_url: reviewImage,
        customer: { name: r.profiles?.full_name ?? null, avatar }
      };
    })
  );

  const breakdownMap = new Map<number, number>([
    [1, 0],
    [2, 0],
    [3, 0],
    [4, 0],
    [5, 0]
  ]);
  for (const r of signedReviews) breakdownMap.set(r.rating, (breakdownMap.get(r.rating) ?? 0) + 1);

  const serviceRows = (services ?? []) as Array<{
    id: string;
    name_en: string | null;
    name_ar: string | null;
    description_en: string | null;
    description_ar: string | null;
    price_bhd: number | string | null;
    duration_minutes: number | null;
    image_url: string | null;
    category: string | null;
  }>;

  const signedPortfolioMedia = await Promise.all(
    (portfolio ?? []).map(async (item) => ({
      id: String(item.id),
      media_type: item.media_type === "video" ? ("video" as const) : ("image" as const),
      media_url: (await signedOrUrl(supabase, "portfolio", item.media_path ?? item.media_url)) ?? null,
      thumb_url:
        (await signedOrUrl(supabase, "portfolio", item.thumbnail_path ?? item.thumbnail_url)) ??
        (await signedOrUrl(supabase, "portfolio", item.media_path ?? item.media_url)) ??
        null,
      category: (item.category ?? null) as string | null,
      caption: ((item.caption ?? item.caption_en ?? null) as string | null) ?? null,
      created_at: (item.created_at ?? null) as string | null,
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

  const portfolioItems = [...signedPortfolioMedia, ...signedReels, ...signedBeforeAfter]
    .sort((left, right) => new Date(right.created_at ?? 0).getTime() - new Date(left.created_at ?? 0).getTime());

  const offerItems = await Promise.all(
    ((offers ?? []) as Array<Record<string, unknown>>)
      .filter((item) => {
        const barberId = String(item.barber_id ?? "").trim();
        return !barberId || barberId === barber.id;
      })
      .map(async (item) => ({
        id: String(item.id),
        title: (item.title as string | null) ?? null,
        description: (item.description as string | null) ?? null,
        offer_type: (item.offer_type as string | null) ?? null,
        discount_percent: item.discount_percent == null ? null : Number(item.discount_percent),
        discount_amount: item.discount_amount == null ? null : Number(item.discount_amount),
        valid_from: (item.valid_from as string | null) ?? null,
        valid_to: (item.valid_to as string | null) ?? null,
        banner_url:
          (await signedOrUrl(supabase, "offer-images", asStorageRef(item.banner_path) ?? asStorageRef(item.banner_url))) ??
          (item.banner_url as string | null) ??
          null,
        package_label:
          typeof (item.package_details as { details?: unknown } | null)?.details === "string"
            ? String((item.package_details as { details?: unknown }).details)
            : null,
      }))
  );

  const publicStatsRow = Array.isArray(publicStats) ? (publicStats[0] as Record<string, unknown> | undefined) : undefined;

  const data: BarberProfileData = {
    barber: {
      id: barber.id,
      display_name: barber.display_name,
      bio: barber.bio,
      specialty: barber.specialty,
      specialties: (barber.specialties as string[] | null) ?? [],
      experience_years: barber.experience_years ?? null,
      area: barber.area,
      address: barber.address,
      phone: (barberProfile?.phone as string | null) ?? null,
      instagram: barber.instagram ?? null,
      tiktok: barber.tiktok ?? null,
      is_verified: Boolean(barber.is_verified),
      available_now: Boolean(barber.available_now),
      rating_avg: Number(barber.rating_avg ?? 0),
      rating_count: Number(barber.rating_count ?? 0),
      followers_count: Number(barber.followers_count ?? 0),
      avatar_url: avatarUrl,
      cover_url: coverUrl,
      lat: typeof barber.lat === "number" ? barber.lat : null,
      lng: typeof barber.lng === "number" ? barber.lng : null,
    },
    shop: shop
      ? {
          id: shop.id,
          name: shop.name,
          area: shop.area,
          address: shop.address,
          phone: shop.phone,
          whatsapp: shop.whatsapp,
          instagram: shop.instagram,
          opening_hours: shop.opening_hours ?? null,
          google_maps_url: shop.google_maps_url,
          lat: typeof shop.lat === "number" ? shop.lat : null,
          lng: typeof shop.lng === "number" ? shop.lng : null,
          is_verified: Boolean(shop.is_verified),
        }
      : null,
    stats: {
      years_experience:
        publicStatsRow && publicStatsRow.years_experience != null ? Number(publicStatsRow.years_experience) : barber.experience_years ?? null,
      total_bookings: publicStatsRow && publicStatsRow.total_bookings != null ? Number(publicStatsRow.total_bookings) : null,
      completion_rate: publicStatsRow && publicStatsRow.completion_rate != null ? Number(publicStatsRow.completion_rate) * 100 : null,
    },
    services: serviceRows.map((s) => ({
      id: String(s.id),
      name_en: s.name_en ?? null,
      name_ar: s.name_ar ?? null,
      description_en: s.description_en ?? null,
      description_ar: s.description_ar ?? null,
      price_bhd: s.price_bhd ?? null,
      duration_minutes: s.duration_minutes ?? null,
      image_url: s.image_url ?? null,
      category: s.category ?? null,
    })),
    portfolio: portfolioItems,
    reviews: signedReviews,
    review_breakdown: (Array.from(breakdownMap.entries()).map(([stars, count]) => ({
      stars: stars as 1 | 2 | 3 | 4 | 5,
      count
    })) as BarberProfileData["review_breakdown"]),
    offers: offerItems,
    working_hours: ((workingHours ?? []) as Array<Record<string, unknown>>).map((item) => ({
      weekday: Number(item.weekday ?? 0),
      start_time: String(item.start_time ?? "10:00"),
      end_time: String(item.end_time ?? "22:00"),
      enabled: Boolean(item.enabled),
    })),
    entry: {
      source: safeParam(routeParams?.source),
      reelId: safeParam(routeParams?.reelId),
      initialTab: toInitialBarberTab(routeParams),
      serviceId: safeParam(routeParams?.serviceId),
      offerId: safeParam(routeParams?.offerId),
    },
    backHref: toBarberBackHref(barber.id, routeParams),
  };

  return <BarberProfileView data={data} />;
}

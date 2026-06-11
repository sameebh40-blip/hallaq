"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";

import { Button } from "@hallaq/ui/button";
import { cn } from "@hallaq/ui/cn";
import {
  BadgeCheck,
  ChevronLeft,
  Clock3,
  MapPin,
  Scissors,
  ShieldCheck,
  Sparkles,
  Star,
  Store,
  Users,
} from "lucide-react";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { ProfileActionBar, toMapsHref, toWaHref } from "@/components/profile/profile-actions";
import { SafeImage } from "@/components/safe-image";
import { trackOnce } from "@/lib/analytics";

type ShopTab = "overview" | "barbers" | "services" | "portfolio" | "reviews" | "availability" | "offers" | "location";

export type ShopProfileBarber = {
  id: string;
  display_name: string | null;
  avatar_url: string | null;
  rating_avg: number;
  rating_count: number;
  experience_years: number | null;
  specialty: string | null;
  is_verified: boolean;
  available_now: boolean;
};

export type ShopProfileService = {
  id: string;
  name_en: string | null;
  name_ar: string | null;
  description_en: string | null;
  description_ar: string | null;
  category: string | null;
  price_bhd: number | string | null;
  duration_minutes: number | null;
  image_url: string | null;
};

export type ShopProfileMedia = {
  id: string;
  media_url: string | null;
  thumb_url: string | null;
  media_type: "image" | "video";
  category: string | null;
  caption: string | null;
  kind: "portfolio" | "reel" | "before_after";
  created_at: string | null;
  before_url?: string | null;
  after_url?: string | null;
};

export type ShopProfileReview = {
  id: string;
  rating: number;
  text: string | null;
  comment: string | null;
  reply_text?: string | null;
  replied_at?: string | null;
  created_at: string;
  is_verified: boolean;
  image_url: string | null;
  customer: { name: string | null; avatar: string | null };
};

export type ShopProfileOffer = {
  id: string;
  title: string | null;
  description: string | null;
  offer_type: string | null;
  discount_percent: number | null;
  discount_amount: number | null;
  valid_from: string | null;
  valid_to: string | null;
  banner_url: string | null;
  package_label: string | null;
};

export type ShopProfileData = {
  shop: {
    id: string;
    name: string | null;
    description: string | null;
    about_us: string | null;
    story: string | null;
    years_in_business: number | null;
    specialties: string[];
    awards: string[];
    languages: string[];
    area: string | null;
    address: string | null;
    phone: string | null;
    whatsapp: string | null;
    instagram: string | null;
    opening_hours: Record<string, string> | null;
    google_maps_url: string | null;
    lat: number | null;
    lng: number | null;
    is_verified: boolean;
    rating_avg: number;
    rating_count: number;
    followers_count: number;
    logo_url: string | null;
    cover_url: string | null;
  };
  stats: {
    barbers_count: number;
    customers_count: number | null;
    completion_rate: number | null;
    bookings_30d: number | null;
  };
  barbers: ShopProfileBarber[];
  services: ShopProfileService[];
  portfolio: ShopProfileMedia[];
  reviews: ShopProfileReview[];
  review_breakdown: { stars: 1 | 2 | 3 | 4 | 5; count: number }[];
  offers: ShopProfileOffer[];
  shop_is_public: boolean;
  entry: {
    source: string | null;
    reelId: string | null;
    initialTab: ShopTab;
    serviceId: string | null;
    offerId: string | null;
    barberId: string | null;
  };
  backHref?: string;
};

function formatBhd(value: number | string | null | undefined) {
  return `BHD ${Number(value ?? 0).toFixed(3)}`;
}

function formatReviewDate(iso: string) {
  return new Intl.DateTimeFormat("en", { day: "numeric", month: "short", year: "numeric" }).format(new Date(iso));
}

function formatShortDate(iso: string | null | undefined) {
  if (!iso) return null;
  return new Intl.DateTimeFormat("en", { day: "numeric", month: "short" }).format(new Date(iso));
}

function useCachedGeolocation() {
  const [coords, setCoords] = useState<{ lat: number; lng: number } | null>(null);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const raw = window.localStorage.getItem("hallaq:last_location");
    if (raw) {
      try {
        const parsed = JSON.parse(raw) as { lat?: number; lng?: number };
        if (typeof parsed.lat === "number" && typeof parsed.lng === "number") {
          setCoords({ lat: parsed.lat, lng: parsed.lng });
        }
      } catch {}
    }
    if (!navigator.geolocation) return;
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const next = { lat: position.coords.latitude, lng: position.coords.longitude };
        setCoords(next);
        window.localStorage.setItem("hallaq:last_location", JSON.stringify({ ...next, at: Date.now() }));
      },
      () => undefined,
      { maximumAge: 600_000, timeout: 5_000, enableHighAccuracy: false },
    );
  }, []);

  return coords;
}

function kmBetween(a: { lat: number; lng: number }, b: { lat: number; lng: number }) {
  const toRad = (value: number) => (value * Math.PI) / 180;
  const radiusKm = 6371;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const x = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * radiusKm * Math.asin(Math.sqrt(x));
}

function travelTimeFromKm(km: number | null) {
  if (km == null) return null;
  const minutes = Math.max(2, Math.round((km / 32) * 60));
  return `${minutes} min`;
}

function isOpenNow(openingHours: Record<string, string> | null | undefined) {
  if (!openingHours) return null;
  const now = new Date();
  const key = new Intl.DateTimeFormat("en-US", { weekday: "short", timeZone: "Asia/Bahrain" }).format(now).toLowerCase().slice(0, 3);
  const raw = String(openingHours[key] ?? openingHours[key.toUpperCase()] ?? "").trim();
  if (!raw || raw.toLowerCase() === "closed") return false;
  const [start, end] = raw.split("-").map((part) => part.trim());
  if (!start || !end) return null;
  const current = Number(new Intl.DateTimeFormat("en-GB", { hour: "2-digit", minute: "2-digit", hour12: false, timeZone: "Asia/Bahrain" }).format(now).replace(":", ""));
  const startValue = Number(start.replace(":", ""));
  const endValue = Number(end.replace(":", ""));
  if (!Number.isFinite(current) || !Number.isFinite(startValue) || !Number.isFinite(endValue)) return null;
  return current >= startValue && current <= endValue;
}

function Stars({ value, size = "h-4 w-4" }: { value: number; size?: string }) {
  return (
    <div className="flex items-center gap-0.5">
      {Array.from({ length: 5 }).map((_, index) => (
        <Star key={index} className={cn(size, index < value ? "fill-[#D4AF37] text-[#D4AF37]" : "text-white/16")} />
      ))}
    </div>
  );
}

function SectionCard({ className, children }: { className?: string; children: React.ReactNode }) {
  return (
    <div
      className={cn(
        "overflow-hidden rounded-[28px] border border-white/8 bg-[linear-gradient(180deg,rgba(17,17,17,0.98),rgba(7,7,7,0.98))] shadow-[0_24px_60px_rgba(0,0,0,0.42)]",
        className,
      )}
    >
      {children}
    </div>
  );
}

function EmptyState({ title, description }: { title: string; description: string }) {
  return (
    <SectionCard className="p-6">
      <div className="text-sm font-semibold text-white">{title}</div>
      <div className="mt-1 text-sm text-[#B8B8B8]">{description}</div>
    </SectionCard>
  );
}

export function ShopProfileView({ data }: { data: ShopProfileData }) {
  const [tab, setTab] = useState<ShopTab>(data.entry.initialTab);
  const [showStickyBar, setShowStickyBar] = useState(false);
  const tabRefs = useRef<Record<string, HTMLButtonElement | null>>({});
  const coords = useCachedGeolocation();

  const shopName = data.shop.name ?? "Shop";
  const location = [data.shop.area, data.shop.address].filter(Boolean).join(", ");
  const rating = Number(data.shop.rating_avg ?? 0);
  const reviewsCount = Number(data.shop.rating_count ?? 0);
  const followers = Number(data.shop.followers_count ?? 0);
  const distanceKm =
    coords && typeof data.shop.lat === "number" && typeof data.shop.lng === "number"
      ? kmBetween(coords, { lat: data.shop.lat, lng: data.shop.lng })
      : null;
  const mapsHref = toMapsHref({
    googleMapsUrl: data.shop.google_maps_url,
    lat: data.shop.lat,
    lng: data.shop.lng,
    label: location,
  });
  const openNow = isOpenNow(data.shop.opening_hours);
  const bookHref = data.shop_is_public
    ? `/booking/new?shopId=${encodeURIComponent(data.shop.id)}${data.entry.barberId ? `&barberId=${encodeURIComponent(data.entry.barberId)}` : ""}${data.entry.serviceId ? `&serviceId=${encodeURIComponent(data.entry.serviceId)}` : ""}${data.entry.offerId ? `&offerId=${encodeURIComponent(data.entry.offerId)}` : ""}${data.entry.reelId ? `&reelId=${encodeURIComponent(data.entry.reelId)}` : ""}&source=${encodeURIComponent(data.entry.source ?? "shop_profile")}`
    : null;
  const waHref = toWaHref(data.shop.whatsapp) ?? toWaHref(data.shop.phone);
  const sourceLabel =
    data.entry.source === "reel"
      ? "Opened From Reel"
      : data.entry.source === "qr"
        ? "Opened From QR"
        : data.entry.source === "search"
          ? "Opened From Search"
          : null;

  useEffect(() => {
    if (!data.shop.id) return;
    void trackOnce(`shop_open:${data.shop.id}`, {
      event_name: "shop_open",
      entity_type: "shop",
      entity_id: data.shop.id,
      meta: { source: data.entry.source, reel_id: data.entry.reelId },
    });
  }, [data.entry.reelId, data.entry.source, data.shop.id]);

  useEffect(() => {
    const onScroll = () => setShowStickyBar(window.scrollY > 460);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    tabRefs.current[tab]?.scrollIntoView({ block: "nearest", inline: "center", behavior: "smooth" });
  }, [tab]);

  const tabs = [
    { id: "overview", label: "Overview" },
    { id: "barbers", label: "Barbers" },
    { id: "services", label: "Services" },
    { id: "portfolio", label: "Portfolio" },
    { id: "reviews", label: "Reviews" },
    { id: "availability", label: "Availability" },
    { id: "offers", label: "Offers" },
    { id: "location", label: "Location" },
  ] as const;

  const groupedServices = useMemo(() => {
    const groups = new Map<string, ShopProfileService[]>();
    data.services.forEach((service) => {
      const key = (service.category ?? "Featured").trim() || "Featured";
      const current = groups.get(key) ?? [];
      current.push(service);
      groups.set(key, current);
    });
    return Array.from(groups.entries());
  }, [data.services]);

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col bg-black pb-28 text-white">
      <div className="px-4 pt-4">
        <div className="mb-3 text-center">
          <div className="text-[11px] font-semibold uppercase tracking-[0.34em] text-[#D4AF37]">Hallaq</div>
          <div className="mt-1 text-[28px] font-semibold tracking-tight text-white">
            SHOP <span className="text-[#D4AF37]">&</span> PROFILE
          </div>
          <div className="mt-1 text-xs text-[#B8B8B8]">Luxury storefront, live actions, and premium barber discovery</div>
        </div>

        <SectionCard className="overflow-hidden">
          <div className="relative aspect-[16/17]">
            <SafeImage src={data.shop.cover_url} fallbackKey="default_shop_cover" alt={shopName} className="h-full w-full object-cover" />
            <div className="absolute inset-0 bg-[linear-gradient(180deg,rgba(0,0,0,0.28),rgba(0,0,0,0.1)_28%,rgba(0,0,0,0.92)_100%)]" />

            <div className="absolute inset-x-0 top-0 flex items-center justify-between px-4 pt-4">
              {data.backHref ? (
                <Link
                  href={data.backHref}
                  className="grid h-11 w-11 place-items-center rounded-full border border-white/12 bg-black/40 backdrop-blur-md transition hover:border-[#D4AF37]/35 hover:text-[#D4AF37]"
                >
                  <ChevronLeft className="h-5 w-5" />
                </Link>
              ) : (
                <div />
              )}
              <div className="rounded-full border border-[#D4AF37]/30 bg-black/45 px-3 py-2 text-sm font-semibold text-[#F3D97A] backdrop-blur-md">
                {rating.toFixed(1)} <span className="text-white/65">({reviewsCount})</span>
              </div>
            </div>

            <div className="absolute inset-x-0 bottom-0 px-4 pb-4">
              <div className="flex items-end gap-3">
                <div className="h-20 w-20 overflow-hidden rounded-[26px] border border-white/15 bg-[#111111] shadow-[0_18px_50px_rgba(0,0,0,0.45)]">
                  <SafeImage src={data.shop.logo_url} fallbackKey="default_shop_logo" alt={shopName} className="h-full w-full object-cover" />
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <div className="truncate text-[28px] font-semibold leading-none text-white">{shopName}</div>
                    {data.shop.is_verified ? <BadgeCheck className="h-5 w-5 shrink-0 text-[#D4AF37]" /> : null}
                  </div>
                  <div className="mt-2 flex flex-wrap items-center gap-2 text-sm text-[#E8E8E8]">
                    <span>{data.shop.area ?? "Bahrain"}</span>
                    {openNow != null ? (
                      <span className={cn("rounded-full px-2 py-1 text-[11px] font-semibold", openNow ? "bg-[#D4AF37]/14 text-[#D4AF37]" : "bg-white/10 text-[#B8B8B8]")}>
                        {openNow ? "Open Now" : "Closed"}
                      </span>
                    ) : null}
                    {sourceLabel ? <span className="rounded-full bg-white/10 px-2 py-1 text-[11px] font-semibold text-white/85">{sourceLabel}</span> : null}
                  </div>
                  <div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-[#B8B8B8]">
                    {location ? (
                      <span className="inline-flex items-center gap-1">
                        <MapPin className="h-3.5 w-3.5 text-[#D4AF37]" />
                        {location}
                      </span>
                    ) : null}
                    {distanceKm != null ? <span>{distanceKm.toFixed(distanceKm < 1 ? 1 : 0)} km</span> : null}
                    {travelTimeFromKm(distanceKm) ? <span>{travelTimeFromKm(distanceKm)}</span> : null}
                  </div>
                </div>
              </div>

              <div className="mt-4 rounded-[24px] border border-white/8 bg-black/45 p-4 backdrop-blur-md">
                <div className="grid grid-cols-4 gap-2 text-center">
                  {[
                    { label: "Barbers", value: data.stats.barbers_count.toLocaleString() },
                    { label: "Customers", value: data.stats.customers_count != null ? data.stats.customers_count.toLocaleString() : "—" },
                    { label: "Rating", value: rating.toFixed(1) },
                    { label: "Sat.", value: data.stats.completion_rate != null ? `${Math.round(data.stats.completion_rate)}%` : "—" },
                  ].map((item) => (
                    <div key={item.label} className="rounded-[18px] border border-white/8 bg-white/[0.03] px-2 py-3">
                      <div className="text-sm font-semibold text-white">{item.value}</div>
                      <div className="mt-1 text-[10px] leading-tight text-[#B8B8B8]">{item.label}</div>
                    </div>
                  ))}
                </div>

                {(data.shop.description ?? "").trim() ? <div className="mt-4 text-sm leading-6 text-[#D7D7D7]">{data.shop.description?.trim()}</div> : null}

                <div className="mt-3 flex flex-wrap gap-2">
                  {data.shop.specialties.slice(0, 4).map((item) => (
                    <span key={item} className="rounded-full border border-[#D4AF37]/18 bg-[#D4AF37]/8 px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.16em] text-[#E7C861]">
                      #{item.replace(/\s+/g, "")}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          </div>

          <div className="px-4 pb-4">
            <ProfileActionBar
              targetType="shop"
              targetId={data.shop.id}
              title={shopName}
              bookingHref={bookHref}
              phone={data.shop.phone}
              whatsapp={data.shop.whatsapp}
              sharePath={`/shop/${encodeURIComponent(data.shop.id)}?source=${encodeURIComponent(data.entry.source ?? "profile_share")}${data.entry.reelId ? `&reelId=${encodeURIComponent(data.entry.reelId)}` : ""}&tab=${encodeURIComponent(tab)}`}
              initialFollowers={followers}
            />
          </div>
        </SectionCard>

        <div className="mt-4 flex gap-2 overflow-x-auto pb-1 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
          {tabs.map((item) => (
            <button
              key={item.id}
              ref={(element) => {
                tabRefs.current[item.id] = element;
              }}
              type="button"
              onClick={() => setTab(item.id)}
              className={cn(
                "whitespace-nowrap rounded-full border px-4 py-2 text-xs font-semibold uppercase tracking-[0.18em] transition-all",
                tab === item.id ? "border-[#D4AF37]/42 bg-[#D4AF37]/12 text-[#D4AF37]" : "border-white/10 bg-white/[0.03] text-[#B8B8B8]",
              )}
            >
              {item.label}
            </button>
          ))}
        </div>

        <div className="mt-4 space-y-4">
          {tab === "overview" ? (
            <>
              <SectionCard className="p-5">
                <div className="grid grid-cols-3 gap-3">
                  {[
                    { icon: Store, title: "Premium Space", text: "Luxury environment and elevated presentation" },
                    { icon: Users, title: "Team Ready", text: `${data.stats.barbers_count} active barbers currently assigned` },
                    { icon: Sparkles, title: "Live Content", text: `${data.portfolio.length} approved media items and reels` },
                  ].map((item) => (
                    <div key={item.title} className="rounded-[22px] border border-white/8 bg-white/[0.03] p-4 text-center">
                      <item.icon className="mx-auto h-5 w-5 text-[#D4AF37]" />
                      <div className="mt-3 text-sm font-semibold text-white">{item.title}</div>
                      <div className="mt-1 text-[11px] text-[#B8B8B8]">{item.text}</div>
                    </div>
                  ))}
                </div>
              </SectionCard>

              <SectionCard className="p-5">
                <div className="text-xs uppercase tracking-[0.2em] text-[#D4AF37]">About the Shop</div>
                <div className="mt-3 space-y-4">
                  {(data.shop.about_us ?? data.shop.description ?? "").trim() ? (
                    <div className="text-sm leading-6 text-[#D0D0D0]">{(data.shop.about_us ?? data.shop.description ?? "").trim()}</div>
                  ) : null}
                  {(data.shop.story ?? "").trim() ? <div className="text-sm leading-6 text-[#C2C2C2]">{data.shop.story?.trim()}</div> : null}
                  <div className="grid gap-3 text-sm">
                    {data.shop.years_in_business != null ? (
                      <div className="flex items-center justify-between gap-3 rounded-[20px] border border-white/8 bg-white/[0.03] px-4 py-3">
                        <span className="text-[#B8B8B8]">Years in business</span>
                        <span className="font-semibold text-white">{data.shop.years_in_business}</span>
                      </div>
                    ) : null}
                    {data.shop.languages.length ? (
                      <div className="rounded-[20px] border border-white/8 bg-white/[0.03] px-4 py-3">
                        <div className="text-[#B8B8B8]">Languages</div>
                        <div className="mt-2 flex flex-wrap gap-2">
                          {data.shop.languages.map((value) => (
                            <span key={value} className="rounded-full border border-white/10 bg-white/[0.04] px-3 py-1 text-xs font-semibold text-white">
                              {value}
                            </span>
                          ))}
                        </div>
                      </div>
                    ) : null}
                    {data.shop.awards.length ? (
                      <div className="rounded-[20px] border border-white/8 bg-white/[0.03] px-4 py-3">
                        <div className="text-[#B8B8B8]">Awards</div>
                        <div className="mt-2 flex flex-wrap gap-2">
                          {data.shop.awards.map((value) => (
                            <span key={value} className="rounded-full border border-[#D4AF37]/18 bg-[#D4AF37]/8 px-3 py-1 text-xs font-semibold text-[#F3D97A]">
                              {value}
                            </span>
                          ))}
                        </div>
                      </div>
                    ) : null}
                  </div>
                </div>
              </SectionCard>

              {data.barbers.length ? (
                <SectionCard className="p-5">
                  <div className="flex items-center justify-between gap-3">
                    <div className="text-sm font-semibold text-white">Meet the barbers</div>
                    <button type="button" onClick={() => setTab("barbers")} className="text-xs font-semibold uppercase tracking-[0.18em] text-[#D4AF37]">
                      View all
                    </button>
                  </div>
                  <div className="mt-4 flex gap-3 overflow-x-auto pb-1 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
                    {data.barbers.slice(0, 8).map((barber) => (
                      <Link key={barber.id} href={`/barber/${encodeURIComponent(barber.id)}?source=${encodeURIComponent(data.entry.source ?? "shop_profile")}${data.entry.reelId ? `&reelId=${encodeURIComponent(data.entry.reelId)}` : ""}&tab=portfolio`} className="w-[118px] shrink-0">
                        <div className="overflow-hidden rounded-[24px] border border-white/8 bg-white/[0.03] p-3">
                          <div className="h-24 overflow-hidden rounded-[18px] border border-white/8 bg-[#111111]">
                            <SafeImage src={barber.avatar_url} fallbackKey="default_barber_avatar" alt={barber.display_name ?? "Barber"} className="h-full w-full object-cover" />
                          </div>
                          <div className="mt-3 line-clamp-1 text-sm font-semibold text-white">{barber.display_name ?? "Barber"}</div>
                          <div className="mt-1 flex items-center gap-1 text-xs text-[#B8B8B8]">
                            <Star className="h-3.5 w-3.5 fill-[#D4AF37] text-[#D4AF37]" />
                            {barber.rating_avg.toFixed(1)}
                          </div>
                        </div>
                      </Link>
                    ))}
                  </div>
                </SectionCard>
              ) : null}
            </>
          ) : null}

          {tab === "barbers" ? (
            data.barbers.length ? (
              data.barbers.map((barber) => (
                <SectionCard key={barber.id} className="p-4">
                  <div className="flex gap-3">
                    <div className="h-24 w-24 shrink-0 overflow-hidden rounded-[22px] border border-white/8 bg-[#111111]">
                      <SafeImage src={barber.avatar_url} fallbackKey="default_barber_avatar" alt={barber.display_name ?? "Barber"} className="h-full w-full object-cover" />
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="flex items-start justify-between gap-3">
                        <div>
                          <div className="flex items-center gap-2">
                            <div className="text-base font-semibold text-white">{barber.display_name ?? "Barber"}</div>
                            {barber.is_verified ? <BadgeCheck className="h-4.5 w-4.5 text-[#D4AF37]" /> : null}
                          </div>
                          <div className="mt-1 text-sm text-[#B8B8B8]">{barber.specialty ?? "Professional barber"}</div>
                        </div>
                        <div className="rounded-full border border-[#D4AF37]/20 bg-[#D4AF37]/8 px-3 py-1 text-xs font-semibold text-[#F3D97A]">
                          {barber.rating_avg.toFixed(1)}
                        </div>
                      </div>
                      <div className="mt-3 flex flex-wrap items-center gap-3 text-xs text-[#D0D0D0]">
                        {barber.experience_years != null ? <span>{barber.experience_years} years exp.</span> : null}
                        <span>{barber.rating_count.toLocaleString()} reviews</span>
                        <span className={barber.available_now ? "text-[#D4AF37]" : "text-[#B8B8B8]"}>{barber.available_now ? "Available now" : "Schedule live"}</span>
                      </div>
                      <div className="mt-4 grid grid-cols-2 gap-3">
                        <Button asChild={data.shop_is_public} disabled={!data.shop_is_public} className="h-11 rounded-[18px]">
                          {data.shop_is_public ? (
                            <Link
                              href={`/booking/new?shopId=${encodeURIComponent(data.shop.id)}&barberId=${encodeURIComponent(barber.id)}${data.entry.reelId ? `&reelId=${encodeURIComponent(data.entry.reelId)}` : ""}&source=${encodeURIComponent(data.entry.source ?? "shop_profile")}`}
                            >
                              Book
                            </Link>
                          ) : (
                            <span>Book</span>
                          )}
                        </Button>
                        <Button asChild variant="secondary" className="h-11 rounded-[18px] border border-white/10 bg-white/[0.03] text-white hover:bg-white/[0.06]">
                          <Link href={`/barber/${encodeURIComponent(barber.id)}?source=${encodeURIComponent(data.entry.source ?? "shop_profile")}${data.entry.reelId ? `&reelId=${encodeURIComponent(data.entry.reelId)}` : ""}&tab=portfolio`}>Open Profile</Link>
                        </Button>
                      </div>
                    </div>
                  </div>
                </SectionCard>
              ))
            ) : (
              <EmptyState title="No active barbers yet" description="Assigned, approved barbers appear here automatically as soon as they are active." />
            )
          ) : null}

          {tab === "services" ? (
            groupedServices.length ? (
              groupedServices.map(([group, services]) => (
                <SectionCard key={group} className="p-5">
                  <div className="text-xs uppercase tracking-[0.2em] text-[#D4AF37]">{group}</div>
                  <div className="mt-4 space-y-3">
                    {services.map((service) => (
                      <div key={service.id} className="rounded-[22px] border border-white/8 bg-white/[0.03] p-4">
                        <div className="flex gap-3">
                          <div className="h-20 w-20 shrink-0 overflow-hidden rounded-[18px] border border-white/8 bg-[#111111]">
                            <SafeImage src={service.image_url} fallbackKey="default_service_image" alt={service.name_en ?? service.name_ar ?? "Service"} className="h-full w-full object-cover" />
                          </div>
                          <div className="min-w-0 flex-1">
                            <div className="flex items-start justify-between gap-3">
                              <div>
                                <div className="text-base font-semibold text-white">{(service.name_en ?? service.name_ar ?? "Service").trim()}</div>
                                {(service.description_en ?? service.description_ar ?? "").trim() ? <div className="mt-1 line-clamp-2 text-sm text-[#B8B8B8]">{(service.description_en ?? service.description_ar ?? "").trim()}</div> : null}
                              </div>
                              <div className="rounded-full border border-[#D4AF37]/20 bg-[#D4AF37]/8 px-3 py-1 text-xs font-semibold text-[#F3D97A]">{formatBhd(service.price_bhd)}</div>
                            </div>
                            <div className="mt-3 flex items-center justify-between gap-3">
                              <div className="inline-flex items-center gap-2 text-sm text-[#D6D6D6]">
                                <Clock3 className="h-4 w-4 text-[#D4AF37]" />
                                {Number(service.duration_minutes ?? 30)} min
                              </div>
                              <Button asChild={data.shop_is_public} disabled={!data.shop_is_public} className="h-10 rounded-[16px] px-5">
                                {data.shop_is_public ? (
                                  <Link
                                    href={`/booking/new?shopId=${encodeURIComponent(data.shop.id)}&serviceId=${encodeURIComponent(service.id)}${data.entry.reelId ? `&reelId=${encodeURIComponent(data.entry.reelId)}` : ""}&source=${encodeURIComponent(data.entry.source ?? "shop_profile")}`}
                                  >
                                    Book
                                  </Link>
                                ) : (
                                  <span>Book</span>
                                )}
                              </Button>
                            </div>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </SectionCard>
              ))
            ) : (
              <EmptyState title="No approved services yet" description="All approved services appear here and connect directly to the booking flow." />
            )
          ) : null}

          {tab === "portfolio" ? (
            data.portfolio.length ? (
              <div className="grid grid-cols-2 gap-3">
                {data.portfolio.map((item, index) => (
                  <SectionCard key={item.id} className={cn(index % 5 === 0 ? "col-span-2" : "")}>
                    <div className={cn("relative", index % 5 === 0 ? "aspect-[16/10]" : "aspect-[4/5]")}>
                      {item.media_type === "video" ? (
                        <video className="h-full w-full object-cover" src={item.media_url ?? undefined} poster={item.thumb_url ?? undefined} controls playsInline preload="metadata" />
                      ) : (
                        <SafeImage src={item.kind === "before_after" ? item.after_url ?? item.media_url : item.media_url} fallbackKey="default_style_image" alt={item.caption ?? shopName} className="h-full w-full object-cover" />
                      )}
                      <div className="absolute bottom-3 left-3 rounded-full border border-[#D4AF37]/22 bg-black/60 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.18em] text-[#D4AF37]">
                        {item.category ?? item.kind}
                      </div>
                    </div>
                    <div className="p-4">
                      <div className="text-sm font-semibold text-white">{item.caption ?? (item.kind === "reel" ? "Shop reel" : item.kind === "before_after" ? "Before / After" : "Portfolio highlight")}</div>
                    </div>
                  </SectionCard>
                ))}
              </div>
            ) : (
              <EmptyState title="No approved portfolio yet" description="Shop photos, videos, reels, and transformations appear here as soon as they are published." />
            )
          ) : null}

          {tab === "reviews" ? (
            <>
              <SectionCard className="p-5">
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <div className="text-xs uppercase tracking-[0.2em] text-[#D4AF37]">Verified Reviews</div>
                    <div className="mt-2 text-4xl font-semibold text-white">{rating.toFixed(1)}</div>
                    <div className="mt-2">
                      <Stars value={Math.round(rating)} />
                    </div>
                  </div>
                  <div className="rounded-[22px] border border-white/8 bg-white/[0.03] px-4 py-3 text-right">
                    <div className="text-sm font-semibold text-white">{reviewsCount.toLocaleString()}</div>
                    <div className="mt-1 text-xs text-[#B8B8B8]">total reviews</div>
                  </div>
                </div>

                <div className="mt-5 space-y-3">
                  {data.review_breakdown
                    .slice()
                    .sort((left, right) => right.stars - left.stars)
                    .map((row) => {
                      const percent = reviewsCount > 0 ? Math.round((row.count / reviewsCount) * 100) : 0;
                      return (
                        <div key={row.stars} className="grid grid-cols-[34px_1fr_44px] items-center gap-3">
                          <div className="text-sm font-semibold text-white">{row.stars}.0</div>
                          <div className="h-2.5 overflow-hidden rounded-full bg-white/8">
                            <div className="h-full rounded-full bg-[linear-gradient(90deg,#D4AF37,#F1DA8B)]" style={{ width: `${percent}%` }} />
                          </div>
                          <div className="text-right text-xs text-[#B8B8B8]">{row.count}</div>
                        </div>
                      );
                    })}
                </div>
              </SectionCard>

              {data.reviews.length ? (
                data.reviews.map((review) => (
                  <SectionCard key={review.id} className="p-5">
                    <div className="flex gap-3">
                      <div className="h-12 w-12 shrink-0 overflow-hidden rounded-full border border-white/8 bg-[#111111]">
                        <SafeImage src={review.customer.avatar} fallbackKey="default_customer_avatar" alt={review.customer.name ?? "Customer"} className="h-full w-full object-cover" />
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="flex items-start justify-between gap-3">
                          <div>
                            <div className="text-sm font-semibold text-white">{review.customer.name ?? "Customer"}</div>
                            <div className="mt-1 flex items-center gap-2">
                              <Stars value={Number(review.rating ?? 0)} size="h-3.5 w-3.5" />
                              {review.is_verified ? <span className="rounded-full border border-[#D4AF37]/20 bg-[#D4AF37]/8 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.16em] text-[#D4AF37]">Verified</span> : null}
                            </div>
                          </div>
                          <div className="text-xs text-[#B8B8B8]">{formatReviewDate(review.created_at)}</div>
                        </div>
                        {(review.text ?? review.comment ?? "").trim() ? <div className="mt-3 text-sm leading-6 text-[#D0D0D0]">{(review.text ?? review.comment ?? "").trim()}</div> : null}
                        {review.image_url ? (
                          <div className="mt-3 overflow-hidden rounded-[20px] border border-white/8">
                            <SafeImage src={review.image_url} fallbackKey="default_style_image" alt="Review" className="h-52 w-full object-cover" />
                          </div>
                        ) : null}
                        {(review.reply_text ?? "").trim() ? (
                          <div className="mt-4 rounded-[20px] border border-[#D4AF37]/14 bg-[#D4AF37]/8 px-4 py-3">
                            <div className="text-[11px] font-semibold uppercase tracking-[0.2em] text-[#D4AF37]">Reply</div>
                            <div className="mt-2 text-sm text-white">{review.reply_text?.trim()}</div>
                            {review.replied_at ? <div className="mt-1 text-xs text-[#B8B8B8]">{formatReviewDate(review.replied_at)}</div> : null}
                          </div>
                        ) : null}
                      </div>
                    </div>
                  </SectionCard>
                ))
              ) : (
                <EmptyState title="No verified reviews yet" description="Approved reviews from verified bookings appear here automatically." />
              )}
            </>
          ) : null}

          {tab === "availability" ? (
            <SectionCard className="p-5">
              <div className="flex items-center justify-between gap-3">
                <div>
                  <div className="text-sm font-semibold text-white">Live shop availability</div>
                  <div className="mt-1 text-xs text-[#B8B8B8]">Current opening status, hours, and barber readiness</div>
                </div>
                <div className={cn("rounded-full px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.22em]", openNow ? "border border-[#D4AF37]/30 bg-[#D4AF37]/12 text-[#D4AF37]" : "border border-white/10 bg-white/[0.03] text-[#B8B8B8]")}>
                  {openNow ? "Open Now" : "Closed"}
                </div>
              </div>

              <div className="mt-4 space-y-3">
                {Object.entries(data.shop.opening_hours ?? {}).map(([day, hours]) => (
                  <div key={day} className="flex items-center justify-between rounded-[18px] border border-white/8 bg-white/[0.03] px-4 py-3">
                    <div className="text-sm font-medium text-white">{day.toUpperCase()}</div>
                    <div className="text-sm text-[#B8B8B8]">{hours}</div>
                  </div>
                ))}
              </div>

              <div className="mt-5 rounded-[22px] border border-white/8 bg-white/[0.03] p-4">
                <div className="text-sm font-semibold text-white">Available barbers now</div>
                <div className="mt-3 flex flex-wrap gap-2">
                  {data.barbers.filter((barber) => barber.available_now).length ? (
                    data.barbers
                      .filter((barber) => barber.available_now)
                      .map((barber) => (
                        <Link key={barber.id} href={`/barber/${encodeURIComponent(barber.id)}`} className="rounded-full border border-[#D4AF37]/20 bg-[#D4AF37]/8 px-3 py-2 text-xs font-semibold text-[#F3D97A]">
                          {barber.display_name ?? "Barber"}
                        </Link>
                      ))
                  ) : (
                    <div className="text-sm text-[#B8B8B8]">No barber is marked available right now. Open booking to view live schedules.</div>
                  )}
                </div>
              </div>
            </SectionCard>
          ) : null}

          {tab === "offers" ? (
            data.offers.length ? (
              data.offers.map((offer) => {
                const badge =
                  offer.offer_type === "package"
                    ? offer.package_label ?? "Package"
                    : offer.discount_percent != null
                      ? `${offer.discount_percent}% Off`
                      : offer.discount_amount != null
                        ? `${formatBhd(offer.discount_amount)} Off`
                        : "Offer";
                return (
                  <SectionCard key={offer.id} className="overflow-hidden">
                    <div className="relative aspect-[16/8]">
                      <SafeImage src={offer.banner_url} fallbackKey="default_offer_image" alt={offer.title ?? "Offer"} className="h-full w-full object-cover" />
                      <div className="absolute inset-0 bg-[linear-gradient(90deg,rgba(0,0,0,0.86),rgba(0,0,0,0.28))]" />
                      <div className="absolute inset-0 flex flex-col justify-between p-5">
                        <div className="inline-flex w-fit rounded-full border border-[#D4AF37]/22 bg-[#D4AF37]/12 px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-[#D4AF37]">{badge}</div>
                        <div>
                          <div className="text-2xl font-semibold text-white">{offer.title ?? "Offer"}</div>
                          {offer.description ? <div className="mt-2 max-w-[80%] text-sm text-[#D8D8D8]">{offer.description}</div> : null}
                        </div>
                      </div>
                    </div>
                    <div className="flex items-center justify-between gap-3 p-4">
                      <div className="text-xs text-[#B8B8B8]">{formatShortDate(offer.valid_from) || "Now"} {offer.valid_to ? `- ${formatShortDate(offer.valid_to)}` : ""}</div>
                      <Button asChild={data.shop_is_public} disabled={!data.shop_is_public} className="h-11 rounded-[18px] px-5">
                        {data.shop_is_public ? (
                          <Link
                            href={`/booking/new?shopId=${encodeURIComponent(data.shop.id)}&offerId=${encodeURIComponent(offer.id)}${data.entry.reelId ? `&reelId=${encodeURIComponent(data.entry.reelId)}` : ""}&source=${encodeURIComponent(data.entry.source ?? "shop_profile")}`}
                          >
                            Book Offer
                          </Link>
                        ) : (
                          <span>Book Offer</span>
                        )}
                      </Button>
                    </div>
                  </SectionCard>
                );
              })
            ) : (
              <EmptyState title="No live offers right now" description="Discounts, bundles, and packages appear here automatically as soon as they are approved." />
            )
          ) : null}

          {tab === "location" ? (
            <SectionCard className="overflow-hidden">
              <div className="p-5">
                <div className="text-xs uppercase tracking-[0.2em] text-[#D4AF37]">Location</div>
                <div className="mt-2 text-lg font-semibold text-white">{shopName}</div>
                <div className="mt-1 text-sm text-[#B8B8B8]">{location || "Bahrain"}</div>
                <div className="mt-3 flex flex-wrap items-center gap-3 text-xs text-[#D0D0D0]">
                  {distanceKm != null ? <span className="inline-flex items-center gap-1 rounded-full border border-white/10 bg-white/[0.03] px-3 py-1"><MapPin className="h-3.5 w-3.5 text-[#D4AF37]" />{distanceKm.toFixed(distanceKm < 1 ? 1 : 0)} km</span> : null}
                  {travelTimeFromKm(distanceKm) ? <span className="inline-flex items-center gap-1 rounded-full border border-white/10 bg-white/[0.03] px-3 py-1"><Clock3 className="h-3.5 w-3.5 text-[#D4AF37]" />{travelTimeFromKm(distanceKm)}</span> : null}
                </div>
              </div>

              {mapsHref ? (
                <div className="border-y border-white/8">
                  <iframe
                    title="Shop location"
                    src={
                      typeof data.shop.lat === "number" && typeof data.shop.lng === "number"
                        ? `https://www.google.com/maps?q=${encodeURIComponent(`${data.shop.lat},${data.shop.lng}`)}&z=15&output=embed`
                        : `https://www.google.com/maps?q=${encodeURIComponent(location || shopName)}&z=15&output=embed`
                    }
                    loading="lazy"
                    className="h-60 w-full border-0"
                  />
                </div>
              ) : null}

              <div className="grid grid-cols-2 gap-3 p-4">
                <Button asChild className="h-12 rounded-[18px]">
                  <a href={mapsHref ?? "#"} target="_blank" rel="noreferrer">Directions</a>
                </Button>
                <Button
                  asChild={Boolean(bookHref)}
                  disabled={!bookHref}
                  variant="secondary"
                  className="h-12 rounded-[18px] border border-white/10 bg-white/[0.03] text-white hover:bg-white/[0.06]"
                >
                  {bookHref ? <Link href={bookHref}>Book Now</Link> : <span>Book Now</span>}
                </Button>
              </div>
            </SectionCard>
          ) : null}

          <div className="grid grid-cols-3 gap-3">
            {[
              { icon: Store, title: "Luxury", text: "Premium storefront design" },
              { icon: Scissors, title: "Services", text: `${data.services.length} active treatments` },
              { icon: ShieldCheck, title: "Trusted", text: "Verified signals and live content" },
            ].map((item) => (
              <SectionCard key={item.title} className="p-4 text-center">
                <item.icon className="mx-auto h-5 w-5 text-[#D4AF37]" />
                <div className="mt-3 text-sm font-semibold text-white">{item.title}</div>
                <div className="mt-1 text-[11px] text-[#B8B8B8]">{item.text}</div>
              </SectionCard>
            ))}
          </div>
        </div>
      </div>

      {showStickyBar ? (
        <div className="fixed inset-x-0 bottom-16 z-50 mx-auto max-w-md px-4">
          <div className="rounded-[24px] border border-[#D4AF37]/18 bg-black/88 p-3 shadow-[0_26px_70px_rgba(0,0,0,0.6)] backdrop-blur-xl">
            <div className="mb-2 flex items-center justify-between gap-3">
              <div>
                <div className="text-sm font-semibold text-white">{shopName}</div>
                <div className="text-[11px] uppercase tracking-[0.18em] text-[#D4AF37]">{openNow ? "Open Now" : "Book Live Schedule"}</div>
              </div>
              <div className="text-right text-xs text-[#B8B8B8]">{data.stats.barbers_count} barbers</div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <Button asChild={Boolean(bookHref)} disabled={!bookHref} className="h-12 rounded-[18px]">
                {bookHref ? <Link href={bookHref}>Book Now</Link> : <span>Book Now</span>}
              </Button>
              <Button asChild variant="secondary" className="h-12 rounded-[18px] border border-white/10 bg-white/[0.03] text-white hover:bg-white/[0.06]">
                <a href={waHref ?? "#"} target="_blank" rel="noreferrer">
                  Message
                </a>
              </Button>
            </div>
          </div>
        </div>
      ) : null}

      <CustomerBottomNav />
    </main>
  );
}

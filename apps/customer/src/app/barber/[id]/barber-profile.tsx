"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";

import { Button } from "@hallaq/ui/button";
import { cn } from "@hallaq/ui/cn";
import {
  BadgeCheck,
  CalendarDays,
  ChevronLeft,
  Clock3,
  Gem,
  MapPin,
  Play,
  ShieldCheck,
  Sparkles,
  Star,
} from "lucide-react";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { ProfileActionBar, toMapsHref, toWaHref } from "@/components/profile/profile-actions";
import { SafeImage } from "@/components/safe-image";
import { trackOnce } from "@/lib/analytics";
import { createAppSupabaseBrowserClient } from "@/lib/supabase-browser";

export type BarberProfileService = {
  id: string;
  name_en: string | null;
  name_ar: string | null;
  description_en: string | null;
  description_ar: string | null;
  price_bhd: number | string | null;
  duration_minutes: number | null;
  image_url: string | null;
  category: string | null;
};

export type BarberProfileMedia = {
  id: string;
  media_url: string | null;
  thumb_url: string | null;
  media_type: "image" | "video";
  category: string | null;
  caption: string | null;
  created_at: string | null;
  kind: "portfolio" | "reel" | "before_after";
  before_url?: string | null;
  after_url?: string | null;
};

export type BarberProfileReview = {
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

export type BarberProfileOffer = {
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

export type BarberProfileWorkingHour = {
  weekday: number;
  start_time: string;
  end_time: string;
  enabled: boolean;
};

export type BarberProfileData = {
  barber: {
    id: string;
    display_name: string | null;
    bio: string | null;
    specialty: string | null;
    specialties: string[];
    experience_years: number | null;
    area: string | null;
    address: string | null;
    phone: string | null;
    instagram: string | null;
    tiktok: string | null;
    is_verified: boolean;
    available_now: boolean;
    rating_avg: number;
    rating_count: number;
    followers_count: number;
    avatar_url: string | null;
    cover_url: string | null;
    lat: number | null;
    lng: number | null;
  };
  shop: {
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
    is_verified: boolean;
  } | null;
  stats: {
    years_experience: number | null;
    total_bookings: number | null;
    completion_rate: number | null;
  };
  services: BarberProfileService[];
  portfolio: BarberProfileMedia[];
  reviews: BarberProfileReview[];
  review_breakdown: { stars: 1 | 2 | 3 | 4 | 5; count: number }[];
  offers: BarberProfileOffer[];
  working_hours: BarberProfileWorkingHour[];
  entry: {
    source: string | null;
    reelId: string | null;
    initialTab: BarberTab;
    serviceId: string | null;
    offerId: string | null;
  };
  backHref?: string;
};

type BarberTab = "portfolio" | "services" | "reviews" | "availability" | "offers" | "about";

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

function weekdayLabel(weekday: number) {
  return ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][weekday] ?? "Day";
}

function formatTimeRange(start: string, end: string) {
  const startLabel = start.slice(0, 5);
  const endLabel = end.slice(0, 5);
  return `${startLabel} - ${endLabel}`;
}

function travelTimeFromKm(km: number | null) {
  if (km == null) return null;
  const minutes = Math.max(2, Math.round((km / 32) * 60));
  return `${minutes} min`;
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

function Stars({ value, size = "h-4 w-4" }: { value: number; size?: string }) {
  return (
    <div className="flex items-center gap-0.5">
      {Array.from({ length: 5 }).map((_, index) => (
        <Star
          key={index}
          className={cn(size, index < value ? "fill-[#D4AF37] text-[#D4AF37]" : "text-white/16")}
        />
      ))}
    </div>
  );
}

function useCachedGeolocation() {
  const [coords, setCoords] = useState<{ lat: number; lng: number } | null>(null);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const raw = window.localStorage.getItem("hallaq:last_location");
    if (raw) {
      try {
        const parsed = JSON.parse(raw) as { lat?: number; lng?: number; at?: number };
        if (typeof parsed.lat === "number" && typeof parsed.lng === "number") {
          setCoords({ lat: parsed.lat, lng: parsed.lng });
        }
      } catch {}
    }
    if (!navigator.geolocation) return;
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const next = {
          lat: position.coords.latitude,
          lng: position.coords.longitude,
        };
        setCoords(next);
        window.localStorage.setItem("hallaq:last_location", JSON.stringify({ ...next, at: Date.now() }));
      },
      () => undefined,
      { maximumAge: 600_000, timeout: 5_000, enableHighAccuracy: false },
    );
  }, []);

  return coords;
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

function AvailabilityPanel({
  barberId,
  services,
  workingHours,
}: {
  barberId: string;
  services: BarberProfileService[];
  workingHours: BarberProfileWorkingHour[];
}) {
  const supabase = useMemo(() => createAppSupabaseBrowserClient(), []);
  const [selectedServiceId, setSelectedServiceId] = useState<string | null>(services[0]?.id ?? null);
  const [days, setDays] = useState<string[]>([]);
  const [selectedDay, setSelectedDay] = useState<string | null>(null);
  const [times, setTimes] = useState<string[]>([]);
  const [loadingDays, setLoadingDays] = useState(false);
  const [loadingTimes, setLoadingTimes] = useState(false);

  const selectedService = services.find((service) => service.id === selectedServiceId) ?? services[0] ?? null;

  useEffect(() => {
    if (!selectedService?.id) return;
    let active = true;
    setLoadingDays(true);
    setTimes([]);
    setSelectedDay(null);
    const now = new Date();
    const month = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-01`;
    void (async () => {
      try {
        const { data } = await supabase.rpc("get_available_days", {
          barber: barberId,
          month,
          duration_minutes: Number(selectedService.duration_minutes ?? 30),
          slot_minutes: 30,
        });
        if (!active) return;
        const nextDays = ((Array.isArray(data) ? data : []) as Array<{ day?: string; has_slots?: boolean }>)
          .filter((row) => row.has_slots && row.day)
          .map((row) => String(row.day))
          .slice(0, 7);
        setDays(nextDays);
        setSelectedDay(nextDays[0] ?? null);
      } finally {
        if (active) setLoadingDays(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [barberId, selectedService?.duration_minutes, selectedService?.id, supabase]);

  useEffect(() => {
    if (!selectedDay || !selectedService?.id) return;
    let active = true;
    setLoadingTimes(true);
    void (async () => {
      try {
        const { data } = await supabase.rpc("get_available_times", {
          barber: barberId,
          day: selectedDay,
          duration_minutes: Number(selectedService.duration_minutes ?? 30),
        });
        if (!active) return;
        const nextTimes = ((Array.isArray(data) ? data : []) as Array<{ start_at?: string } | string>)
          .map((row) => (typeof row === "string" ? row : row.start_at ?? null))
          .filter((value): value is string => Boolean(value))
          .slice(0, 8);
        setTimes(nextTimes);
      } finally {
        if (active) setLoadingTimes(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [barberId, selectedDay, selectedService?.duration_minutes, selectedService?.id, supabase]);

  return (
    <div className="space-y-4">
      <SectionCard className="p-5">
        <div className="flex items-center justify-between gap-3">
          <div>
            <div className="text-sm font-semibold text-white">Working Hours</div>
            <div className="mt-1 text-xs text-[#B8B8B8]">Live slots are pulled from the booking engine</div>
          </div>
          <div
            className={cn(
              "rounded-full border px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.22em]",
              workingHours.some((entry) => entry.enabled)
                ? "border-[#D4AF37]/30 bg-[#D4AF37]/10 text-[#D4AF37]"
                : "border-white/10 bg-white/[0.03] text-[#B8B8B8]",
            )}
          >
            {workingHours.some((entry) => entry.enabled) ? "Open Schedule" : "Closed"}
          </div>
        </div>

        <div className="mt-4 space-y-3">
          {workingHours.length ? (
            workingHours.map((entry) => (
              <div
                key={`${entry.weekday}-${entry.start_time}`}
                className="flex items-center justify-between rounded-[18px] border border-white/8 bg-white/[0.02] px-4 py-3"
              >
                <div className="text-sm font-medium text-white">{weekdayLabel(entry.weekday)}</div>
                <div className="text-sm text-[#B8B8B8]">{entry.enabled ? formatTimeRange(entry.start_time, entry.end_time) : "Closed"}</div>
              </div>
            ))
          ) : (
            <div className="rounded-[18px] border border-white/8 bg-white/[0.02] px-4 py-4 text-sm text-[#B8B8B8]">Working hours are syncing from the shop schedule.</div>
          )}
        </div>
      </SectionCard>

      <SectionCard className="p-5">
        <div className="flex items-center justify-between gap-3">
          <div>
            <div className="text-sm font-semibold text-white">Available Slots</div>
            <div className="mt-1 text-xs text-[#B8B8B8]">Select a service to preview the next bookable times</div>
          </div>
          <CalendarDays className="h-4.5 w-4.5 text-[#D4AF37]" />
        </div>

        {services.length ? (
          <div className="mt-4 flex gap-2 overflow-x-auto pb-1 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
            {services.slice(0, 8).map((service) => (
              <button
                key={service.id}
                type="button"
                onClick={() => setSelectedServiceId(service.id)}
                className={cn(
                  "whitespace-nowrap rounded-full border px-4 py-2 text-xs font-semibold transition-all",
                  selectedServiceId === service.id
                    ? "border-[#D4AF37]/40 bg-[#D4AF37]/12 text-[#D4AF37]"
                    : "border-white/10 bg-white/[0.03] text-[#B8B8B8]",
                )}
              >
                {(service.name_en ?? service.name_ar ?? "Service").trim() || "Service"}
              </button>
            ))}
          </div>
        ) : null}

        <div className="mt-4">
          {loadingDays ? (
            <div className="grid grid-cols-3 gap-2">
              {Array.from({ length: 6 }).map((_, index) => (
                <div key={index} className="h-16 animate-pulse rounded-[18px] border border-white/8 bg-white/[0.04]" />
              ))}
            </div>
          ) : days.length ? (
            <div className="grid grid-cols-3 gap-2">
              {days.map((day) => (
                <button
                  key={day}
                  type="button"
                  onClick={() => setSelectedDay(day)}
                  className={cn(
                    "rounded-[18px] border px-3 py-3 text-left transition-all",
                    selectedDay === day
                      ? "border-[#D4AF37]/45 bg-[#D4AF37]/12"
                      : "border-white/8 bg-white/[0.03]",
                  )}
                >
                  <div className="text-[11px] uppercase tracking-[0.18em] text-[#B8B8B8]">
                    {new Intl.DateTimeFormat("en", { weekday: "short" }).format(new Date(day))}
                  </div>
                  <div className="mt-1 text-sm font-semibold text-white">
                    {new Intl.DateTimeFormat("en", { day: "numeric", month: "short" }).format(new Date(day))}
                  </div>
                </button>
              ))}
            </div>
          ) : (
            <div className="rounded-[18px] border border-white/8 bg-white/[0.03] px-4 py-4 text-sm text-[#B8B8B8]">No open slots were found in the next few days for this service.</div>
          )}
        </div>

        <div className="mt-4 flex flex-wrap gap-2">
          {loadingTimes ? (
            Array.from({ length: 6 }).map((_, index) => (
              <div key={index} className="h-10 w-24 animate-pulse rounded-full border border-white/8 bg-white/[0.04]" />
            ))
          ) : times.length ? (
            times.map((time) => (
              <div key={time} className="rounded-full border border-[#D4AF37]/18 bg-[#D4AF37]/8 px-4 py-2 text-xs font-semibold text-[#F2E0A0]">
                {new Intl.DateTimeFormat("en", { hour: "numeric", minute: "2-digit", hour12: true, timeZone: "Asia/Bahrain" }).format(new Date(time))}
              </div>
            ))
          ) : selectedDay ? (
            <div className="text-sm text-[#B8B8B8]">Slots are refreshing for the selected day.</div>
          ) : null}
        </div>
      </SectionCard>
    </div>
  );
}

export function BarberProfileView({ data }: { data: BarberProfileData }) {
  const [tab, setTab] = useState<BarberTab>(data.entry.initialTab);
  const [portfolioFilter, setPortfolioFilter] = useState<string>("all");
  const [showStickyBar, setShowStickyBar] = useState(false);
  const tabRefs = useRef<Record<string, HTMLButtonElement | null>>({});
  const coords = useCachedGeolocation();

  const barberName = data.barber.display_name ?? "Barber";
  const rating = Number(data.barber.rating_avg ?? 0);
  const reviewsCount = Number(data.barber.rating_count ?? 0);
  const followerCount = Number(data.barber.followers_count ?? 0);
  const totalHaircuts = Number(data.stats.total_bookings ?? 0);
  const satisfaction = data.stats.completion_rate != null ? Math.round(Number(data.stats.completion_rate)) : null;
  const yearsExperience = data.stats.years_experience ?? data.barber.experience_years;
  const profileLocation = [data.shop?.area ?? data.barber.area, data.shop?.address ?? data.barber.address].filter(Boolean).join(", ");

  const destination =
    typeof data.shop?.lat === "number" && typeof data.shop?.lng === "number"
      ? { lat: data.shop.lat, lng: data.shop.lng }
      : typeof data.barber.lat === "number" && typeof data.barber.lng === "number"
        ? { lat: data.barber.lat, lng: data.barber.lng }
        : null;

  const distanceKm = coords && destination ? kmBetween(coords, destination) : null;
  const mapsHref = toMapsHref({
    googleMapsUrl: data.shop?.google_maps_url,
    lat: data.shop?.lat ?? data.barber.lat,
    lng: data.shop?.lng ?? data.barber.lng,
    label: profileLocation,
  });
  const bookHref = `/booking/new?barberId=${encodeURIComponent(data.barber.id)}${data.shop?.id ? `&shopId=${encodeURIComponent(data.shop.id)}` : ""}${data.entry.reelId ? `&reelId=${encodeURIComponent(data.entry.reelId)}` : ""}${data.entry.serviceId ? `&serviceId=${encodeURIComponent(data.entry.serviceId)}` : ""}${data.entry.offerId ? `&offerId=${encodeURIComponent(data.entry.offerId)}` : ""}&source=${encodeURIComponent(data.entry.source ?? "barber_profile")}`;
  const waHref = toWaHref(data.shop?.whatsapp) ?? toWaHref(data.barber.phone);
  const sourceLabel =
    data.entry.source === "reel"
      ? "Opened From Reel"
      : data.entry.source === "qr"
        ? "Opened From QR"
        : data.entry.source === "search"
          ? "Opened From Search"
          : null;

  useEffect(() => {
    if (!data.barber.id) return;
    void trackOnce(`barber_open:${data.barber.id}`, {
      event_name: "barber_open",
      entity_type: "barber",
      entity_id: data.barber.id,
      meta: { shop_id: data.shop?.id ?? null, source: data.entry.source, reel_id: data.entry.reelId },
    });
  }, [data.barber.id, data.entry.reelId, data.entry.source, data.shop?.id]);

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
    { id: "portfolio", label: "Portfolio" },
    { id: "services", label: "Services" },
    { id: "reviews", label: "Reviews" },
    { id: "availability", label: "Availability" },
    { id: "offers", label: "Offers" },
    { id: "about", label: "About" },
  ] as const;

  const portfolioCategories = useMemo(() => {
    const set = new Set<string>();
    data.portfolio.forEach((item) => {
      const key = (item.category ?? item.kind).trim();
      if (key) set.add(key);
    });
    return ["all", ...Array.from(set).slice(0, 6)];
  }, [data.portfolio]);

  const filteredPortfolio = useMemo(
    () =>
      portfolioFilter === "all"
        ? data.portfolio
        : data.portfolio.filter((item) => (item.category ?? item.kind).trim().toLowerCase() === portfolioFilter.toLowerCase()),
    [data.portfolio, portfolioFilter],
  );

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col bg-black pb-28 text-white">
      <div className="px-4 pt-4">
        <div className="mb-3 text-center">
          <div className="text-[11px] font-semibold uppercase tracking-[0.34em] text-[#D4AF37]">Hallaq</div>
          <div className="mt-1 text-[28px] font-semibold tracking-tight text-white">
            BARBER <span className="text-[#D4AF37]">&</span> PROFILE
          </div>
          <div className="mt-1 text-xs text-[#B8B8B8]">Premium barber details, live booking, and luxury presentation</div>
        </div>

        <SectionCard className="overflow-hidden">
          <div className="relative aspect-[16/17]">
            <SafeImage
              src={data.barber.cover_url}
              fallbackKey="default_barber_cover"
              alt={barberName}
              className="h-full w-full object-cover"
            />
            <div className="absolute inset-0 bg-[linear-gradient(180deg,rgba(0,0,0,0.28),rgba(0,0,0,0.1)_28%,rgba(0,0,0,0.9)_100%)]" />

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
                  <SafeImage
                    src={data.barber.avatar_url}
                    fallbackKey="default_barber_avatar"
                    alt={barberName}
                    className="h-full w-full object-cover"
                  />
                </div>

                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <div className="truncate text-[28px] font-semibold leading-none text-white">{barberName}</div>
                    {data.barber.is_verified ? <BadgeCheck className="h-5 w-5 shrink-0 text-[#D4AF37]" /> : null}
                  </div>
                  <div className="mt-2 flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-[#E8E8E8]">
                    {data.shop?.name ? <span>{data.shop.name}</span> : null}
                    {data.shop?.is_verified ? <ShieldCheck className="h-3.5 w-3.5 text-[#D4AF37]" /> : null}
                    <span className={cn("rounded-full px-2 py-1 text-[11px] font-semibold", data.barber.available_now ? "bg-[#D4AF37]/14 text-[#D4AF37]" : "bg-white/10 text-[#B8B8B8]")}>
                      {data.barber.available_now ? "Available Now" : "Schedule Live"}
                    </span>
                    {sourceLabel ? <span className="rounded-full bg-white/10 px-2 py-1 text-[11px] font-semibold text-white/85">{sourceLabel}</span> : null}
                  </div>
                  <div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-[#B8B8B8]">
                    {profileLocation ? (
                      <span className="inline-flex items-center gap-1">
                        <MapPin className="h-3.5 w-3.5 text-[#D4AF37]" />
                        {profileLocation}
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
                    { label: "Years Exp.", value: yearsExperience != null ? `${yearsExperience}` : "—" },
                    { label: "Followers", value: followerCount.toLocaleString() },
                    { label: "Haircuts", value: totalHaircuts ? totalHaircuts.toLocaleString() : "—" },
                    { label: "Sat.", value: satisfaction != null ? `${satisfaction}%` : "—" },
                  ].map((item) => (
                    <div key={item.label} className="rounded-[18px] border border-white/8 bg-white/[0.03] px-2 py-3">
                      <div className="text-sm font-semibold text-white">{item.value}</div>
                      <div className="mt-1 text-[10px] leading-tight text-[#B8B8B8]">{item.label}</div>
                    </div>
                  ))}
                </div>

                {(data.barber.bio ?? "").trim() ? (
                  <div className="mt-4 text-sm leading-6 text-[#D7D7D7]">{data.barber.bio?.trim()}</div>
                ) : null}

                <div className="mt-3 flex flex-wrap gap-2">
                  {[data.barber.specialty, ...data.barber.specialties].filter(Boolean).slice(0, 4).map((item) => (
                    <span
                      key={item}
                      className="rounded-full border border-[#D4AF37]/18 bg-[#D4AF37]/8 px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.16em] text-[#E7C861]"
                    >
                      #{String(item).replace(/\s+/g, "")}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          </div>

          <div className="px-4 pb-4">
            <ProfileActionBar
              targetType="barber"
              targetId={data.barber.id}
              title={barberName}
              bookingHref={bookHref}
              phone={data.barber.phone ?? data.shop?.phone}
              whatsapp={data.shop?.whatsapp}
              sharePath={`/barber/${encodeURIComponent(data.barber.id)}?source=${encodeURIComponent(data.entry.source ?? "profile_share")}${data.entry.reelId ? `&reelId=${encodeURIComponent(data.entry.reelId)}` : ""}&tab=${encodeURIComponent(tab)}`}
              initialFollowers={followerCount}
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
                tab === item.id
                  ? "border-[#D4AF37]/42 bg-[#D4AF37]/12 text-[#D4AF37]"
                  : "border-white/10 bg-white/[0.03] text-[#B8B8B8]",
              )}
            >
              {item.label}
            </button>
          ))}
        </div>

        <div className="mt-4 space-y-4">
          {tab === "portfolio" ? (
            filteredPortfolio.length ? (
              <>
                <div className="flex gap-2 overflow-x-auto pb-1 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
                  {portfolioCategories.map((category) => (
                    <button
                      key={category}
                      type="button"
                      onClick={() => setPortfolioFilter(category)}
                      className={cn(
                        "whitespace-nowrap rounded-full border px-4 py-2 text-xs font-semibold transition-all",
                        portfolioFilter === category
                          ? "border-[#D4AF37]/38 bg-[#D4AF37]/12 text-[#D4AF37]"
                          : "border-white/10 bg-white/[0.03] text-[#B8B8B8]",
                      )}
                    >
                      {category === "all" ? "All" : category}
                    </button>
                  ))}
                </div>

                <div className="grid grid-cols-2 gap-3">
                  {filteredPortfolio.map((item, index) => {
                    const mediaUrl = item.kind === "before_after" ? item.after_url ?? item.before_url : item.media_url;
                    return (
                      <SectionCard key={item.id} className={cn(index % 5 === 0 ? "col-span-2" : "")}>
                        <div className={cn("relative", index % 5 === 0 ? "aspect-[16/10]" : "aspect-[4/5]")}>
                          {item.media_type === "video" ? (
                            <>
                              <video
                                className="h-full w-full object-cover"
                                src={mediaUrl ?? undefined}
                                poster={item.thumb_url ?? undefined}
                                controls
                                playsInline
                                preload="metadata"
                              />
                              <div className="pointer-events-none absolute right-3 top-3 rounded-full border border-white/10 bg-black/45 px-2 py-1 text-[11px] font-semibold text-white">
                                <span className="inline-flex items-center gap-1">
                                  <Play className="h-3 w-3 fill-current" />
                                  Reel
                                </span>
                              </div>
                            </>
                          ) : (
                            <SafeImage
                              src={mediaUrl}
                              fallbackKey="default_style_image"
                              alt={item.caption ?? barberName}
                              className="h-full w-full object-cover"
                            />
                          )}

                          {item.kind === "before_after" && item.before_url ? (
                            <div className="absolute bottom-3 left-3 rounded-full border border-[#D4AF37]/26 bg-black/60 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.18em] text-[#D4AF37]">
                              Transformation
                            </div>
                          ) : null}
                        </div>
                        <div className="p-4">
                          <div className="flex items-center justify-between gap-3">
                            <div className="text-sm font-semibold text-white">{item.category ?? (item.kind === "reel" ? "Reel" : item.kind === "before_after" ? "Before / After" : "Portfolio")}</div>
                            <div className="text-[11px] uppercase tracking-[0.16em] text-[#B8B8B8]">{item.kind}</div>
                          </div>
                          {item.caption ? <div className="mt-1 text-sm text-[#B8B8B8]">{item.caption}</div> : null}
                        </div>
                      </SectionCard>
                    );
                  })}
                </div>
              </>
            ) : (
              <EmptyState title="No approved portfolio yet" description="Photos, videos, beard work, and transformations appear here as soon as they are published." />
            )
          ) : null}

          {tab === "services" ? (
            data.services.length ? (
              data.services.map((service) => {
                const name = (service.name_en ?? service.name_ar ?? "Service").trim() || "Service";
                const description = (service.description_en ?? service.description_ar ?? "").trim();
                return (
                  <SectionCard key={service.id} className="p-4">
                    <div className="flex gap-3">
                      <div className="h-24 w-24 shrink-0 overflow-hidden rounded-[22px] border border-white/8 bg-[#111111]">
                        <SafeImage
                          src={service.image_url}
                          fallbackKey="default_service_image"
                          alt={name}
                          className="h-full w-full object-cover"
                        />
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="flex items-start justify-between gap-3">
                          <div>
                            <div className="text-base font-semibold text-white">{name}</div>
                            {service.category ? <div className="mt-1 text-xs uppercase tracking-[0.2em] text-[#D4AF37]">{service.category}</div> : null}
                          </div>
                          <div className="rounded-full border border-[#D4AF37]/20 bg-[#D4AF37]/8 px-3 py-1 text-xs font-semibold text-[#F3D97A]">
                            {formatBhd(service.price_bhd)}
                          </div>
                        </div>
                        {description ? <div className="mt-2 line-clamp-2 text-sm text-[#B8B8B8]">{description}</div> : null}
                        <div className="mt-3 flex items-center justify-between gap-3">
                          <div className="inline-flex items-center gap-2 text-sm text-[#D6D6D6]">
                            <Clock3 className="h-4 w-4 text-[#D4AF37]" />
                            {Number(service.duration_minutes ?? 30)} min
                          </div>
                          <Button asChild className="h-11 rounded-[18px] px-5">
                            <Link
                              href={`/booking/new?barberId=${encodeURIComponent(data.barber.id)}${data.shop?.id ? `&shopId=${encodeURIComponent(data.shop.id)}` : ""}&serviceId=${encodeURIComponent(service.id)}${data.entry.reelId ? `&reelId=${encodeURIComponent(data.entry.reelId)}` : ""}&source=${encodeURIComponent(data.entry.source ?? "barber_profile")}`}
                            >
                              Book
                            </Link>
                          </Button>
                        </div>
                      </div>
                    </div>
                  </SectionCard>
                );
              })
            ) : (
              <EmptyState title="No approved services yet" description="Assigned services appear here and link directly into the live booking flow." />
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
                        <SafeImage
                          src={review.customer.avatar}
                          fallbackKey="default_customer_avatar"
                          alt={review.customer.name ?? "Customer"}
                          className="h-full w-full object-cover"
                        />
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="flex items-start justify-between gap-3">
                          <div>
                            <div className="text-sm font-semibold text-white">{review.customer.name ?? "Customer"}</div>
                            <div className="mt-1 flex items-center gap-2">
                              <Stars value={Number(review.rating ?? 0)} size="h-3.5 w-3.5" />
                              {review.is_verified ? (
                                <span className="rounded-full border border-[#D4AF37]/20 bg-[#D4AF37]/8 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.16em] text-[#D4AF37]">
                                  Verified
                                </span>
                              ) : null}
                            </div>
                          </div>
                          <div className="text-xs text-[#B8B8B8]">{formatReviewDate(review.created_at)}</div>
                        </div>

                        {(review.text ?? review.comment ?? "").trim() ? (
                          <div className="mt-3 text-sm leading-6 text-[#D0D0D0]">{(review.text ?? review.comment ?? "").trim()}</div>
                        ) : null}

                        {review.image_url ? (
                          <div className="mt-3 overflow-hidden rounded-[20px] border border-white/8">
                            <SafeImage
                              src={review.image_url}
                              fallbackKey="default_style_image"
                              alt="Review"
                              className="h-52 w-full object-cover"
                            />
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
                <EmptyState title="No verified reviews yet" description="Approved post-visit reviews with booking verification appear here automatically." />
              )}
            </>
          ) : null}

          {tab === "availability" ? (
            <AvailabilityPanel barberId={data.barber.id} services={data.services} workingHours={data.working_hours} />
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
                      <SafeImage
                        src={offer.banner_url}
                        fallbackKey="default_offer_image"
                        alt={offer.title ?? "Offer"}
                        className="h-full w-full object-cover"
                      />
                      <div className="absolute inset-0 bg-[linear-gradient(90deg,rgba(0,0,0,0.86),rgba(0,0,0,0.28))]" />
                      <div className="absolute inset-0 flex flex-col justify-between p-5">
                        <div className="inline-flex w-fit rounded-full border border-[#D4AF37]/22 bg-[#D4AF37]/12 px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-[#D4AF37]">
                          {badge}
                        </div>
                        <div>
                          <div className="text-2xl font-semibold text-white">{offer.title ?? "Offer"}</div>
                          {offer.description ? <div className="mt-2 max-w-[80%] text-sm text-[#D8D8D8]">{offer.description}</div> : null}
                        </div>
                      </div>
                    </div>
                    <div className="flex items-center justify-between gap-3 p-4">
                      <div className="text-xs text-[#B8B8B8]">
                        {formatShortDate(offer.valid_from) || "Now"} {offer.valid_to ? `- ${formatShortDate(offer.valid_to)}` : ""}
                      </div>
                  <Button asChild className="h-11 rounded-[18px] px-5">
                    <Link href={`/booking/new?barberId=${encodeURIComponent(data.barber.id)}&offerId=${encodeURIComponent(offer.id)}${data.entry.reelId ? `&reelId=${encodeURIComponent(data.entry.reelId)}` : ""}&source=${encodeURIComponent(data.entry.source ?? "barber_profile")}`}>
                          Book Offer
                        </Link>
                      </Button>
                    </div>
                  </SectionCard>
                );
              })
            ) : (
              <EmptyState title="No live offers right now" description="Approved discounts, packages, and promotions appear here the moment they go live." />
            )
          ) : null}

          {tab === "about" ? (
            <>
              <SectionCard className="p-5">
                <div className="text-xs uppercase tracking-[0.2em] text-[#D4AF37]">About</div>
                <div className="mt-3 space-y-4">
                  {(data.barber.bio ?? "").trim() ? (
                    <div>
                      <div className="text-sm font-semibold text-white">Bio</div>
                      <div className="mt-1 text-sm leading-6 text-[#CFCFCF]">{data.barber.bio?.trim()}</div>
                    </div>
                  ) : null}

                  <div className="grid gap-3 text-sm">
                    {yearsExperience != null ? (
                      <div className="flex items-center justify-between gap-3 rounded-[20px] border border-white/8 bg-white/[0.03] px-4 py-3">
                        <span className="text-[#B8B8B8]">Experience</span>
                        <span className="font-semibold text-white">{yearsExperience} years</span>
                      </div>
                    ) : null}
                    {(data.barber.specialty ?? "").trim() ? (
                      <div className="flex items-center justify-between gap-3 rounded-[20px] border border-white/8 bg-white/[0.03] px-4 py-3">
                        <span className="text-[#B8B8B8]">Specialty</span>
                        <span className="text-right font-semibold text-white">{data.barber.specialty}</span>
                      </div>
                    ) : null}
                    {data.barber.specialties.length ? (
                      <div className="rounded-[20px] border border-white/8 bg-white/[0.03] px-4 py-3">
                        <div className="text-[#B8B8B8]">Specialties</div>
                        <div className="mt-2 flex flex-wrap gap-2">
                          {data.barber.specialties.map((specialty) => (
                            <span key={specialty} className="rounded-full border border-[#D4AF37]/18 bg-[#D4AF37]/8 px-3 py-1 text-xs font-semibold text-[#F3D97A]">
                              {specialty}
                            </span>
                          ))}
                        </div>
                      </div>
                    ) : null}
                    {data.shop?.name ? (
                      <div className="flex items-center justify-between gap-3 rounded-[20px] border border-white/8 bg-white/[0.03] px-4 py-3">
                        <span className="text-[#B8B8B8]">Shop</span>
                        <span className="text-right font-semibold text-white">{data.shop.name}</span>
                      </div>
                    ) : null}
                    {data.barber.instagram ? (
                      <div className="flex items-center justify-between gap-3 rounded-[20px] border border-white/8 bg-white/[0.03] px-4 py-3">
                        <span className="text-[#B8B8B8]">Instagram</span>
                        <span className="text-right font-semibold text-white">{data.barber.instagram}</span>
                      </div>
                    ) : null}
                    {data.barber.tiktok ? (
                      <div className="flex items-center justify-between gap-3 rounded-[20px] border border-white/8 bg-white/[0.03] px-4 py-3">
                        <span className="text-[#B8B8B8]">TikTok</span>
                        <span className="text-right font-semibold text-white">{data.barber.tiktok}</span>
                      </div>
                    ) : null}
                  </div>
                </div>
              </SectionCard>

              <SectionCard className="overflow-hidden">
                <div className="p-5">
                  <div className="text-xs uppercase tracking-[0.2em] text-[#D4AF37]">Location</div>
                  <div className="mt-2 text-lg font-semibold text-white">{data.shop?.name ?? barberName}</div>
                  <div className="mt-1 text-sm text-[#B8B8B8]">{profileLocation || "Bahrain"}</div>
                  <div className="mt-3 flex flex-wrap items-center gap-3 text-xs text-[#D0D0D0]">
                    {distanceKm != null ? (
                      <span className="inline-flex items-center gap-1 rounded-full border border-white/10 bg-white/[0.03] px-3 py-1">
                        <MapPin className="h-3.5 w-3.5 text-[#D4AF37]" />
                        {distanceKm.toFixed(distanceKm < 1 ? 1 : 0)} km
                      </span>
                    ) : null}
                    {travelTimeFromKm(distanceKm) ? (
                      <span className="inline-flex items-center gap-1 rounded-full border border-white/10 bg-white/[0.03] px-3 py-1">
                        <Clock3 className="h-3.5 w-3.5 text-[#D4AF37]" />
                        {travelTimeFromKm(distanceKm)}
                      </span>
                    ) : null}
                  </div>
                </div>

                {mapsHref ? (
                  <div className="border-y border-white/8">
                    <iframe
                      title="Barber location"
                      src={
                        typeof data.shop?.lat === "number" && typeof data.shop?.lng === "number"
                          ? `https://www.google.com/maps?q=${encodeURIComponent(`${data.shop.lat},${data.shop.lng}`)}&z=15&output=embed`
                          : `https://www.google.com/maps?q=${encodeURIComponent(profileLocation || barberName)}&z=15&output=embed`
                      }
                      loading="lazy"
                      className="h-60 w-full border-0"
                    />
                  </div>
                ) : null}

                <div className="grid grid-cols-2 gap-3 p-4">
                  <Button asChild className="h-12 rounded-[18px]">
                    <a href={mapsHref ?? "#"} target="_blank" rel="noreferrer">
                      Directions
                    </a>
                  </Button>
                  <Button asChild variant="secondary" className="h-12 rounded-[18px] border border-white/10 bg-white/[0.03] text-white hover:bg-white/[0.06]">
                    <Link href={bookHref}>
                      Book Now
                    </Link>
                  </Button>
                </div>
              </SectionCard>
            </>
          ) : null}
        </div>

        <div className="mt-6 grid grid-cols-3 gap-3">
          {[
            { icon: Sparkles, title: "Premium", text: "Luxury profile detail" },
            { icon: Gem, title: "Realtime", text: "Follow and content updates" },
            { icon: ShieldCheck, title: "Verified", text: "Trusted booking signals" },
          ].map((item) => (
            <SectionCard key={item.title} className="p-4 text-center">
              <item.icon className="mx-auto h-5 w-5 text-[#D4AF37]" />
              <div className="mt-3 text-sm font-semibold text-white">{item.title}</div>
              <div className="mt-1 text-[11px] text-[#B8B8B8]">{item.text}</div>
            </SectionCard>
          ))}
        </div>
      </div>

      {showStickyBar ? (
        <div className="fixed inset-x-0 bottom-16 z-50 mx-auto max-w-md px-4">
          <div className="rounded-[24px] border border-[#D4AF37]/18 bg-black/88 p-3 shadow-[0_26px_70px_rgba(0,0,0,0.6)] backdrop-blur-xl">
            <div className="mb-2 flex items-center justify-between gap-3">
              <div>
                <div className="text-sm font-semibold text-white">{barberName}</div>
                <div className="text-[11px] uppercase tracking-[0.18em] text-[#D4AF37]">{data.barber.available_now ? "Available Now" : "Book Live Schedule"}</div>
              </div>
              <div className="text-right text-xs text-[#B8B8B8]">{rating.toFixed(1)} rating</div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <Button asChild className="h-12 rounded-[18px]">
                <Link href={bookHref}>Book Now</Link>
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

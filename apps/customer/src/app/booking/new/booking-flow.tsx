"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { cn } from "@hallaq/ui/cn";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { ArrowLeft, BadgeCheck, Check, CreditCard, Heart, MapPin, Search, Star, Wallet } from "lucide-react";

import { SafeImage } from "@/components/safe-image";
import { createAppSupabaseBrowserClient } from "@/lib/supabase-browser";
import { trackOnce } from "@/lib/analytics";

type InitialState = {
  shopId: string | null;
  barberId: string | null;
  serviceId: string | null;
  reelId: string | null;
  offerId: string | null;
  sourcePostId: string | null;
  source: string | null;
};

type Props = {
  initial: InitialState;
  backHref: string;
};

type BarberRow = {
  id: string;
  display_name: string | null;
  shop_id: string | null;
  avatar_url: string | null;
  rating_avg: number | null;
  rating_count: number | null;
  area: string | null;
  available_now: boolean | null;
  is_verified: boolean | null;
  is_active: boolean | null;
  status: string | null;
  deleted_at: string | null;
  lat: number | null;
  lng: number | null;
  barbershops: { id: string; name: string | null; area: string | null; lat: number | null; lng: number | null }[] | null;
};

type ShopRow = {
  id: string;
  name: string | null;
  area: string | null;
  lat: number | null;
  lng: number | null;
  logo_url: string | null;
};

type ServiceRow = {
  id: string;
  name_en: string | null;
  name_ar: string | null;
  price_bhd: number | string | null;
  duration_minutes: number | null;
  image_url: string | null;
  shop_id?: string | null;
};

type OfferRow = {
  id: string;
  shop_id: string | null;
  barber_id: string | null;
  offer_type: string | null;
  discount_percent: number | string | null;
  discount_amount: number | string | null;
  active: boolean | null;
  is_active?: boolean | null;
  status?: string | null;
  valid_from: string | null;
  valid_to: string | null;
};

type HoldRow = { hold_id: string | null; expires_at: string | null };

type BookingRow = {
  id: string;
  shop_id: string | null;
  barber_id: string | null;
  service_id: string | null;
  start_at: string;
  end_at: string;
  status: string;
  price_bhd: number | string | null;
  discount_amount: number | string | null;
  total_price: number | string | null;
  payment_method: string | null;
  payment_status: string | null;
  source: string | null;
  reel_id: string | null;
  offer_id: string | null;
  created_at: string | null;
};

type Step = "select" | "service" | "date" | "time" | "review" | "payment" | "confirmed";

function formatBhd(value: number | string | null | undefined) {
  return `BHD ${Number(value ?? 0).toFixed(3)}`;
}

function safeStr(v: unknown) {
  const s = String(v ?? "").trim();
  return s || null;
}

function kmBetween(a: { lat: number; lng: number }, b: { lat: number; lng: number }) {
  const toRad = (v: number) => (v * Math.PI) / 180;
  const R = 6371;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const x = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(x));
}

function formatTimeBahrain(iso: string) {
  return new Intl.DateTimeFormat("en", { hour: "numeric", minute: "2-digit", hour12: true, timeZone: "Asia/Bahrain" }).format(new Date(iso));
}

function formatDateBahrain(date: Date) {
  return new Intl.DateTimeFormat("en", { weekday: "long", day: "numeric", month: "long", year: "numeric", timeZone: "Asia/Bahrain" }).format(date);
}

function isoDate(date: Date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function monthLabel(date: Date) {
  return new Intl.DateTimeFormat("en", { month: "long", year: "numeric", timeZone: "Asia/Bahrain" }).format(date);
}

function createMonthGrid(anchor: Date) {
  const first = new Date(anchor.getFullYear(), anchor.getMonth(), 1);
  const startWeekday = first.getDay();
  const start = new Date(first);
  start.setDate(first.getDate() - startWeekday);
  const cells: Date[] = [];
  for (let i = 0; i < 42; i++) {
    const d = new Date(start);
    d.setDate(start.getDate() + i);
    cells.push(d);
  }
  return cells;
}

function userFacingBookingError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong. Please try again.";
  switch (m) {
    case "NOT_AUTHENTICATED":
      return "Please sign in to book.";
    case "SERVICE_NOT_FOUND":
      return "Service not found.";
    case "SERVICE_INACTIVE":
      return "This service is not available right now.";
    case "SERVICE_NOT_FOR_BARBER":
      return "This service is not available for this barber.";
    case "SERVICE_NOT_FOR_SHOP":
      return "This service is not available for this shop.";
    case "INVALID_SHOP":
      return "This shop is not available right now.";
    case "INVALID_BARBER":
      return "This barber is not available right now.";
    case "BARBER_NOT_IN_SHOP":
      return "This barber is not available in that shop.";
    case "BARBER_TIME_OFF":
      return "This time is not available.";
    case "BOOKING_OVERLAP":
      return "This time is no longer available. Please choose another time.";
    case "SLOT_HELD":
      return "This time is being held by another customer. Please choose another time.";
    case "HOLD_NOT_FOUND":
    case "HOLD_MISMATCH":
      return "This time is no longer reserved. Please choose another time.";
    case "BARBER_INACTIVE":
      return "This barber is not available right now.";
    case "SHOP_INACTIVE":
      return "This shop is not available right now.";
    case "PAYMENT_METHOD_NOT_SUPPORTED":
      return "This payment method is coming soon. Please choose Cash at Shop.";
    default:
      return m;
  }
}

function segmentedTimes(times: string[]) {
  const morning: string[] = [];
  const afternoon: string[] = [];
  const evening: string[] = [];
  for (const t of times) {
    const d = new Date(t);
    const h = Number(new Intl.DateTimeFormat("en", { hour: "numeric", hour12: false, timeZone: "Asia/Bahrain" }).format(d));
    if (h < 12) morning.push(t);
    else if (h < 17) afternoon.push(t);
    else evening.push(t);
  }
  return { morning, afternoon, evening };
}

function useCachedGeolocation() {
  const [pos, setPos] = useState<{ lat: number; lng: number } | null>(null);
  useEffect(() => {
    if (typeof window === "undefined") return;
    const raw = safeStr(window.localStorage.getItem("hallaq:last_location"));
    if (raw) {
      try {
        const v = JSON.parse(raw) as { lat?: number; lng?: number; at?: number };
        const lat = typeof v.lat === "number" ? v.lat : null;
        const lng = typeof v.lng === "number" ? v.lng : null;
        const at = typeof v.at === "number" ? v.at : null;
        if (lat != null && lng != null && at != null && Date.now() - at < 6 * 60 * 60 * 1000) {
          setPos({ lat, lng });
          return;
        }
      } catch {}
    }

    if (!navigator.geolocation) return;
    navigator.geolocation.getCurrentPosition(
      (p) => {
        const next = { lat: p.coords.latitude, lng: p.coords.longitude };
        setPos(next);
        try {
          window.localStorage.setItem("hallaq:last_location", JSON.stringify({ ...next, at: Date.now() }));
        } catch {}
      },
      () => {},
      { enableHighAccuracy: true, maximumAge: 6 * 60 * 60 * 1000, timeout: 6_000 }
    );
  }, []);
  return pos;
}

export function BookingFlow({ initial, backHref }: Props) {
  const supabaseRef = useRef<ReturnType<typeof createAppSupabaseBrowserClient> | null>(null);
  if (!supabaseRef.current) supabaseRef.current = createAppSupabaseBrowserClient();
  const supabase = supabaseRef.current;

  const pos = useCachedGeolocation();

  const [step, setStep] = useState<Step>(() => (initial.barberId ? "service" : "select"));
  const [tab, setTab] = useState<"nearby" | "top" | "following">("nearby");
  const [query, setQuery] = useState("");

  const [shopId, setShopId] = useState<string | null>(initial.shopId);
  const [barberId, setBarberId] = useState<string | null>(initial.barberId);
  const [serviceId, setServiceId] = useState<string | null>(initial.serviceId);
  const [reelId] = useState<string | null>(initial.reelId);
  const [offerId] = useState<string | null>(initial.offerId);
  const [sourcePostId] = useState<string | null>(initial.sourcePostId);
  const [source] = useState<string>(() => initial.source ?? (initial.reelId ? "reel" : initial.shopId ? "shop_profile" : initial.barberId ? "barber_profile" : "home_book_now"));

  const [barbers, setBarbers] = useState<BarberRow[]>([]);
  const [favorites, setFavorites] = useState<Set<string>>(new Set());
  const [selectedBarber, setSelectedBarber] = useState<BarberRow | null>(null);
  const [selectedShop, setSelectedShop] = useState<ShopRow | null>(null);

  const [services, setServices] = useState<ServiceRow[]>([]);
  const chosenService = useMemo(() => services.find((s) => String(s.id) === serviceId) ?? null, [services, serviceId]);

  const serviceDuration = Number(chosenService?.duration_minutes ?? 30);
  const servicePrice = Number(chosenService?.price_bhd ?? 0);
  const serviceName = (chosenService?.name_en ?? chosenService?.name_ar ?? "").trim() || "Service";
  const resolvedShopId = useMemo(
    () => safeStr(shopId) ?? safeStr(selectedBarber?.shop_id) ?? safeStr(chosenService?.shop_id) ?? null,
    [chosenService?.shop_id, selectedBarber?.shop_id, shopId]
  );

  const [offer, setOffer] = useState<OfferRow | null>(null);
  const discountAmount = useMemo(() => {
    if (!offerId || !offer?.active || offer?.is_active === false || (offer?.status && offer.status !== "approved")) return 0;
    const now = Date.now();
    const from = offer.valid_from ? new Date(offer.valid_from).getTime() : null;
    const to = offer.valid_to ? new Date(offer.valid_to).getTime() : null;
    if (from != null && now < from) return 0;
    if (to != null && now > to) return 0;
    if (offer.shop_id && resolvedShopId && offer.shop_id !== resolvedShopId) return 0;
    if (offer.barber_id && barberId && offer.barber_id !== barberId) return 0;
    if (offer.barber_id && !barberId) return 0;

    if ((offer.offer_type ?? "percentage") === "fixed") {
      return Math.max(0, Math.min(servicePrice, Math.round(Number(offer.discount_amount ?? 0) * 1000) / 1000));
    }

    const p = Number(offer.discount_percent ?? 0);
    if (!p || p <= 0) return 0;
    return Math.max(0, Math.min(servicePrice, Math.round(servicePrice * (p / 100) * 1000) / 1000));
  }, [barberId, offer?.active, offer?.barber_id, offer?.discount_amount, offer?.discount_percent, offer?.is_active, offer?.offer_type, offer?.shop_id, offer?.status, offer?.valid_from, offer?.valid_to, offerId, resolvedShopId, servicePrice]);

  const totalPrice = useMemo(() => Math.max(0, Math.round((servicePrice - discountAmount) * 1000) / 1000), [discountAmount, servicePrice]);

  const [calendarMonth, setCalendarMonth] = useState(() => new Date());
  const [availableDays, setAvailableDays] = useState<Set<string>>(new Set());
  const [calendarLoading, setCalendarLoading] = useState(false);
  const [selectedDate, setSelectedDate] = useState<Date | null>(null);

  const [timeLoading, setTimeLoading] = useState(false);
  const [availableTimes, setAvailableTimes] = useState<string[]>([]);
  const [selectedStartAt, setSelectedStartAt] = useState<string | null>(null);

  const [paymentMethod, setPaymentMethod] = useState<"cash" | "card" | "benefitpay" | "apple_pay" | "stc_pay">("cash");
  const [confirming, setConfirming] = useState(false);
  const [booking, setBooking] = useState<BookingRow | null>(null);
  const [error, setError] = useState<string | null>(null);

  const [holdId, setHoldId] = useState<string | null>(null);
  const [holdExpiresAt, setHoldExpiresAt] = useState<string | null>(null);
  const holdExpiryTimerRef = useRef<number | null>(null);

  const monthCells = useMemo(() => createMonthGrid(calendarMonth), [calendarMonth]);
  const monthKey = `${calendarMonth.getFullYear()}-${String(calendarMonth.getMonth() + 1).padStart(2, "0")}`;
  const timeGroups = useMemo(() => segmentedTimes(availableTimes), [availableTimes]);

  async function recoverActiveHold(params: { barberId: string; serviceId: string; startAt: string; shopId: string | null }) {
    let query = supabase
      .from("booking_slot_holds")
      .select("id, expires_at")
      .eq("barber_id", params.barberId)
      .eq("service_id", params.serviceId)
      .eq("start_at", params.startAt)
      .is("consumed_at", null)
      .gt("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false })
      .limit(1);

    query = params.shopId ? query.eq("shop_id", params.shopId) : query.is("shop_id", null);

    const { data } = await query.maybeSingle();
    const recoveredId = safeStr(data?.id);
    const recoveredExpiresAt = safeStr(data?.expires_at);
    if (!recoveredId || !recoveredExpiresAt) return null;
    return { holdId: recoveredId, expiresAt: recoveredExpiresAt };
  }

  async function releaseHold() {
    if (!holdId) return;
    try {
      await supabase.rpc("release_booking_slot", { hold_id: holdId });
    } catch {}
    setHoldId(null);
    setHoldExpiresAt(null);
  }

  function clearHoldExpiryTimer() {
    if (holdExpiryTimerRef.current != null) {
      window.clearInterval(holdExpiryTimerRef.current);
      holdExpiryTimerRef.current = null;
    }
  }

  function startHoldExpiryTimer(expiresAtIso: string) {
    clearHoldExpiryTimer();
    holdExpiryTimerRef.current = window.setInterval(() => {
      const left = new Date(expiresAtIso).getTime() - Date.now();
      if (left > 0) return;
      void releaseHold();
      setSelectedStartAt(null);
      setStep("time");
      setError("This reserved time expired. Please choose another time.");
    }, 1_000);
  }

  useEffect(() => {
    return () => clearHoldExpiryTimer();
  }, []);

  useEffect(() => {
    if (!barberId) return;
    void trackOnce(`booking_started:${barberId}:${shopId ?? "none"}`, {
      event_name: "booking_started",
      entity_type: "barber",
      entity_id: barberId,
      meta: { shop_id: shopId ?? null, initial_service_id: initial.serviceId ?? null, source, reel_id: reelId, offer_id: offerId }
    });
  }, [barberId, initial.serviceId, offerId, reelId, shopId, source]);

  useEffect(() => {
    if (!offerId) return;
    void (async () => {
      const { data } = await supabase
        .from("offers")
        .select("id, shop_id, barber_id, offer_type, discount_percent, discount_amount, active, is_active, status, valid_from, valid_to")
        .eq("id", offerId)
        .maybeSingle();
      setOffer((data as OfferRow | null) ?? null);
    })();
  }, [offerId, supabase]);

  useEffect(() => {
    void (async () => {
      if (barberId) {
        const { data } = await supabase
          .from("barbers")
          .select("id, display_name, shop_id, avatar_url, rating_avg, rating_count, area, available_now, is_verified, is_active, status, deleted_at, lat, lng, barbershops(id, name, area, lat, lng)")
          .eq("id", barberId)
          .maybeSingle();
        const b = (data as BarberRow | null) ?? null;
        setSelectedBarber(b);
        setShopId((b?.shop_id ?? shopId) ?? null);
      }
      if (shopId && !selectedShop) {
        const { data } = await supabase.from("barbershops").select("id, name, area, lat, lng, logo_url").eq("id", shopId).maybeSingle();
        setSelectedShop((data as ShopRow | null) ?? null);
      }
    })();
  }, [barberId, selectedShop, shopId, supabase]);

  const loadBarbers = useCallback(async () => {
    setError(null);
    const base = supabase
      .from("barbers")
      .select("id, display_name, shop_id, avatar_url, rating_avg, rating_count, area, available_now, is_verified, is_active, status, deleted_at, lat, lng, barbershops(id, name, area, lat, lng)")
      .is("deleted_at", null)
      .eq("is_active", true)
      .eq("status", "approved");

    const q = query.trim();
    const filtered =
      q.length >= 2
        ? base.or([`display_name.ilike.%${q}%`, `area.ilike.%${q}%`].join(","))
        : base;

    const scoped = shopId ? filtered.eq("shop_id", shopId) : filtered;
    const { data } = await scoped.limit(80);
    const list = (Array.isArray(data) ? (data as BarberRow[]) : []) ?? [];
    setBarbers(list);
  }, [query, setBarbers, setError, shopId, supabase]);

  const loadFavorites = useCallback(async () => {
    try {
      const { data } = await supabase.from("favorites").select("target_id").eq("target_type", "barber").limit(500);
      const s = new Set<string>();
      for (const r of (data as Array<{ target_id?: string | null }> | null) ?? []) {
        const id = safeStr(r.target_id);
        if (id) s.add(id);
      }
      setFavorites(s);
    } catch {}
  }, [supabase]);

  useEffect(() => {
    if (step !== "select") return;
    void loadBarbers();
    void loadFavorites();
  }, [loadBarbers, loadFavorites, shopId, step, tab, query]);

  const sortedBarbers = useMemo(() => {
    const list = [...barbers];
    if (tab === "top") {
      return list.sort((a, b) => Number(b.rating_avg ?? 0) - Number(a.rating_avg ?? 0));
    }
    if (tab === "following") {
      return list.filter((b) => favorites.has(b.id));
    }
    if (tab === "nearby" && pos) {
      return list
        .map((b) => {
          const shopRel = b.barbershops?.[0] ?? null;
          const lat = typeof b.lat === "number" ? b.lat : typeof shopRel?.lat === "number" ? shopRel.lat : null;
          const lng = typeof b.lng === "number" ? b.lng : typeof shopRel?.lng === "number" ? shopRel.lng : null;
          if (lat == null || lng == null) return { b, d: null as number | null };
          return { b, d: kmBetween(pos, { lat, lng }) };
        })
        .sort((a, b) => {
          if (a.d == null && b.d == null) return 0;
          if (a.d == null) return 1;
          if (b.d == null) return -1;
          return a.d - b.d;
        })
        .map((x) => x.b);
    }
    return list;
  }, [barbers, favorites, pos, tab]);

  const loadServices = useCallback(async (nextBarberId: string, nextShopId: string | null) => {
    setError(null);
    let query = supabase
      .from("barber_services_effective")
      .select("id, name_en, name_ar, price_bhd, duration_minutes, image_url, barber_ref, shop_id")
      .eq("barber_ref", nextBarberId)
      .order("created_at", { ascending: false })
      .limit(100);

    if (nextShopId) {
      query = query.eq("shop_id", nextShopId);
    }

    const { data, error } = await query;

    if (!error && (data?.length ?? 0) > 0) {
      setServices(((data ?? []) as ServiceRow[]) ?? []);
      return;
    }

    const byId = new Map<string, ServiceRow>();

    const { data: directBarber } = await supabase
      .from("services")
      .select("id, name_en, name_ar, price_bhd, duration_minutes, image_url, barber_id, shop_id")
      .eq("barber_id", nextBarberId)
      .or("status.eq.approved,status.is.null")
      .or("is_active.eq.true,active.eq.true")
      .is("deleted_at", null)
      .limit(100);

    for (const row of ((directBarber ?? []) as Array<ServiceRow & { barber_id?: string | null }>)) {
      byId.set(String(row.id), row);
    }

    if (nextShopId) {
      const { data: shopShared } = await supabase
        .from("services")
        .select("id, name_en, name_ar, price_bhd, duration_minutes, image_url, barber_id, shop_id")
        .eq("shop_id", nextShopId)
        .is("barber_id", null)
        .or("status.eq.approved,status.is.null")
        .or("is_active.eq.true,active.eq.true")
        .is("deleted_at", null)
        .limit(100);

      for (const row of ((shopShared ?? []) as Array<ServiceRow & { barber_id?: string | null }>)) {
        byId.set(String(row.id), row);
      }
    }

    const fallback = Array.from(byId.values()).sort((a, b) => Number(a.price_bhd ?? 0) - Number(b.price_bhd ?? 0));
    setServices(fallback);
    if (!fallback.length) setError("Could not load services.");
  }, [supabase]);

  const loadAvailableDays = useCallback(async (month: Date) => {
    if (!barberId || !chosenService?.id) return;
    setCalendarLoading(true);
    setError(null);
    const results = new Set<string>();
    const y = month.getFullYear();
    const m = month.getMonth();
    const monthIso = `${y}-${String(m + 1).padStart(2, "0")}-01`;
    const { data, error } = await supabase.rpc("get_available_days", {
      barber: barberId,
      month: monthIso,
      duration_minutes: serviceDuration,
      slot_minutes: 30
    });
    if (error) {
      setAvailableDays(results);
      setCalendarLoading(false);
      setError(userFacingBookingError(error.message));
      return;
    }
    const rows = (Array.isArray(data) ? data : []) as Array<{ day?: string; has_slots?: boolean }>;
    for (const r of rows) {
      const day0 = safeStr(r.day);
      if (!day0) continue;
      if (r.has_slots) results.add(day0);
    }
    setAvailableDays(results);
    setCalendarLoading(false);
  }, [barberId, chosenService?.id, serviceDuration, supabase]);

  const loadTimes = useCallback(async (day: Date) => {
    if (!barberId || !chosenService?.id) return;
    setTimeLoading(true);
    setError(null);
    const { data, error } = await supabase.rpc("get_available_times", {
      barber: barberId,
      day: isoDate(day),
      duration_minutes: serviceDuration
    });
    if (error) {
      setTimeLoading(false);
      setAvailableTimes([]);
      setSelectedStartAt(null);
      setError(userFacingBookingError(error.message));
      return;
    }
    const rows = (Array.isArray(data) ? data : []) as Array<{ start_at?: string } | string>;
    const list = rows
      .map((r) => (typeof r === "string" ? r : safeStr(r.start_at)))
      .filter((v): v is string => Boolean(v));
    setAvailableTimes(list);
    setSelectedStartAt(null);
    setTimeLoading(false);
  }, [barberId, chosenService?.id, serviceDuration, supabase]);

  useEffect(() => {
    if (!barberId) return;
    if (services.length) return;
    void loadServices(barberId, shopId);
  }, [barberId, loadServices, services.length, shopId]);

  useEffect(() => {
    if (step !== "date") return;
    if (!barberId || !chosenService?.id) return;
    void loadAvailableDays(calendarMonth);
  }, [barberId, calendarMonth, chosenService?.id, loadAvailableDays, step]);

  async function reserveAndContinue() {
    if (!barberId || !chosenService?.id || !selectedStartAt) return;
    setConfirming(true);
    setError(null);
    await releaseHold();
    const holdParams = {
      barberId,
      serviceId: chosenService.id,
      startAt: selectedStartAt,
      shopId: resolvedShopId
    };
    const { data, error } = await supabase.rpc("hold_booking_slot", {
      service_id: chosenService.id,
      start_at: selectedStartAt,
      barber_id: barberId,
      shop_id: resolvedShopId,
      hold_minutes: 5
    });
    if (error) {
      const recovered = await recoverActiveHold(holdParams);
      if (recovered) {
        setHoldId(recovered.holdId);
        setHoldExpiresAt(recovered.expiresAt);
        startHoldExpiryTimer(recovered.expiresAt);
        setConfirming(false);
        setStep("review");
        return;
      }
      setConfirming(false);
      setError(userFacingBookingError(error.message));
      return;
    }

    const row = (Array.isArray(data) ? data[0] : data) as HoldRow | null;
    const hId = safeStr(row?.hold_id);
    const exp = safeStr(row?.expires_at);
    if (!hId || !exp) {
      const recovered = await recoverActiveHold(holdParams);
      if (recovered) {
        setHoldId(recovered.holdId);
        setHoldExpiresAt(recovered.expiresAt);
        startHoldExpiryTimer(recovered.expiresAt);
        setConfirming(false);
        setStep("review");
        return;
      }
      setConfirming(false);
      setError("Failed to reserve the time. Please try again.");
      return;
    }
    setHoldId(hId);
    setHoldExpiresAt(exp);
    startHoldExpiryTimer(exp);
    setConfirming(false);
    setStep("review");
  }

  async function confirmBooking() {
    if (!barberId || !chosenService?.id || !selectedStartAt || !holdId) return;
    setConfirming(true);
    setError(null);
    const args: Record<string, unknown> = {
      service_id: chosenService.id,
      start_at: selectedStartAt,
      barber_id: barberId,
      payment_method: paymentMethod,
      source,
      discount_amount: discountAmount
    };
    if (resolvedShopId) args.shop_id = resolvedShopId;
    if (sourcePostId) args.source_post_id = sourcePostId;
    if (reelId) args.reel_id = reelId;
    if (offerId) args.offer_id = offerId;

    let data: unknown = null;
    let error: { message?: string } | null = null;

    {
      const r1 = await supabase.rpc("create_booking_safely", { ...args, hold_id: holdId });
      data = r1.data;
      error = r1.error as { message?: string } | null;
    }

    if (error?.message?.toLowerCase().includes("could not find the function public.create_booking_safely")) {
      const r2 = await supabase.rpc("create_booking_safely", args);
      data = r2.data;
      error = r2.error as { message?: string } | null;
    }
    if (error) {
      setConfirming(false);
      setError(userFacingBookingError(error.message ?? "Failed to create booking."));
      return;
    }
    const result = (data ?? null) as { ok?: boolean; booking?: BookingRow | null; error?: string | null } | null;
    if (!result?.ok || !result.booking) {
      setConfirming(false);
      setError(userFacingBookingError(result?.error ?? "Failed to create booking."));
      return;
    }
    setBooking(result.booking);
    await releaseHold();
    clearHoldExpiryTimer();
    setConfirming(false);
    setStep("confirmed");
  }

  async function toggleFavorite(id: string) {
    const next = new Set(favorites);
    const has = next.has(id);
    setFavorites(next);
    try {
      if (has) {
        next.delete(id);
        await supabase.from("favorites").delete().eq("target_type", "barber").eq("target_id", id);
        setFavorites(new Set(next));
      } else {
        next.add(id);
        await supabase.from("favorites").insert({ target_type: "barber", target_id: id });
        setFavorites(new Set(next));
      }
    } catch {}
  }

  const holdLabel = holdExpiresAt
    ? (() => {
        const s = Math.max(0, Math.round((new Date(holdExpiresAt).getTime() - Date.now()) / 1000));
        const mm = Math.floor(s / 60);
        const ss = String(s % 60).padStart(2, "0");
        return `${mm}:${ss}`;
      })()
    : null;

  const headerTitle =
    step === "select"
      ? shopId
        ? "Select Barber"
        : "Select Barber / Shop"
      : step === "service"
        ? "Choose Service"
        : step === "date"
          ? "Select Date"
          : step === "time"
            ? "Select Time"
            : step === "review"
              ? "Review Booking"
              : step === "payment"
                ? "Payment Method"
                : "Booking Confirmed";

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col bg-black pb-24 text-white">
      <div className="sticky top-0 z-40 border-b border-[#2A2A2A] bg-black/80 backdrop-blur">
        <div className="flex items-center gap-3 px-4 py-4">
          <Link href={backHref} className="flex h-10 w-10 items-center justify-center rounded-[14px] border border-[#2A2A2A] bg-[#111111]">
            <ArrowLeft className="h-4 w-4 text-white" />
          </Link>
          <div className="flex min-w-0 flex-1 flex-col">
            <div className="truncate text-sm font-extrabold text-white">{headerTitle}</div>
            {selectedBarber?.display_name ? (
              <div className="truncate pt-1 text-[12px] font-semibold text-[#9E9E9E]">{selectedBarber.display_name}</div>
            ) : selectedShop?.name ? (
              <div className="truncate pt-1 text-[12px] font-semibold text-[#9E9E9E]">{selectedShop.name}</div>
            ) : null}
          </div>
          {holdLabel && step !== "select" && step !== "service" && step !== "date" && step !== "time" ? (
            <div className="rounded-full border border-[#2A2A2A] bg-[#111111] px-3 py-2 text-[12px] font-extrabold text-[hsl(var(--gold))]">{holdLabel}</div>
          ) : null}
        </div>
      </div>

      {error ? (
        <div className="mx-4 mt-4 rounded-[18px] border border-rose-500/25 bg-rose-500/10 px-4 py-3 text-sm font-semibold text-rose-200">
          {error}
        </div>
      ) : null}

      <div className="flex flex-1 flex-col gap-4 px-4 py-4">
        {step === "select" ? (
          <>
            <div className="flex items-center gap-2 rounded-[18px] border border-[#2A2A2A] bg-[#111111] px-4 py-3">
              <Search className="h-4 w-4 text-[#9E9E9E]" />
              <input
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder={shopId ? "Search barbers" : "Search barbers"}
                className="w-full bg-transparent text-sm font-semibold text-white placeholder:text-[#6E6E6E] outline-none"
              />
            </div>

            <div className="flex gap-2">
              <button
                type="button"
                className={cn(
                  "rounded-full border px-4 py-2 text-[12px] font-extrabold",
                  tab === "nearby" ? "border-[hsl(var(--gold))]/55 bg-[#111111] text-[hsl(var(--gold))]" : "border-[#2A2A2A] bg-[#111111] text-[#9E9E9E]"
                )}
                onClick={() => setTab("nearby")}
              >
                Nearby
              </button>
              <button
                type="button"
                className={cn(
                  "rounded-full border px-4 py-2 text-[12px] font-extrabold",
                  tab === "top" ? "border-[hsl(var(--gold))]/55 bg-[#111111] text-[hsl(var(--gold))]" : "border-[#2A2A2A] bg-[#111111] text-[#9E9E9E]"
                )}
                onClick={() => setTab("top")}
              >
                Top Rated
              </button>
              <button
                type="button"
                className={cn(
                  "rounded-full border px-4 py-2 text-[12px] font-extrabold",
                  tab === "following" ? "border-[hsl(var(--gold))]/55 bg-[#111111] text-[hsl(var(--gold))]" : "border-[#2A2A2A] bg-[#111111] text-[#9E9E9E]"
                )}
                onClick={() => setTab("following")}
              >
                Following
              </button>
            </div>

            <div className="flex flex-col gap-3">
              {sortedBarbers.map((b) => {
                const shopRel = b.barbershops?.[0] ?? null;
                const shopName = shopRel?.name ?? null;
                const area = b.area ?? shopRel?.area ?? null;
                const rating = typeof b.rating_avg === "number" ? b.rating_avg : null;
                const count = typeof b.rating_count === "number" ? b.rating_count : null;
                const lat = typeof b.lat === "number" ? b.lat : typeof shopRel?.lat === "number" ? shopRel.lat : null;
                const lng = typeof b.lng === "number" ? b.lng : typeof shopRel?.lng === "number" ? shopRel.lng : null;
                const distanceKm = pos && lat != null && lng != null ? kmBetween(pos, { lat, lng }) : null;
                const distanceLabel = distanceKm == null ? null : `${distanceKm.toFixed(distanceKm < 1 ? 1 : 0)} km`;
                const fav = favorites.has(b.id);
                const available = Boolean(b.available_now);
                const verified = Boolean(b.is_verified);
                return (
                  <div key={b.id} className="overflow-hidden rounded-[24px] border border-[#2A2A2A] bg-[#111111] shadow-[0_18px_44px_rgba(0,0,0,0.55)]">
                    <div className="flex items-center gap-3 p-4">
                      <div className="h-16 w-16 overflow-hidden rounded-[22px] border border-[#2A2A2A] bg-black">
                        <SafeImage src={b.avatar_url ?? null} fallbackKey="default_barber_avatar" alt={b.display_name ?? "Barber"} className="h-full w-full object-cover" />
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-2">
                          <div className="truncate text-sm font-extrabold text-white">{b.display_name ?? "Barber"}</div>
                          {verified ? <BadgeCheck className="h-4 w-4 text-[hsl(var(--gold))]" /> : null}
                        </div>
                        {shopName ? <div className="truncate pt-1 text-[12px] font-semibold text-[#9E9E9E]">{shopName}</div> : null}
                        <div className="pt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-[12px] font-semibold text-[#9E9E9E]">
                          {area ? (
                            <span className="inline-flex items-center gap-1">
                              <MapPin className="h-3.5 w-3.5" />
                              {area}
                            </span>
                          ) : null}
                          {rating != null ? (
                            <span className="inline-flex items-center gap-1 text-[hsl(var(--gold))]">
                              <Star className="h-3.5 w-3.5" />
                              {rating.toFixed(1)}
                              {count != null ? <span className="text-[#9E9E9E]">({count})</span> : null}
                            </span>
                          ) : null}
                          {distanceLabel ? <span>{distanceLabel}</span> : null}
                          <span className={available ? "text-emerald-400" : "text-[#6E6E6E]"}>{available ? "Available" : "Offline"}</span>
                        </div>
                      </div>
                      <button
                        type="button"
                        onClick={() => void toggleFavorite(b.id)}
                        className={cn(
                          "flex h-10 w-10 items-center justify-center rounded-[14px] border",
                          fav ? "border-[hsl(var(--gold))]/55 bg-[hsl(var(--gold))]/10" : "border-[#2A2A2A] bg-black/20"
                        )}
                      >
                        <Heart className={cn("h-4 w-4", fav ? "fill-[hsl(var(--gold))] text-[hsl(var(--gold))]" : "text-[#9E9E9E]")} />
                      </button>
                    </div>
                    <div className="flex gap-3 border-t border-[#2A2A2A] p-4">
                      <Button
                        className="h-12 w-full rounded-[16px] bg-[hsl(var(--gold))] text-black shadow-[0_18px_42px_rgba(212,175,55,0.28)] hover:bg-[hsl(var(--gold))]"
                        onClick={() => {
                          setSelectedBarber(b);
                          setSelectedShop(
                            shopRel?.id
                              ? { id: shopRel.id, name: shopRel.name, area: shopRel.area, lat: shopRel.lat, lng: shopRel.lng, logo_url: null }
                              : null
                          );
                          setBarberId(b.id);
                          setShopId(b.shop_id ?? null);
                          setServiceId(initial.serviceId);
                          void loadServices(b.id, b.shop_id ?? null);
                          setStep("service");
                        }}
                      >
                        Book
                      </Button>
                    </div>
                  </div>
                );
              })}
            </div>
          </>
        ) : null}

        {step === "service" ? (
          <>
            {services.length ? (
              <div className="flex flex-col gap-3">
                {services.map((s) => {
                  const id = String(s.id);
                  const selected = id === serviceId;
                  const name = (s.name_en ?? s.name_ar ?? "").trim() || "Service";
                  const duration = Number(s.duration_minutes ?? 30);
                  const price = Number(s.price_bhd ?? 0);
                  return (
                    <button
                      type="button"
                      key={id}
                      className={cn(
                        "flex w-full items-center gap-3 rounded-[24px] border bg-[#111111] p-4 text-left shadow-[0_18px_44px_rgba(0,0,0,0.55)]",
                        selected ? "border-[hsl(var(--gold))]/65" : "border-[#2A2A2A]"
                      )}
                      onClick={async () => {
                        await releaseHold();
                        setServiceId(id);
                        setSelectedDate(null);
                        setAvailableDays(new Set());
                        setSelectedStartAt(null);
                        setAvailableTimes([]);
                      }}
                    >
                      <div className="h-14 w-14 overflow-hidden rounded-[20px] border border-[#2A2A2A] bg-black">
                        <SafeImage src={s.image_url ?? null} fallbackKey="default_service_image" alt={name} className="h-full w-full object-cover" />
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="truncate text-sm font-extrabold text-white">{name}</div>
                        <div className="pt-2 text-[12px] font-semibold text-[#9E9E9E]">
                          {duration} min • {formatBhd(price)}
                        </div>
                      </div>
                      <div
                        className={cn(
                          "flex h-7 w-7 items-center justify-center rounded-full border",
                          selected ? "border-[hsl(var(--gold))] bg-[hsl(var(--gold))] text-black" : "border-[#2A2A2A] bg-black/30 text-transparent"
                        )}
                      >
                        <Check className="h-4 w-4" />
                      </div>
                    </button>
                  );
                })}
              </div>
            ) : (
              <LuxuryCard className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-6">
                <div className="text-sm font-extrabold text-white">No services available</div>
                <div className="pt-1 text-sm font-semibold text-[#9E9E9E]">Try another barber.</div>
                <div className="pt-4">
                  <Button variant="secondary" className="h-12 w-full rounded-[16px] border border-[#2A2A2A] bg-black/20 text-white" onClick={() => setStep("select")}>
                    Back
                  </Button>
                </div>
              </LuxuryCard>
            )}
          </>
        ) : null}

        {step === "date" ? (
          <LuxuryCard className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-4">
            <div className="flex items-center justify-between">
              <button
                type="button"
                className="rounded-[14px] border border-[#2A2A2A] bg-black/20 px-3 py-2 text-[12px] font-extrabold text-white"
                onClick={() => setCalendarMonth(new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() - 1, 1))}
              >
                Prev
              </button>
              <div className="text-sm font-extrabold text-white">{monthLabel(calendarMonth)}</div>
              <button
                type="button"
                className="rounded-[14px] border border-[#2A2A2A] bg-black/20 px-3 py-2 text-[12px] font-extrabold text-white"
                onClick={() => setCalendarMonth(new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() + 1, 1))}
              >
                Next
              </button>
            </div>
            <div className="mt-4 grid grid-cols-7 gap-2 text-center text-[11px] font-extrabold text-[#9E9E9E]">
              {["S", "M", "T", "W", "T", "F", "S"].map((d) => (
                <div key={d}>{d}</div>
              ))}
            </div>
            <div className="mt-3 grid grid-cols-7 gap-2">
              {monthCells.map((d, idx) => {
                const inMonth = d.getMonth() === calendarMonth.getMonth();
                const key = isoDate(d);
                const isAvailable = availableDays.has(key);
                const isPast = d.getTime() < new Date().setHours(0, 0, 0, 0);
                const selected = selectedDate ? isoDate(selectedDate) === key : false;
                const disabled = !inMonth || isPast || !isAvailable;
                return (
                  <button
                    type="button"
                    key={`${monthKey}-${idx}`}
                    disabled={calendarLoading || disabled}
                    className={cn(
                      "flex h-10 w-10 items-center justify-center rounded-[18px] text-sm font-extrabold transition-colors",
                      selected ? "bg-[hsl(var(--gold))] text-black" : "bg-black/20 text-white",
                      disabled ? "opacity-40" : "hover:bg-[hsl(var(--gold))]/15"
                    )}
                    onClick={async () => {
                      await releaseHold();
                      setSelectedDate(d);
                      setSelectedStartAt(null);
                      setAvailableTimes([]);
                      await loadTimes(d);
                    }}
                  >
                    {d.getDate()}
                  </button>
                );
              })}
            </div>
            {calendarLoading ? <div className="pt-4 text-sm font-semibold text-[#9E9E9E]">Loading...</div> : null}
          </LuxuryCard>
        ) : null}

        {step === "time" ? (
          <LuxuryCard className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-4">
            {timeLoading ? (
              <div className="text-sm font-semibold text-[#9E9E9E]">Loading available times...</div>
            ) : availableTimes.length ? (
              <div className="flex flex-col gap-5">
                {([
                  ["Morning", timeGroups.morning],
                  ["Afternoon", timeGroups.afternoon],
                  ["Evening", timeGroups.evening]
                ] as const).map(([label, items]) =>
                  items.length ? (
                    <div key={label}>
                      <div className="text-[12px] font-extrabold text-[#9E9E9E]">{label}</div>
                      <div className="mt-2 grid grid-cols-3 gap-2">
                        {items.map((t) => {
                          const selected = t === selectedStartAt;
                          return (
                            <button
                              key={t}
                              type="button"
                              className={cn(
                                "flex items-center justify-center rounded-[16px] border px-3 py-3 text-[12px] font-extrabold",
                                selected ? "border-[hsl(var(--gold))] bg-[hsl(var(--gold))] text-black" : "border-[#2A2A2A] bg-black/20 text-white"
                              )}
                              onClick={() => setSelectedStartAt(t)}
                            >
                              {formatTimeBahrain(t)}
                            </button>
                          );
                        })}
                      </div>
                    </div>
                  ) : null
                )}
              </div>
            ) : (
              <div className="text-sm font-semibold text-[#9E9E9E]">No available times for this date.</div>
            )}
          </LuxuryCard>
        ) : null}

        {step === "review" ? (
          <LuxuryCard className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-5">
            <div className="flex items-center gap-3">
              <div className="h-12 w-12 overflow-hidden rounded-[18px] border border-[#2A2A2A] bg-black">
                <SafeImage src={selectedBarber?.avatar_url ?? null} fallbackKey="default_barber_avatar" alt={selectedBarber?.display_name ?? "Barber"} className="h-full w-full object-cover" />
              </div>
              <div className="min-w-0 flex-1">
                <div className="truncate text-sm font-extrabold text-white">{selectedBarber?.display_name ?? "Barber"}</div>
                {selectedShop?.name ? <div className="truncate pt-1 text-[12px] font-semibold text-[#9E9E9E]">{selectedShop.name}</div> : null}
              </div>
            </div>
            <div className="pt-4 grid gap-3 text-sm">
              <div className="flex items-center justify-between gap-3">
                <div className="text-[#9E9E9E]">Service</div>
                <div className="font-extrabold text-white">{serviceName}</div>
              </div>
              <div className="flex items-center justify-between gap-3">
                <div className="text-[#9E9E9E]">Date</div>
                <div className="font-extrabold text-white">{selectedDate ? formatDateBahrain(selectedDate) : "-"}</div>
              </div>
              <div className="flex items-center justify-between gap-3">
                <div className="text-[#9E9E9E]">Time</div>
                <div className="font-extrabold text-white">{selectedStartAt ? formatTimeBahrain(selectedStartAt) : "-"}</div>
              </div>
              <div className="flex items-center justify-between gap-3">
                <div className="text-[#9E9E9E]">Price</div>
                <div className="font-extrabold text-white">{formatBhd(servicePrice)}</div>
              </div>
              {discountAmount > 0 ? (
                <div className="flex items-center justify-between gap-3">
                  <div className="text-[#9E9E9E]">Discount</div>
                  <div className="font-extrabold text-emerald-400">- {formatBhd(discountAmount)}</div>
                </div>
              ) : null}
              <div className="flex items-center justify-between gap-3 pt-2">
                <div className="text-[#9E9E9E]">Total</div>
                <div className="text-base font-extrabold text-[hsl(var(--gold))]">{formatBhd(totalPrice)}</div>
              </div>
            </div>
          </LuxuryCard>
        ) : null}

        {step === "payment" ? (
          <LuxuryCard className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-5">
            <div className="flex flex-col gap-3">
              {(
                [
                  { id: "cash", label: "Cash at Shop", icon: Wallet, active: true },
                  { id: "card", label: "Card", icon: CreditCard, active: false },
                  { id: "benefitpay", label: "BenefitPay", icon: CreditCard, active: false },
                  { id: "apple_pay", label: "Apple Pay", icon: CreditCard, active: false },
                  { id: "stc_pay", label: "STC Pay", icon: CreditCard, active: false }
                ] as const
              ).map((m) => {
                const checked = paymentMethod === m.id;
                const disabled = !m.active;
                const Icon = m.icon;
                return (
                  <button
                    key={m.id}
                    type="button"
                    disabled={disabled}
                    onClick={() => setPaymentMethod(m.id)}
                    className={cn(
                      "flex w-full items-center justify-between rounded-[20px] border px-4 py-4 text-left",
                      checked ? "border-[hsl(var(--gold))]/65 bg-[hsl(var(--gold))]/10" : "border-[#2A2A2A] bg-black/20",
                      disabled ? "opacity-50" : ""
                    )}
                  >
                    <div className="flex items-center gap-3">
                      <div className="flex h-10 w-10 items-center justify-center rounded-[16px] border border-[#2A2A2A] bg-black/20">
                        <Icon className="h-4 w-4 text-[hsl(var(--gold))]" />
                      </div>
                      <div className="flex flex-col">
                        <div className="text-sm font-extrabold text-white">{m.label}</div>
                        {!m.active ? <div className="pt-1 text-[12px] font-semibold text-[#9E9E9E]">Coming soon</div> : null}
                      </div>
                    </div>
                    <div className={cn("flex h-6 w-6 items-center justify-center rounded-full border", checked ? "border-[hsl(var(--gold))] bg-[hsl(var(--gold))]" : "border-[#2A2A2A] bg-black/20")}>
                      <Check className={cn("h-4 w-4", checked ? "text-black" : "text-transparent")} />
                    </div>
                  </button>
                );
              })}
            </div>
            <div className="pt-4 flex items-center justify-between text-sm">
              <div className="text-[#9E9E9E]">Total</div>
              <div className="text-base font-extrabold text-[hsl(var(--gold))]">{formatBhd(totalPrice)}</div>
            </div>
          </LuxuryCard>
        ) : null}

        {step === "confirmed" && booking ? (
          <div className="flex flex-1 flex-col items-center justify-center gap-6 py-10">
            <div className="flex h-20 w-20 items-center justify-center rounded-full border border-[hsl(var(--gold))]/45 bg-[hsl(var(--gold))]/10">
              <Check className="h-10 w-10 text-[hsl(var(--gold))]" />
            </div>
            <div className="text-center">
              <div className="text-xl font-extrabold text-white">Booking Confirmed!</div>
              <div className="pt-2 text-sm font-semibold text-[#9E9E9E]">Your appointment is confirmed.</div>
            </div>
            <LuxuryCard className="w-full rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-5">
              <div className="flex items-center justify-between gap-3">
                <div className="text-[12px] font-extrabold text-[#9E9E9E]">Booking ID</div>
                <div className="text-[12px] font-extrabold text-white">{booking.id}</div>
              </div>
              <div className="pt-4 grid gap-3 text-sm">
                <div className="flex items-center justify-between gap-3">
                  <div className="text-[#9E9E9E]">Service</div>
                  <div className="font-extrabold text-white">{serviceName}</div>
                </div>
                <div className="flex items-center justify-between gap-3">
                  <div className="text-[#9E9E9E]">Date</div>
                  <div className="font-extrabold text-white">{formatDateBahrain(new Date(booking.start_at))}</div>
                </div>
                <div className="flex items-center justify-between gap-3">
                  <div className="text-[#9E9E9E]">Time</div>
                  <div className="font-extrabold text-white">{formatTimeBahrain(booking.start_at)}</div>
                </div>
                <div className="flex items-center justify-between gap-3 pt-2">
                  <div className="text-[#9E9E9E]">Total</div>
                  <div className="text-base font-extrabold text-[hsl(var(--gold))]">{formatBhd(booking.total_price ?? totalPrice)}</div>
                </div>
              </div>
            </LuxuryCard>
            <div className="grid w-full gap-3">
              <Link
                href="/bookings"
                className="inline-flex h-12 w-full items-center justify-center rounded-[16px] bg-[hsl(var(--gold))] px-5 text-sm font-extrabold text-black shadow-[0_18px_42px_rgba(212,175,55,0.28)]"
              >
                View My Bookings
              </Link>
              <Link
                href={`/bookings/${encodeURIComponent(booking.id)}`}
                className="inline-flex h-12 w-full items-center justify-center rounded-[16px] border border-[#2A2A2A] bg-[#111111] px-5 text-sm font-extrabold text-white"
              >
                View Booking Details
              </Link>
            </div>
          </div>
        ) : null}
      </div>

      {step !== "confirmed" ? (
        <div className="fixed bottom-0 left-0 right-0 z-40 border-t border-[#2A2A2A] bg-black/80 p-4 backdrop-blur">
          <div className="mx-auto max-w-md">
            {step === "service" ? (
              <Button
                className="h-12 w-full rounded-[16px] bg-[hsl(var(--gold))] text-black shadow-[0_18px_42px_rgba(212,175,55,0.28)] hover:bg-[hsl(var(--gold))]"
                disabled={!barberId || !serviceId}
                onClick={async () => {
                  if (!barberId || !chosenService?.id) return;
                  await loadAvailableDays(calendarMonth);
                  setStep("date");
                }}
              >
                Continue
              </Button>
            ) : step === "date" ? (
              <Button
                className="h-12 w-full rounded-[16px] bg-[hsl(var(--gold))] text-black shadow-[0_18px_42px_rgba(212,175,55,0.28)] hover:bg-[hsl(var(--gold))]"
                disabled={!selectedDate || calendarLoading}
                onClick={() => setStep("time")}
              >
                Continue
              </Button>
            ) : step === "time" ? (
              <Button
                className="h-12 w-full rounded-[16px] bg-[hsl(var(--gold))] text-black shadow-[0_18px_42px_rgba(212,175,55,0.28)] hover:bg-[hsl(var(--gold))]"
                disabled={!selectedStartAt || timeLoading || confirming}
                onClick={() => void reserveAndContinue()}
              >
                Continue
              </Button>
            ) : step === "review" ? (
              <Button className="h-12 w-full rounded-[16px] bg-[hsl(var(--gold))] text-black shadow-[0_18px_42px_rgba(212,175,55,0.28)] hover:bg-[hsl(var(--gold))]" disabled={!holdId} onClick={() => setStep("payment")}>
                Continue to Payment
              </Button>
            ) : step === "payment" ? (
              <Button className="h-12 w-full rounded-[16px] bg-[hsl(var(--gold))] text-black shadow-[0_18px_42px_rgba(212,175,55,0.28)] hover:bg-[hsl(var(--gold))]" disabled={confirming || paymentMethod !== "cash"} onClick={() => void confirmBooking()}>
                {confirming ? "Confirming..." : "Confirm Booking"}
              </Button>
            ) : (
              <Button className="h-12 w-full rounded-[16px] bg-[hsl(var(--gold))] text-black shadow-[0_18px_42px_rgba(212,175,55,0.28)] hover:bg-[hsl(var(--gold))]" onClick={() => void loadBarbers()}>
                Refresh
              </Button>
            )}
          </div>
        </div>
      ) : null}
    </main>
  );
}

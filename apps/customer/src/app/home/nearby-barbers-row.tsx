"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";

import { SafeImage } from "@/components/safe-image";

type Barber = {
  id: string;
  display_name?: string | null;
  shop_id?: string | null;
  avatar_url?: string | null;
  avatar_path?: string | null;
  lat?: number | null;
  lng?: number | null;
  rating_avg?: number | null;
  rating_count?: number | null;
};

type ShopCoord = {
  id: string;
  lat?: number | null;
  lng?: number | null;
};

type BarberWithDistance = Barber & { _distanceKm?: number | null };

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

export function NearbyBarbersRow({ barbers, shops }: { barbers: Barber[]; shops: ShopCoord[] }) {
  const [pos, setPos] = useState<{ lat: number; lng: number } | null>(null);

  useEffect(() => {
    if (typeof navigator === "undefined" || !navigator.geolocation) return;
    navigator.geolocation.getCurrentPosition(
      (p) => setPos({ lat: p.coords.latitude, lng: p.coords.longitude }),
      () => {},
      { enableHighAccuracy: true, maximumAge: 60_000, timeout: 6_000 }
    );
  }, []);

  const shopCoords = useMemo(() => {
    const m = new Map<string, { lat: number; lng: number }>();
    for (const s of shops) {
      const lat = typeof s.lat === "number" ? s.lat : null;
      const lng = typeof s.lng === "number" ? s.lng : null;
      if (lat == null || lng == null) continue;
      m.set(s.id, { lat, lng });
    }
    return m;
  }, [shops]);

  const items = useMemo(() => {
    const base = barbers.filter((b) => b.id);
    if (!pos) return base;
    const withD = base
      .map((b) => {
        const fromShop = b.shop_id ? shopCoords.get(b.shop_id) ?? null : null;
        const lat = fromShop ? fromShop.lat : typeof b.lat === "number" ? b.lat : null;
        const lng = fromShop ? fromShop.lng : typeof b.lng === "number" ? b.lng : null;
        if (lat == null || lng == null) return { barber: b, d: null as number | null };
        return { barber: b, d: kmBetween(pos, { lat, lng }) };
      })
      .sort((a, b) => {
        if (a.d == null && b.d == null) return 0;
        if (a.d == null) return 1;
        if (b.d == null) return -1;
        return a.d - b.d;
      });
    return withD.map((x): BarberWithDistance => ({ ...x.barber, _distanceKm: x.d }));
  }, [barbers, pos, shopCoords]);

  return (
    <div className="flex gap-3 overflow-x-auto pb-1">
      {items.slice(0, 12).map((b) => {
        const d = (b as BarberWithDistance)._distanceKm;
        const rating = typeof b.rating_avg === "number" ? b.rating_avg : null;
        const count = typeof b.rating_count === "number" ? b.rating_count : null;
        const distanceLabel = d == null ? null : `${d.toFixed(d < 1 ? 1 : 0)} km remaining`;
        return (
          <Link key={b.id} href={`/barber/${encodeURIComponent(b.id)}`} className="block w-[150px] shrink-0">
            <div className="overflow-hidden rounded-[24px] border border-[#2A2A2A] bg-[#111111] shadow-[0_18px_44px_rgba(0,0,0,0.55)]">
              <div className="relative h-[118px] w-full overflow-hidden">
                <SafeImage
                  src={b.avatar_url ?? null}
                  fallbackKey="default_barber_avatar"
                  alt={b.display_name ?? "Barber"}
                  className="h-full w-full object-cover"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/10 to-transparent" />
              </div>
              <div className="p-3">
                <div className="truncate text-sm font-bold text-white">{b.display_name ?? "Barber"}</div>
                {rating != null ? (
                  <div className="mt-2 flex items-center gap-2 text-[12px] text-[#9E9E9E]">
                    <span className="font-semibold text-[hsl(var(--gold))]">{`★ ${rating.toFixed(1)}`}</span>
                    {count != null ? <span>({count})</span> : null}
                  </div>
                ) : null}
                {distanceLabel ? <div className="mt-1 text-[12px] font-semibold text-[#9E9E9E]">{distanceLabel}</div> : null}
              </div>
            </div>
          </Link>
        );
      })}
    </div>
  );
}


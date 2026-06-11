"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import { Heart } from "lucide-react";

import { SafeImage } from "@/components/safe-image";
import { cn } from "@hallaq/ui/cn";
import { createSupabaseBrowserClient } from "@hallaq/supabase/browser";

type Shop = {
  id: string;
  name?: string | null;
  area?: string | null;
  rating_avg?: number | null;
  rating_count?: number | null;
  badge_verified?: boolean | null;
  cover_url?: string | null;
  cover_path?: string | null;
  lat?: number | null;
  lng?: number | null;
};

type ShopWithDistance = Shop & { _distanceKm?: number | null };

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

export function NearbyShopsRow({ shops }: { shops: Shop[] }) {
  const router = useRouter();
  const [pos, setPos] = useState<{ lat: number; lng: number } | null>(null);
  const [fav, setFav] = useState<Set<string>>(() => new Set());

  useEffect(() => {
    if (typeof navigator === "undefined" || !navigator.geolocation) return;
    navigator.geolocation.getCurrentPosition(
      (p) => setPos({ lat: p.coords.latitude, lng: p.coords.longitude }),
      () => {},
      { enableHighAccuracy: true, maximumAge: 60_000, timeout: 6_000 }
    );
  }, []);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      try {
        const supabase = createSupabaseBrowserClient();
        const {
          data: { user }
        } = await supabase.auth.getUser();
        if (!user) return;
        const ids = shops.map((s) => s.id).filter(Boolean);
        if (!ids.length) return;
        const { data } = await supabase
          .from("favorites")
          .select("target_id")
          .eq("profile_id", user.id)
          .eq("target_type", "shop")
          .in("target_id", ids)
          .limit(200);
        if (cancelled) return;
        const next = new Set<string>();
        for (const r of data ?? []) {
          const id = (r as { target_id: string }).target_id;
          if (id) next.add(id);
        }
        setFav(next);
      } catch {}
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [shops]);

  async function toggleFavorite(shopId: string) {
    try {
      const supabase = createSupabaseBrowserClient();
      const {
        data: { user }
      } = await supabase.auth.getUser();
      if (!user) {
        router.push("/auth/sign-in?next=/home");
        return;
      }

      const isFav = fav.has(shopId);
      setFav((prev) => {
        const next = new Set(prev);
        if (isFav) next.delete(shopId);
        else next.add(shopId);
        return next;
      });

      if (isFav) {
        await supabase.from("favorites").delete().eq("profile_id", user.id).eq("target_type", "shop").eq("target_id", shopId);
      } else {
        await supabase.from("favorites").insert({ profile_id: user.id, target_type: "shop", target_id: shopId });
      }
    } catch {}
  }

  const items = useMemo(() => {
    const base = shops.filter((s) => s.id);
    if (!pos) return base;
    const withD = base
      .map((s) => {
        const lat = typeof s.lat === "number" ? s.lat : null;
        const lng = typeof s.lng === "number" ? s.lng : null;
        if (lat == null || lng == null) return { shop: s, d: null as number | null };
        return { shop: s, d: kmBetween(pos, { lat, lng }) };
      })
      .sort((a, b) => {
        if (a.d == null && b.d == null) return 0;
        if (a.d == null) return 1;
        if (b.d == null) return -1;
        return a.d - b.d;
      });
    return withD.map((x): ShopWithDistance => ({ ...x.shop, _distanceKm: x.d }));
  }, [shops, pos]);

  return (
    <div className="flex gap-3 overflow-x-auto pb-1">
      {items.slice(0, 12).map((s) => {
        const d = (s as ShopWithDistance)._distanceKm;
        const rating = typeof s.rating_avg === "number" ? s.rating_avg : null;
        const count = typeof s.rating_count === "number" ? s.rating_count : null;
        const distanceLabel = d == null ? null : `${d.toFixed(d < 1 ? 1 : 0)} km remaining`;
        const isFav = fav.has(s.id);
        return (
          <Link key={s.id} href={`/shop/${encodeURIComponent(s.id)}`} className="block w-[170px] shrink-0">
            <div className="overflow-hidden rounded-[24px] border border-[#2A2A2A] bg-[#111111] shadow-[0_18px_44px_rgba(0,0,0,0.55)]">
              <div className="relative h-[118px] w-full overflow-hidden">
                <SafeImage
                  src={s.cover_url ?? null}
                  fallbackKey="default_shop_cover"
                  alt={s.name ?? "Shop"}
                  className="h-full w-full object-cover"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/10 to-transparent" />
                <button
                  type="button"
                  aria-label="Favorite"
                  className="absolute right-3 top-3 grid h-9 w-9 place-items-center rounded-full border border-white/10 bg-black/30 text-white"
                  onClick={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    void toggleFavorite(s.id);
                  }}
                >
                  <Heart className={cn("h-4 w-4", isFav ? "fill-[hsl(var(--gold))] text-[hsl(var(--gold))]" : "")} />
                </button>
              </div>
              <div className="p-3">
                <div className="flex items-center gap-2">
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-sm font-bold text-white">{s.name ?? "-"}</div>
                  </div>
                  {s.badge_verified ? <span className="h-2.5 w-2.5 rounded-full bg-[hsl(var(--gold))]" /> : null}
                </div>
                <div className="mt-2 flex items-center gap-2 text-[12px] text-[#9E9E9E]">
                  <span className={cn("font-semibold", rating != null ? "text-[hsl(var(--gold))]" : "text-[#9E9E9E]")}>
                    {rating != null ? `★ ${rating.toFixed(1)}` : "★"}
                  </span>
                  {count != null ? <span>({count})</span> : null}
                </div>
                {distanceLabel ? <div className="mt-1 text-[12px] font-semibold text-[#9E9E9E]">{distanceLabel}</div> : null}
              </div>
            </div>
          </Link>
        );
      })}
    </div>
  );
}

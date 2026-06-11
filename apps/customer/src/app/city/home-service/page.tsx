import Link from "next/link";

import { signedOrUrl } from "@hallaq/supabase/storage";
import { getT } from "@hallaq/ui/translations-server";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { RealtimeRefresh } from "@/components/realtime-refresh";
import { SafeImage } from "@/components/safe-image";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

function safeUrl(url: unknown, fallback: string) {
  const u = typeof url === "string" ? url.trim() : "";
  return u || fallback;
}

export default async function CityHomeServicePage({ searchParams }: { searchParams: Promise<{ lat?: string; lng?: string }> }) {
  const t = await getT();
  const params = await searchParams;
  const supabase = await createAppSupabaseServerClient();

  const lat = Number(params.lat ?? 26.2235);
  const lng = Number(params.lng ?? 50.5876);

  const { data, error } = await supabase.rpc("search_home_service_shops", { p_lat: lat, p_lng: lng, p_limit: 40, p_offset: 0 });
  const rows = (data ?? []) as Array<Record<string, unknown>>;

  const list = await Promise.all(
    rows.map(async (s) => {
      const cover = await signedOrUrl(supabase, "shop-images", String(s.cover_path ?? s.cover_url ?? "").trim() || null);
      const logo = await signedOrUrl(supabase, "shop-images", String(s.logo_path ?? s.logo_url ?? "").trim() || null);
      return {
        id: String(s.id),
        name: String(s.name ?? "Shop"),
        area: String(s.area ?? s.address ?? "").trim(),
        rating: Number(s.rating_avg ?? 0),
        visitFee: Number(s.home_service_visit_fee_bhd ?? 0),
        radius: s.home_service_radius_km != null ? Number(s.home_service_radius_km) : null,
        distance: s.distance_km != null ? Number(s.distance_km) : null,
        coverUrl: safeUrl(cover, ""),
        logoUrl: safeUrl(logo, "")
      };
    })
  );

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 pt-6 pb-24 text-white">
      <RealtimeRefresh tables={["barbershops"]} />
      <header className="flex items-center justify-between">
        <div className="flex flex-col gap-1">
          <div className="text-[13px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">{t("customer.city.title")}</div>
          <div className="text-sm font-semibold text-white">Home Service</div>
          <div className="text-[12px] text-muted-foreground">Only shops that enabled home visits.</div>
        </div>
        <Link href="/city" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
          Back
        </Link>
      </header>

      {error ? (
        <div className="rounded-[26px] border border-[#2A2A2A] bg-[#111111] p-4 text-sm text-muted-foreground">
          Could not load home service right now.
        </div>
      ) : null}

      {list.length ? (
        <div className="flex flex-col gap-3">
          {list.map((s) => (
            <div
              key={s.id}
              className="flex gap-3 overflow-hidden rounded-[26px] border border-[#2A2A2A] bg-[#111111] shadow-[0_16px_36px_rgba(0,0,0,0.35)]"
            >
              <Link href={`/shop/${encodeURIComponent(s.id)}`} className="relative h-[92px] w-[120px] shrink-0 overflow-hidden">
                <SafeImage src={s.coverUrl} fallbackKey="default_shop_cover" alt={s.name} className="h-full w-full object-cover" />
                <div className="absolute bottom-2 left-2 h-10 w-10 overflow-hidden rounded-2xl border border-[#2A2A2A] bg-black/60 shadow-[0_10px_24px_rgba(0,0,0,0.35)]">
                  <SafeImage src={s.logoUrl} fallbackKey="default_shop_logo" alt="" className="h-full w-full object-cover" />
                </div>
              </Link>
              <div className="flex flex-1 flex-col justify-between p-3">
                <div className="flex flex-col">
                  <Link href={`/shop/${encodeURIComponent(s.id)}`} className="text-[12px] font-semibold text-white line-clamp-1">
                    {s.name}
                  </Link>
                  <div className="mt-0.5 text-[11px] text-muted-foreground line-clamp-1">
                    {s.area}
                    {s.distance != null ? ` • ${s.distance.toFixed(1)}km` : ""}
                  </div>
                  <div className="mt-1 text-[11px] font-semibold text-white">
                    ★ {s.rating.toFixed(1)} • Visit Fee BD {s.visitFee.toFixed(1)}
                    {s.radius != null ? ` • Radius ${s.radius.toFixed(0)}km` : ""}
                  </div>
                </div>
                <div className="mt-2 grid grid-cols-2 gap-2">
                  <a
                    href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(s.area || s.name)}`}
                    className="rounded-[18px] border border-[#2A2A2A] bg-black/30 px-3 py-2 text-center text-[11px] font-semibold text-white"
                    target="_blank"
                    rel="noreferrer"
                  >
                    Maps
                  </a>
                  <Link
                    href={`/booking/new?homeService=1&shopId=${encodeURIComponent(s.id)}`}
                    className="grid rounded-[18px] bg-[hsl(var(--gold))] px-3 py-2 text-center text-[11px] font-semibold text-[#111111] shadow-[0_14px_34px_rgba(212,175,55,0.22)]"
                  >
                    Book Home Visit
                  </Link>
                </div>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="rounded-[26px] border border-[#2A2A2A] bg-[#111111] p-4 text-sm text-muted-foreground">No home-service shops yet.</div>
      )}

      <CustomerBottomNav />
    </main>
  );
}

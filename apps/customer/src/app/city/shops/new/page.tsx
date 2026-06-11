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

export default async function CityNewShopsPage() {
  const t = await getT();
  const supabase = await createAppSupabaseServerClient();

  const { data: shops, error } = await supabase
    .from("barbershops")
    .select("id, name, area, address, cover_url, cover_path, logo_url, logo_path, rating_avg, created_at, status")
    .eq("status", "approved")
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(40);

  const list = await Promise.all(
    ((shops ?? []) as Array<Record<string, unknown>>).map(async (s) => {
      const cover = await signedOrUrl(supabase, "shop-images", String(s.cover_path ?? s.cover_url ?? "").trim() || null);
      const logo = await signedOrUrl(supabase, "shop-images", String(s.logo_path ?? s.logo_url ?? "").trim() || null);
      return {
        id: String(s.id),
        name: String(s.name ?? "Shop"),
        area: String(s.area ?? s.address ?? "").trim(),
        rating: Number(s.rating_avg ?? 0),
        coverUrl: safeUrl(cover, ""),
        logoUrl: safeUrl(logo, ""),
        createdAt: String(s.created_at ?? "")
      };
    })
  );

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 pt-6 pb-24 text-white">
      <RealtimeRefresh tables={["barbershops"]} />
      <header className="flex items-center justify-between">
        <div className="flex flex-col gap-1">
          <div className="text-[13px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">{t("customer.city.title")}</div>
          <div className="text-sm font-semibold text-white">New Shops</div>
        </div>
        <Link href="/city" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
          Back
        </Link>
      </header>

      {error ? (
        <div className="rounded-[26px] border border-[#2A2A2A] bg-[#111111] p-4 text-sm text-muted-foreground">
          Could not load shops right now.
        </div>
      ) : null}

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
                <div className="mt-0.5 text-[11px] text-muted-foreground line-clamp-1">{s.area}</div>
                <div className="mt-1 text-[11px] font-semibold text-white">★ {s.rating.toFixed(1)}</div>
              </div>
              <div className="mt-2 grid grid-cols-2 gap-2">
                <Link
                  href={`/shop/${encodeURIComponent(s.id)}`}
                  className="rounded-[18px] border border-[#2A2A2A] bg-black/30 px-3 py-2 text-center text-[11px] font-semibold text-white"
                >
                  Profile
                </Link>
                <a
                  href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(s.area || s.name)}`}
                  className="rounded-[18px] bg-[hsl(var(--gold))] px-3 py-2 text-center text-[11px] font-semibold text-[#111111] shadow-[0_14px_34px_rgba(212,175,55,0.22)]"
                  target="_blank"
                  rel="noreferrer"
                >
                  Maps
                </a>
              </div>
            </div>
          </div>
        ))}
      </div>

      <CustomerBottomNav />
    </main>
  );
}

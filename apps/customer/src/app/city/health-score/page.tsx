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

export default async function CityHealthScoreIndexPage() {
  const t = await getT();
  const supabase = await createAppSupabaseServerClient();

  const [{ data: barbers }, { data: shops }] = await Promise.all([
    supabase
      .from("barbers")
      .select("id, display_name, avatar_url, avatar_path, rating_avg")
      .eq("status", "approved")
      .eq("is_active", true)
      .is("deleted_at", null)
      .order("rating_avg", { ascending: false })
      .limit(10),
    supabase.from("barbershops").select("id, name, logo_url, logo_path, rating_avg").eq("status", "approved").is("deleted_at", null).order("rating_avg", { ascending: false }).limit(10)
  ]);

  const barberList = await Promise.all(
    ((barbers ?? []) as Array<Record<string, unknown>>).map(async (b) => {
      const avatar = await signedOrUrl(supabase, "barber-images", String(b.avatar_path ?? b.avatar_url ?? "").trim() || null);
      return { id: String(b.id), name: String(b.display_name ?? "Barber"), rating: Number(b.rating_avg ?? 0), img: safeUrl(avatar, "") };
    })
  );

  const shopList = await Promise.all(
    ((shops ?? []) as Array<Record<string, unknown>>).map(async (s) => {
      const logo = await signedOrUrl(supabase, "shop-images", String(s.logo_path ?? s.logo_url ?? "").trim() || null);
      return { id: String(s.id), name: String(s.name ?? "Shop"), rating: Number(s.rating_avg ?? 0), img: safeUrl(logo, "") };
    })
  );

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 pt-6 pb-24 text-white">
      <RealtimeRefresh tables={["barbers", "barbershops", "bookings", "reviews"]} />
      <header className="flex items-center justify-between">
        <div className="flex flex-col gap-1">
          <div className="text-[13px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">{t("customer.city.title")}</div>
          <div className="text-sm font-semibold text-white">Business Health Score</div>
          <div className="text-[12px] text-muted-foreground">0–100 score built from live marketplace activity.</div>
        </div>
        <Link href="/city" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
          Back
        </Link>
      </header>

      <section className="flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div className="text-sm font-semibold text-white">Barbers</div>
        </div>
        <div className="flex flex-col gap-3">
          {barberList.map((b) => (
            <Link key={b.id} href={`/city/health-score/barber/${encodeURIComponent(b.id)}`} className="block">
              <div className="flex items-center gap-3 overflow-hidden rounded-[26px] border border-[#2A2A2A] bg-[#111111] p-3 shadow-[0_16px_36px_rgba(0,0,0,0.35)]">
                <div className="h-12 w-12 overflow-hidden rounded-2xl border border-[#2A2A2A] bg-black/30">
                  <SafeImage src={b.img} fallbackKey="default_barber_avatar" alt="" className="h-full w-full object-cover" />
                </div>
                <div className="flex flex-1 flex-col">
                  <div className="text-[12px] font-semibold text-white line-clamp-1">{b.name}</div>
                  <div className="mt-0.5 text-[11px] text-muted-foreground">★ {b.rating.toFixed(1)}</div>
                </div>
                <div className="rounded-full bg-[hsl(var(--gold))/0.14] px-3 py-2 text-[11px] font-semibold text-[hsl(var(--gold))]">View</div>
              </div>
            </Link>
          ))}
        </div>
      </section>

      <section className="flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div className="text-sm font-semibold text-white">Shops</div>
        </div>
        <div className="flex flex-col gap-3">
          {shopList.map((s) => (
            <Link key={s.id} href={`/city/health-score/shop/${encodeURIComponent(s.id)}`} className="block">
              <div className="flex items-center gap-3 overflow-hidden rounded-[26px] border border-[#2A2A2A] bg-[#111111] p-3 shadow-[0_16px_36px_rgba(0,0,0,0.35)]">
                <div className="h-12 w-12 overflow-hidden rounded-2xl border border-[#2A2A2A] bg-black/30">
                  <SafeImage src={s.img} fallbackKey="default_shop_logo" alt="" className="h-full w-full object-cover" />
                </div>
                <div className="flex flex-1 flex-col">
                  <div className="text-[12px] font-semibold text-white line-clamp-1">{s.name}</div>
                  <div className="mt-0.5 text-[11px] text-muted-foreground">★ {s.rating.toFixed(1)}</div>
                </div>
                <div className="rounded-full bg-[hsl(var(--gold))/0.14] px-3 py-2 text-[11px] font-semibold text-[hsl(var(--gold))]">View</div>
              </div>
            </Link>
          ))}
        </div>
      </section>

      <CustomerBottomNav />
    </main>
  );
}

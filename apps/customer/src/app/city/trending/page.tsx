import Link from "next/link";

import { signedOrUrl } from "@hallaq/supabase/storage";
import { getT } from "@hallaq/ui/translations-server";
import { cn } from "@hallaq/ui/cn";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { RealtimeRefresh } from "@/components/realtime-refresh";
import { SafeImage } from "@/components/safe-image";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type Tab = "barbers" | "shops" | "reels";

function tabFromParam(value: string | undefined): Tab {
  if (value === "shops") return "shops";
  if (value === "reels") return "reels";
  return "barbers";
}

export default async function CityTrendingPage({ searchParams }: { searchParams: Promise<{ tab?: string }> }) {
  const t = await getT();
  const params = await searchParams;
  const tab = tabFromParam(params.tab);
  const supabase = await createAppSupabaseServerClient();

  const tabs: Array<{ key: Tab; label: string; href: string }> = [
    { key: "barbers", label: "Barbers", href: "/city/trending?tab=barbers" },
    { key: "shops", label: "Shops", href: "/city/trending?tab=shops" },
    { key: "reels", label: "Reels", href: "/city/trending?tab=reels" }
  ];

  const barbersPromise =
    tab === "barbers"
      ? supabase.rpc("city_trending_barbers", { p_limit: 30 })
      : Promise.resolve({ data: [], error: null } as { data: unknown[]; error: unknown });

  const shopsPromise =
    tab === "shops"
      ? supabase.rpc("city_trending_shops", { p_limit: 30 })
      : Promise.resolve({ data: [], error: null } as { data: unknown[]; error: unknown });

  const reelsPromise =
    tab === "reels"
      ? supabase.rpc("city_trending_reels", { p_limit: 30 })
      : Promise.resolve({ data: [], error: null } as { data: unknown[]; error: unknown });

  const [
    { data: barbers, error: barbersError },
    { data: shops, error: shopsError },
    { data: reels, error: reelsError }
  ] = await Promise.all([barbersPromise, shopsPromise, reelsPromise]);

  const items =
    tab === "barbers"
      ? await Promise.all(
          (barbers as Array<Record<string, unknown>>).map(async (b) => {
            const avatar = await signedOrUrl(supabase, "barber-images", String(b.avatar_path ?? b.avatar_url ?? "").trim() || null);
            return {
              id: String(b.id),
              title: String(b.display_name ?? "Barber"),
              subtitle: `★ ${Number(b.rating_avg ?? 0).toFixed(1)} • ${Number(b.followers_count ?? 0).toLocaleString()} followers • ${Number(b.bookings_count ?? 0).toLocaleString()} bookings • ${Number(b.views_count ?? 0).toLocaleString()} views`,
              imageUrl: avatar,
              fallbackKey: "default_barber_avatar",
              href: `/barber/${encodeURIComponent(String(b.id))}`
            };
          })
        )
      : tab === "shops"
        ? await Promise.all(
            (shops as Array<Record<string, unknown>>).map(async (s) => {
              const logo = await signedOrUrl(supabase, "shop-images", String(s.logo_path ?? s.logo_url ?? "").trim() || null);
              return {
                id: String(s.id),
                title: String(s.name ?? "Shop"),
                subtitle: `${String(s.area ?? "")} • ★ ${Number(s.rating_avg ?? 0).toFixed(1)} • ${Number(s.followers_count ?? 0).toLocaleString()} followers • ${Number(s.bookings_count ?? 0).toLocaleString()} bookings`,
                imageUrl: logo,
                fallbackKey: "default_shop_logo",
                href: `/shop/${encodeURIComponent(String(s.id))}`
              };
            })
          )
        : await Promise.all(
            (reels as Array<Record<string, unknown>>).map(async (r) => {
              const ref = String(r.thumbnail_path ?? r.thumbnail_url ?? r.media_path ?? r.media_url ?? "").trim() || null;
              const poster =
                (await signedOrUrl(supabase, "reels", ref)) ??
                (await signedOrUrl(supabase, "reels-media", ref)) ??
                (await signedOrUrl(supabase, "post-media", ref));
              return {
                id: String(r.id),
                title: String(r.caption ?? "Reel"),
                subtitle: `▶ ${Number(r.views_count ?? 0).toLocaleString()} • ♥ ${Number(r.likes_count ?? 0)} • 💬 ${Number(r.comments_count ?? 0)}`,
                imageUrl: poster,
                fallbackKey: "default_reel_thumbnail",
                href: "/city/reels"
              };
            })
          );

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 px-4 pt-6 pb-24">
      <RealtimeRefresh tables={["barbers", "barbershops", "reels"]} />
      <header className="flex items-center justify-between">
        <div className="flex flex-col gap-1">
          <div className="text-[13px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">{t("customer.city.title")}</div>
          <div className="text-sm font-semibold text-[#111111]">Trending This Week</div>
        </div>
        <Link href="/city" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
          Back
        </Link>
      </header>

      <div className="flex gap-2 overflow-x-auto pb-1">
        {tabs.map((x) => {
          const active = x.key === tab;
          return (
            <Link
              key={x.key}
              href={x.href}
              className={cn(
                "shrink-0 rounded-full border px-3 py-2 text-[12px] font-semibold leading-none transition",
                active
                  ? "border-[hsl(var(--gold))] bg-[hsl(var(--gold))/0.10] text-[#111111]"
                  : "border-black/10 bg-white text-muted-foreground hover:border-black/20"
              )}
            >
              {x.label}
            </Link>
          );
        })}
      </div>

      <div className="flex flex-col gap-3">
        {(barbersError || shopsError || reelsError) ? (
          <div className="rounded-[26px] border bg-white p-4 text-sm text-muted-foreground">
            Trending is syncing. Refresh to try again.
          </div>
        ) : null}

        {items.map((it, idx) => (
          <Link key={it.id} href={it.href} className="block">
            <div className="flex items-center gap-3 overflow-hidden rounded-[24px] border bg-white p-3 shadow-[0_16px_36px_rgba(17,17,17,0.08)]">
              <div className="grid h-8 w-8 place-items-center rounded-full bg-[hsl(var(--gold))] text-[12px] font-black text-[#111111]">
                {idx + 1}
              </div>
              <div className="h-12 w-12 overflow-hidden rounded-2xl border bg-white">
                <SafeImage src={it.imageUrl} fallbackKey={it.fallbackKey} alt="" className="h-full w-full object-cover" />
              </div>
              <div className="flex flex-1 flex-col">
                <div className="text-[12px] font-semibold text-[#111111] line-clamp-1">{it.title}</div>
                <div className="mt-0.5 text-[11px] text-muted-foreground line-clamp-1">{it.subtitle}</div>
              </div>
              <div className="rounded-full bg-black/5 px-3 py-2 text-[11px] font-semibold text-[#111111]">View</div>
            </div>
          </Link>
        ))}
      </div>

      <CustomerBottomNav />
    </main>
  );
}

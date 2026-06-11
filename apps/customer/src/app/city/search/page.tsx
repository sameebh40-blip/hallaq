import Link from "next/link";
import { cookies } from "next/headers";

import { signedOrUrl } from "@hallaq/supabase/storage";
import { getT } from "@hallaq/ui/translations-server";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { SafeImage } from "@/components/safe-image";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type SearchResult = {
  type: "barber" | "shop" | "offer" | "style";
  id: string;
  title: string;
  subtitle?: string | null;
  imageUrl?: string | null;
  fallbackKey: string;
  href: string;
};

export default async function CitySearchPage({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
  const t = await getT();
  const params = await searchParams;
  const q = (params.q ?? "").trim();
  const supabase = await createAppSupabaseServerClient();
  const cookieStore = await cookies();
  const selectedCity = decodeURIComponent(cookieStore.get("hallaq_city")?.value ?? "Manama").trim();
  const { data: cityRow } = await supabase.from("cities").select("id").ilike("name", selectedCity).maybeSingle();
  const selectedCityId = (cityRow?.id as string | undefined) ?? undefined;

  const query = q.length >= 2 ? q : "";

  const barberPromise = query
    ? (() => {
        let qy = supabase
          .from("barbers")
          .select("id, display_name, avatar_url, avatar_path, rating_avg")
          .eq("status", "approved")
          .eq("is_active", true)
          .is("deleted_at", null)
          .ilike("display_name", `%${query}%`)
          .limit(10);
        if (selectedCityId) qy = qy.eq("city_id", selectedCityId);
        return qy;
      })()
    : Promise.resolve({ data: [], error: null });

  const shopPromise = query
    ? (() => {
        let qy = supabase
          .from("barbershops")
          .select("id, name, area, logo_url, logo_path, cover_url, cover_path, rating_avg, status")
          .eq("status", "approved")
          .ilike("name", `%${query}%`)
          .limit(10);
        if (selectedCityId) qy = qy.eq("city_id", selectedCityId);
        return qy;
      })()
    : Promise.resolve({ data: [], error: null });

  const offerPromise = query
    ? (() => {
        let qy = supabase
          .from("offers")
          .select("id, title, discount_percent, shop_id, barbershops!inner(id, name, cover_url, cover_path, city_id)")
          .eq("active", true)
          .eq("is_active", true)
          .eq("status", "approved")
          .ilike("title", `%${query}%`)
          .limit(10);
        if (selectedCityId) qy = qy.eq("barbershops.city_id", selectedCityId);
        return qy;
      })()
    : Promise.resolve({ data: [], error: null });

  const stylePromise = query
    ? supabase
        .from("style_library")
        .select("id, name_en, name_ar, cover_url, cover_path, views_count, is_active")
        .eq("is_active", true)
        .eq("status", "approved")
        .or([`name_en.ilike.%${query}%`, `name_ar.ilike.%${query}%`, `slug.ilike.%${query}%`].join(","))
        .limit(10)
    : Promise.resolve({ data: [], error: null });

  const [{ data: barbers }, { data: shops }, { data: offers }, { data: styles }] = await Promise.all([
    barberPromise,
    shopPromise,
    offerPromise,
    stylePromise
  ]);

  const results: SearchResult[] = [];

  for (const b of (barbers ?? []) as Array<Record<string, unknown>>) {
    const avatar = await signedOrUrl(supabase, "barber-images", (b.avatar_path as string | null) ?? (b.avatar_url as string | null));
    results.push({
      type: "barber",
      id: String(b.id),
      title: String(b.display_name ?? "Barber"),
      subtitle: `${Number(b.rating_avg ?? 0).toFixed(1)} rating`,
      imageUrl: typeof avatar === "string" ? avatar.trim() : null,
      fallbackKey: "default_barber_avatar",
      href: `/barber/${encodeURIComponent(String(b.id))}`
    });
  }

  for (const s of (shops ?? []) as Array<Record<string, unknown>>) {
    const logo = await signedOrUrl(supabase, "shop-images", (s.logo_path as string | null) ?? (s.logo_url as string | null));
    results.push({
      type: "shop",
      id: String(s.id),
      title: String(s.name ?? "Shop"),
      subtitle: String(s.area ?? ""),
      imageUrl: typeof logo === "string" ? logo.trim() : null,
      fallbackKey: "default_shop_logo",
      href: `/shop/${encodeURIComponent(String(s.id))}`
    });
  }

  for (const o of (offers ?? []) as Array<Record<string, unknown>>) {
    const shop = (o.barbershops as Record<string, unknown> | null) ?? null;
    const cover = await signedOrUrl(supabase, "shop-images", (shop?.cover_path as string | null) ?? (shop?.cover_url as string | null));
    const discount = o.discount_percent != null ? `${Math.round(Number(o.discount_percent))}%` : "";
    results.push({
      type: "offer",
      id: String(o.id),
      title: `${discount} ${String(o.title ?? "Offer")}`.trim(),
      subtitle: String(shop?.name ?? ""),
      imageUrl: typeof cover === "string" ? cover.trim() : null,
      fallbackKey: "default_offer_image",
      href: "/city/offers"
    });
  }

  for (const s of (styles ?? []) as Array<Record<string, unknown>>) {
    const cover = await signedOrUrl(supabase, "style-library", (s.cover_path as string | null) ?? (s.cover_url as string | null));
    const title = String(s.name_en ?? s.name_ar ?? "Style");
    results.push({
      type: "style",
      id: String(s.id),
      title,
      subtitle: `${Number(s.views_count ?? 0).toLocaleString()} views`,
      imageUrl: typeof cover === "string" ? cover.trim() : null,
      fallbackKey: "default_style_image",
      href: `/city/styles/${encodeURIComponent(String(s.id))}`
    });
  }

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 pt-6 pb-28 text-white">
      <header className="flex flex-col gap-1">
        <div className="text-[13px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">{t("customer.city.title")}</div>
        <div className="text-sm text-[#9E9E9E]">{q ? `Results for “${q}”` : "Search"}</div>
      </header>

      <form action="/city/search" className="flex items-center gap-2">
        <input
          name="q"
          defaultValue={q}
          placeholder={t("customer.city.searchPlaceholder")}
          className="h-12 flex-1 rounded-[22px] border border-[#2A2A2A] bg-[#111111] px-4 text-[13px] font-semibold text-white outline-none placeholder:text-white/60 focus:border-[hsl(var(--gold))]/45"
        />
        <button
          type="submit"
          className="h-12 rounded-[22px] bg-[hsl(var(--gold))] px-4 text-[13px] font-extrabold text-black shadow-[0_18px_42px_rgba(212,175,55,0.25)]"
        >
          Search
        </button>
      </form>

      {query.length < 2 ? (
        <div className="rounded-[26px] border border-[#2A2A2A] bg-[#111111] p-4 text-sm font-semibold text-[#9E9E9E]">Type at least 2 letters to search.</div>
      ) : results.length ? (
        <div className="flex flex-col gap-3">
          {results.map((r) => (
            <Link key={`${r.type}:${r.id}`} href={r.href} className="block">
              <div className="flex items-center gap-3 overflow-hidden rounded-[22px] border border-[#2A2A2A] bg-[#111111] p-3 shadow-[0_18px_44px_rgba(0,0,0,0.55)]">
                <div className="h-12 w-12 shrink-0 overflow-hidden rounded-2xl border border-[#2A2A2A] bg-black">
                  <SafeImage src={r.imageUrl} fallbackKey={r.fallbackKey} alt="" className="h-full w-full object-cover" />
                </div>
                <div className="flex flex-1 flex-col">
                  <div className="text-[12px] font-extrabold text-white line-clamp-1">{r.title}</div>
                  {r.subtitle ? <div className="mt-0.5 text-[11px] font-semibold text-[#9E9E9E] line-clamp-1">{r.subtitle}</div> : null}
                </div>
                <div className="rounded-full border border-[hsl(var(--gold))]/25 bg-black/30 px-2 py-1 text-[10px] font-extrabold text-[hsl(var(--gold))]">
                  {r.type}
                </div>
              </div>
            </Link>
          ))}
        </div>
      ) : (
        <div className="rounded-[26px] border border-[#2A2A2A] bg-[#111111] p-4 text-sm font-semibold text-[#9E9E9E]">No results.</div>
      )}

      <CustomerBottomNav />
    </main>
  );
}

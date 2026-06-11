import Link from "next/link";

import { signedOrUrl } from "@hallaq/supabase/storage";
import { getServerLocale, getT } from "@hallaq/ui/translations-server";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { RealtimeRefresh } from "@/components/realtime-refresh";
import { SafeImage } from "@/components/safe-image";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

export default async function CityAwardDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const t = await getT();
  const locale = await getServerLocale();
  const supabase = await createAppSupabaseServerClient();
  const { id } = await params;

  const { data: award } = await supabase
    .from("awards")
    .select("id, year, target_type, target_id, winner_photo_url, winner_photo_path, stats, reason, award_categories(id, name_en, name_ar)")
    .eq("id", id)
    .maybeSingle();

  const category = (award?.award_categories ?? null) as { name_en?: string; name_ar?: string } | null;
  const categoryLabel = locale === "en" ? (category?.name_en ?? "Award") : (category?.name_ar ?? "جائزة");

  const winnerType = String(award?.target_type ?? "");
  const winnerId = String(award?.target_id ?? "");

  let winnerName = "";
  let winnerPhoto: string | null = null;
  let winnerHref: string | null = null;

  if (winnerType === "barber") {
    const { data: barber } = await supabase.from("barbers").select("id, display_name, avatar_url, avatar_path").eq("id", winnerId).maybeSingle();
    winnerName = barber?.display_name ?? "Barber";
    winnerHref = barber?.id ? `/barber/${encodeURIComponent(barber.id)}` : null;
    winnerPhoto = await signedOrUrl(supabase, "barber-images", barber?.avatar_path ?? barber?.avatar_url);
  } else if (winnerType === "shop") {
    const { data: shop } = await supabase.from("barbershops").select("id, name, logo_url, logo_path").eq("id", winnerId).maybeSingle();
    winnerName = shop?.name ?? "Shop";
    winnerHref = shop?.id ? `/shop/${encodeURIComponent(shop.id)}` : null;
    winnerPhoto = await signedOrUrl(supabase, "shop-images", shop?.logo_path ?? shop?.logo_url);
  }

  if (!winnerPhoto) {
    winnerPhoto = await signedOrUrl(supabase, "awards", award?.winner_photo_path ?? award?.winner_photo_url);
  }

  const stats = ((award?.stats ?? {}) as Record<string, unknown>) ?? {};
  const reason = (award?.reason ?? "").trim();
  const winnerFallbackKey = winnerType === "barber" ? "default_barber_avatar" : winnerType === "shop" ? "default_shop_logo" : "default_profile_avatar";

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 px-4 pt-6 pb-24">
      <RealtimeRefresh tables={["awards", "award_categories", "barbers", "barbershops"]} />
      <header className="flex items-center justify-between">
        <div className="flex flex-col gap-1">
          <div className="text-[13px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">{t("customer.city.title")}</div>
          <div className="text-sm font-semibold text-[#111111]">{categoryLabel}</div>
          <div className="text-[12px] text-muted-foreground">{award?.year ?? ""}</div>
        </div>
        <Link href="/city/awards" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
          Back
        </Link>
      </header>

      <div className="overflow-hidden rounded-[28px] border bg-[#111111] p-5 text-white shadow-[0_18px_48px_rgba(0,0,0,0.18)]">
        <div className="text-[11px] font-semibold tracking-[0.22em] text-white/70">WINNER</div>
        <div className="mt-2 text-sm font-semibold">{winnerName || "—"}</div>
        <div className="mt-1 text-[12px] text-white/80">{winnerType ? winnerType.toUpperCase() : ""}</div>
        <div className="mt-4 flex items-center gap-3 rounded-[22px] bg-white/10 p-3">
          <div className="h-12 w-12 overflow-hidden rounded-2xl border border-white/10 bg-white/10">
            <SafeImage src={winnerPhoto} fallbackKey={winnerFallbackKey} alt="" className="h-full w-full object-cover" />
          </div>
          <div className="flex flex-1 flex-col">
            <div className="text-[12px] font-semibold text-white line-clamp-1">{winnerName || "Winner"}</div>
            <div className="mt-0.5 text-[11px] text-white/70">{categoryLabel}</div>
          </div>
          {winnerHref ? (
            <Link href={winnerHref} className="rounded-full bg-[hsl(var(--gold))] px-3 py-2 text-[11px] font-semibold text-[#111111]">
              View
            </Link>
          ) : null}
        </div>
      </div>

      <div className="overflow-hidden rounded-[28px] border bg-white p-4 shadow-[0_16px_36px_rgba(17,17,17,0.08)]">
        <div className="text-sm font-semibold text-[#111111]">Stats</div>
        <div className="mt-3 grid grid-cols-2 gap-3">
          {[
            { k: "views", label: "Views" },
            { k: "likes", label: "Likes" },
            { k: "followers", label: "Followers" },
            { k: "bookings", label: "Bookings" }
          ].map((x) => (
            <div key={x.k} className="rounded-[22px] bg-black/5 px-4 py-3">
              <div className="text-[10px] font-semibold text-muted-foreground">{x.label}</div>
              <div className="mt-1 text-base font-black text-[#111111]">{Number(stats[x.k] ?? 0).toLocaleString()}</div>
            </div>
          ))}
        </div>
      </div>

      <div className="overflow-hidden rounded-[28px] border bg-white p-4 shadow-[0_16px_36px_rgba(17,17,17,0.08)]">
        <div className="text-sm font-semibold text-[#111111]">Reason</div>
        <div className="mt-2 text-[12px] text-muted-foreground">
          {reason || "This winner leads the week with exceptional consistency, client satisfaction, and booking performance."}
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <Link href="/booking/new" className="grid h-12 place-items-center rounded-[22px] bg-black/5 text-[13px] font-semibold text-[#111111]">
          Book
        </Link>
        {winnerHref ? (
          <Link
            href={winnerHref}
            className="grid h-12 place-items-center rounded-[22px] bg-[hsl(var(--gold))] text-[13px] font-semibold text-[#111111] shadow-[0_18px_42px_rgba(212,175,55,0.25)]"
          >
            Winner Profile
          </Link>
        ) : (
          <Link
            href="/city"
            className="grid h-12 place-items-center rounded-[22px] bg-[hsl(var(--gold))] text-[13px] font-semibold text-[#111111] shadow-[0_18px_42px_rgba(212,175,55,0.25)]"
          >
            Explore City
          </Link>
        )}
      </div>

      <CustomerBottomNav />
    </main>
  );
}

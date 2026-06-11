import Link from "next/link";

import { signedOrUrl } from "@hallaq/supabase/storage";
import { getT } from "@hallaq/ui/translations-server";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { RealtimeRefresh } from "@/components/realtime-refresh";
import { SafeImage } from "@/components/safe-image";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type OfferRow = {
  id: string;
  title?: string | null;
  description?: string | null;
  discount_percent?: number | null;
  valid_to?: string | null;
  barbershops?: { id: string; name?: string | null; cover_url?: string | null; cover_path?: string | null } | null;
};

function trimUrl(url: unknown) {
  const u = typeof url === "string" ? url.trim() : "";
  return u || null;
}

export default async function CityOffersPage() {
  const t = await getT();
  const supabase = await createAppSupabaseServerClient();

  const { data: offers, error } = await supabase
    .from("offers")
    .select("id, title, description, discount_percent, valid_to, active, created_at, barbershops(id, name, cover_url, cover_path)")
    .eq("active", true)
    .eq("is_active", true)
    .eq("status", "approved")
    .order("created_at", { ascending: false })
    .limit(50);

  const normalized: OfferRow[] = ((offers ?? []) as unknown[]).map((row) => {
    const r = row as Record<string, unknown>;
    const embedded = (r.barbershops ?? null) as unknown;
    const shop =
      embedded && Array.isArray(embedded)
        ? ((embedded[0] ?? null) as Record<string, unknown> | null)
        : (embedded as Record<string, unknown> | null);
    return {
      id: String(r.id),
      title: (r.title as string | null | undefined) ?? null,
      description: (r.description as string | null | undefined) ?? null,
      discount_percent: (r.discount_percent as number | null | undefined) ?? null,
      valid_to: (r.valid_to as string | null | undefined) ?? null,
      barbershops: shop
        ? {
            id: String(shop.id),
            name: (shop.name as string | null | undefined) ?? null,
            cover_url: (shop.cover_url as string | null | undefined) ?? null,
            cover_path: (shop.cover_path as string | null | undefined) ?? null
          }
        : null
    };
  });

  const list = await Promise.all(
    normalized.map(async (o) => {
      const cover = await signedOrUrl(supabase, "shop-images", o.barbershops?.cover_path ?? o.barbershops?.cover_url);
      return {
        ...o,
        coverUrl: trimUrl(cover),
        shopName: o.barbershops?.name ?? ""
      };
    })
  );

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 px-4 pt-6 pb-24">
      <RealtimeRefresh tables={["offers"]} />
      <header className="flex items-center justify-between">
        <div className="flex flex-col gap-1">
          <div className="text-[13px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">{t("customer.city.title")}</div>
          <div className="text-sm font-semibold text-[#111111]">Current Offers</div>
        </div>
        <Link href="/city" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
          Back
        </Link>
      </header>

      {error ? (
        <div className="rounded-[26px] border bg-white p-4 text-sm text-muted-foreground">
          Offers are unavailable right now. Refresh the page to try again.
        </div>
      ) : null}

      {list.length ? (
        <div className="flex flex-col gap-3">
          {list.map((o) => {
            const pct = o.discount_percent != null ? Math.round(Number(o.discount_percent)) : null;
            return (
              <div key={o.id} className="relative overflow-hidden rounded-[26px] border bg-white shadow-[0_18px_42px_rgba(17,17,17,0.09)]">
                <div className="absolute inset-0">
                  <SafeImage src={o.coverUrl} fallbackKey="default_offer_image" alt="" className="h-full w-full object-cover opacity-[0.20]" />
                </div>
                <div className="relative flex items-center justify-between gap-4 p-4">
                  <div className="flex flex-col gap-1">
                    <div className="text-[12px] font-semibold text-[#111111] line-clamp-1">{o.title ?? "Offer"}</div>
                    <div className="text-[11px] text-muted-foreground line-clamp-1">{o.shopName}</div>
                    <div className="mt-1 text-[11px] font-semibold text-[#111111]">
                      Expires {o.valid_to ? new Date(o.valid_to).toLocaleDateString() : "soon"}
                    </div>
                  </div>
                  <div className="grid h-14 w-14 place-items-center rounded-[20px] bg-[hsl(var(--gold))/0.14] text-[#111111] shadow-[0_14px_34px_rgba(212,175,55,0.20)]">
                    <div className="text-center">
                      <div className="text-[12px] font-black">{pct != null ? `${pct}%` : "BD"}</div>
                      <div className="text-[10px] font-semibold text-black/60">OFF</div>
                    </div>
                  </div>
                </div>
                <div className="relative grid grid-cols-2 gap-2 px-4 pb-4">
                  <Link
                    href={`/booking/new?offerId=${encodeURIComponent(o.id)}`}
                    className="grid h-11 place-items-center rounded-[20px] bg-black/5 text-[12px] font-semibold text-[#111111]"
                  >
                    Claim
                  </Link>
                  <Link
                    href="/booking/new"
                    className="grid h-11 place-items-center rounded-[20px] bg-[hsl(var(--gold))] text-[12px] font-semibold text-[#111111] shadow-[0_14px_34px_rgba(212,175,55,0.22)]"
                  >
                    Book
                  </Link>
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        <div className="rounded-[26px] border bg-white p-4 text-sm text-muted-foreground">No active offers yet.</div>
      )}

      <CustomerBottomNav />
    </main>
  );
}

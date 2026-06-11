import Link from "next/link";

import { SafeImage } from "@/components/safe-image";
import type { CityHomeOffer, CityHomeReel, CityHomeShop } from "./city-home";

export function CityHomeMore({
  newShops,
  bestReels,
  offers,
  styles
}: {
  newShops: CityHomeShop[];
  bestReels: CityHomeReel[];
  offers: CityHomeOffer[];
  styles: Array<{ id: string; name: string; coverUrl: string | null; views: number }>;
}) {
  return (
    <>
      <section className="flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div className="text-sm font-semibold text-[#111111]">New Shops</div>
          <Link href="/city/shops/new" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
            View All
          </Link>
        </div>

        <div className="flex flex-col gap-3">
          {newShops.slice(0, 3).map((s) => (
            <Link key={s.id} href={`/shop/${encodeURIComponent(s.id)}`} className="block">
              <div className="flex gap-3 overflow-hidden rounded-[24px] border bg-white shadow-[0_16px_36px_rgba(17,17,17,0.08)]">
                <div className="h-[74px] w-[92px] shrink-0 overflow-hidden">
                  <SafeImage src={s.cover_url} fallbackKey="default_shop_cover" alt={s.name ?? "Shop"} className="h-full w-full object-cover" />
                </div>
                <div className="flex flex-1 items-center justify-between py-3 pr-3">
                  <div className="flex flex-col">
                    <div className="text-[12px] font-semibold text-[#111111] line-clamp-1">{s.name ?? "Shop"}</div>
                    <div className="mt-0.5 text-[11px] text-muted-foreground line-clamp-1">{s.area ?? ""}</div>
                    <div className="mt-1 text-[11px] font-semibold text-[#111111]">{Number(s.rating_avg ?? 0).toFixed(1)}</div>
                  </div>
                  <div className="h-10 w-10 overflow-hidden rounded-2xl border bg-white">
                    <SafeImage src={s.logo_url} fallbackKey="default_shop_logo" alt="" className="h-full w-full object-cover" />
                  </div>
                </div>
              </div>
            </Link>
          ))}
        </div>
      </section>

      <section className="flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div className="text-sm font-semibold text-[#111111]">Best Reels</div>
          <Link href="/city/reels" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
            View All
          </Link>
        </div>

        <div className="grid grid-cols-2 gap-3">
          {bestReels.slice(0, 4).map((r) => (
            <Link key={r.id} href="/city/reels" className="block">
              <div className="relative overflow-hidden rounded-[24px] border bg-white shadow-[0_16px_36px_rgba(17,17,17,0.08)]">
                <div className="aspect-[9/16] w-full overflow-hidden">
                  <SafeImage src={r.thumbnail_url} fallbackKey="default_reel_thumbnail" alt={r.caption ?? "Reel"} className="h-full w-full object-cover" />
                </div>
                <div className="absolute inset-x-0 bottom-0 flex items-center justify-between gap-2 bg-gradient-to-t from-black/65 via-black/15 to-transparent p-3 text-[11px] font-semibold text-white">
                  <div className="flex items-center gap-2">
                    <span>♥ {Number(r.likes_count ?? 0)}</span>
                    <span>💬 {Number(r.comments_count ?? 0)}</span>
                  </div>
                  <span className="rounded-full bg-white/14 px-2 py-1 text-[10px] backdrop-blur">Play</span>
                </div>
              </div>
            </Link>
          ))}
        </div>
      </section>

      <section className="flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div className="text-sm font-semibold text-[#111111]">Current Offers</div>
          <Link href="/city/offers" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
            View All
          </Link>
        </div>

        {offers.length ? (
          <div className="flex flex-col gap-3">
            {offers.map((o) => (
              <Link key={o.id} href="/city/offers" className="block">
                <div className="relative overflow-hidden rounded-[26px] border bg-white shadow-[0_18px_42px_rgba(17,17,17,0.09)]">
                  <div className="absolute inset-0">
                    <SafeImage
                      src={o.barbershops?.cover_url}
                      fallbackKey="default_offer_image"
                      alt=""
                      className="h-full w-full object-cover opacity-[0.20]"
                    />
                  </div>
                  <div className="relative flex items-center justify-between gap-4 p-4">
                    <div className="flex flex-col gap-1">
                      <div className="text-[12px] font-semibold text-[#111111] line-clamp-1">{o.title ?? "Offer"}</div>
                      <div className="text-[11px] text-muted-foreground line-clamp-1">{o.barbershops?.name ?? ""}</div>
                      <div className="mt-1 text-[11px] font-semibold text-[#111111]">
                        Expires {o.valid_to ? new Date(o.valid_to).toLocaleDateString() : "soon"}
                      </div>
                    </div>
                    <div className="grid h-14 w-14 place-items-center rounded-[20px] bg-[hsl(var(--gold))/0.14] text-[#111111] shadow-[0_14px_34px_rgba(212,175,55,0.20)]">
                      <div className="text-center">
                        <div className="text-[12px] font-black">
                          {o.discount_percent ? `${Math.round(Number(o.discount_percent))}%` : "BD"}
                        </div>
                        <div className="text-[10px] font-semibold text-black/60">OFF</div>
                      </div>
                    </div>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        ) : (
          <div className="rounded-[26px] border bg-white p-4 text-sm text-muted-foreground">No active offers yet.</div>
        )}
      </section>

      <section className="flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div className="text-sm font-semibold text-[#111111]">Style Library</div>
          <Link href="/city/styles" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
            View All
          </Link>
        </div>

        <div className="grid grid-cols-2 gap-3">
          {styles.slice(0, 4).map((s) => (
            <Link key={s.id} href={`/city/styles/${encodeURIComponent(s.id)}`} className="block">
              <div className="overflow-hidden rounded-[24px] border bg-white shadow-[0_16px_36px_rgba(17,17,17,0.08)]">
                <div className="aspect-square w-full overflow-hidden">
                  <SafeImage src={s.coverUrl} fallbackKey="default_style_image" alt={s.name} className="h-full w-full object-cover" />
                </div>
                <div className="p-3">
                  <div className="text-[12px] font-semibold text-[#111111]">{s.name}</div>
                  <div className="mt-1 text-[11px] text-muted-foreground">{s.views.toLocaleString()} views</div>
                </div>
              </div>
            </Link>
          ))}
        </div>
      </section>

      <section className="grid grid-cols-2 gap-3">
        <Link href="/city/ai-studio" className="block">
          <div className="overflow-hidden rounded-[26px] border bg-[#111111] p-4 text-white shadow-[0_18px_48px_rgba(0,0,0,0.18)]">
            <div className="text-[11px] font-semibold tracking-[0.22em] text-white/70">AI HAIRCUT STUDIO</div>
            <div className="mt-2 text-sm font-semibold">Preview your next look</div>
            <div className="mt-3 inline-flex rounded-full bg-white/14 px-3 py-1 text-[11px] font-semibold backdrop-blur">
              Try now
            </div>
          </div>
        </Link>
        <Link href="/city/awards" className="block">
          <div className="overflow-hidden rounded-[26px] border bg-white p-4 shadow-[0_18px_48px_rgba(17,17,17,0.10)]">
            <div className="text-[11px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">HALLAQ AWARDS</div>
            <div className="mt-2 text-sm font-semibold text-[#111111]">Winners & rankings</div>
            <div className="mt-3 inline-flex rounded-full bg-[hsl(var(--gold))/0.14] px-3 py-1 text-[11px] font-semibold text-[#111111]">
              Open
            </div>
          </div>
        </Link>
      </section>

      <section className="grid grid-cols-2 gap-3">
        <Link href="/city/levels" className="block">
          <div className="overflow-hidden rounded-[26px] border bg-white p-4 shadow-[0_18px_48px_rgba(17,17,17,0.10)]">
            <div className="text-[11px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">LEVELS</div>
            <div className="mt-2 text-sm font-semibold text-[#111111]">Silver • Gold • Platinum</div>
            <div className="mt-1 text-[12px] text-muted-foreground">Points • progress • benefits</div>
            <div className="mt-3 inline-flex rounded-full bg-black/5 px-3 py-1 text-[11px] font-semibold text-[#111111]">Open</div>
          </div>
        </Link>
        <Link href="/city/gift-cards" className="block">
          <div className="overflow-hidden rounded-[26px] border bg-[#111111] p-4 text-white shadow-[0_18px_48px_rgba(0,0,0,0.18)]">
            <div className="text-[11px] font-semibold tracking-[0.22em] text-white/70">GIFT CARDS</div>
            <div className="mt-2 text-sm font-semibold">BD 10 / 20 / 50</div>
            <div className="mt-1 text-[12px] text-white/80">Purchase • Send • Redeem</div>
            <div className="mt-3 inline-flex rounded-full bg-white/14 px-3 py-1 text-[11px] font-semibold backdrop-blur">
              Open
            </div>
          </div>
        </Link>
      </section>

      <Link href="/city/availability" className="block">
        <div className="overflow-hidden rounded-[26px] border bg-white p-4 shadow-[0_18px_48px_rgba(17,17,17,0.10)]">
          <div className="text-[11px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">LIVE</div>
          <div className="mt-2 text-sm font-semibold text-[#111111]">Availability</div>
          <div className="mt-1 text-[12px] text-muted-foreground">Available Now • Busy Today • Fully Booked</div>
          <div className="mt-3 inline-flex rounded-full bg-black/5 px-3 py-1 text-[11px] font-semibold text-[#111111]">Open</div>
        </div>
      </Link>

      <section className="grid grid-cols-2 gap-3">
        <Link href="/city/home-service" className="block">
          <div className="overflow-hidden rounded-[26px] border bg-white p-4 shadow-[0_18px_48px_rgba(17,17,17,0.10)]">
            <div className="text-[11px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">HOME</div>
            <div className="mt-2 text-sm font-semibold text-[#111111]">Service</div>
            <div className="mt-1 text-[12px] text-muted-foreground">Visit fee • distance</div>
            <div className="mt-3 inline-flex rounded-full bg-black/5 px-3 py-1 text-[11px] font-semibold text-[#111111]">Open</div>
          </div>
        </Link>
        <Link href="/city/health-score" className="block">
          <div className="overflow-hidden rounded-[26px] border bg-white p-4 shadow-[0_18px_48px_rgba(17,17,17,0.10)]">
            <div className="text-[11px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">SCORE</div>
            <div className="mt-2 text-sm font-semibold text-[#111111]">Health</div>
            <div className="mt-1 text-[12px] text-muted-foreground">0–100 dashboard</div>
            <div className="mt-3 inline-flex rounded-full bg-black/5 px-3 py-1 text-[11px] font-semibold text-[#111111]">Open</div>
          </div>
        </Link>
      </section>
    </>
  );
}

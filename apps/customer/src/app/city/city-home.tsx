import Link from "next/link";

import { Button } from "@hallaq/ui/button";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { SafeImage } from "@/components/safe-image";

import { CityHomeMore } from "./city-home-more";
import { CityFilters } from "./city-filters";
import { HeroCarousel } from "./hero-carousel";

export type CityHomeBarber = {
  id: string;
  display_name?: string | null;
  avatar_url?: string | null;
  rating_avg?: number | null;
  followers_count?: number | null;
};

export type CityHomeShop = {
  id: string;
  name?: string | null;
  area?: string | null;
  cover_url?: string | null;
  logo_url?: string | null;
  rating_avg?: number | null;
};

export type CityHomeReel = {
  id: string;
  caption?: string | null;
  thumbnail_url?: string | null;
  likes_count?: number | null;
  comments_count?: number | null;
};

export type CityHomeOffer = {
  id: string;
  title?: string | null;
  discount_percent?: number | null;
  valid_to?: string | null;
  barbershops?: { id: string; name?: string | null; cover_url?: string | null } | null;
};

export function CityHome({
  tTitle,
  tSubtitle,
  tSearchPlaceholder,
  heroItems,
  topBarbers,
  newShops,
  bestReels,
  offers,
  styles,
  hadDataErrors
}: {
  tTitle: string;
  tSubtitle: string;
  tSearchPlaceholder: string;
  heroItems: Array<{ id: string; title: string; subtitle: string; imageUrl: string; href: string; fallbackKey?: string }>;
  topBarbers: CityHomeBarber[];
  newShops: CityHomeShop[];
  bestReels: CityHomeReel[];
  offers: CityHomeOffer[];
  styles: Array<{ id: string; name: string; coverUrl: string | null; views: number }>;
  hadDataErrors: boolean;
}) {
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-5 px-4 pt-6 pb-24">
      <header className="flex flex-col gap-1">
        <div className="text-[13px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">{tTitle}</div>
        <div className="text-sm text-muted-foreground">{tSubtitle}</div>
      </header>

      <form action="/city/search" className="flex items-center gap-2">
        <input
          name="q"
          placeholder={tSearchPlaceholder}
          className="h-12 flex-1 rounded-[22px] border border-black/10 bg-white px-4 text-[13px] outline-none shadow-[0_10px_30px_rgba(17,17,17,0.05)] placeholder:text-muted-foreground focus:border-black/20"
        />
        <Button type="submit" className="h-12 rounded-[22px] px-4">
          Search
        </Button>
      </form>

      {heroItems.length ? (
        <HeroCarousel items={heroItems} />
      ) : (
        <div className="overflow-hidden rounded-[28px] border bg-white p-4 shadow-[0_22px_60px_rgba(17,17,17,0.10)]">
          <div className="text-[11px] font-semibold tracking-[0.24em] text-[hsl(var(--gold))]">HALLAQ CITY</div>
          <div className="mt-2 text-sm font-semibold text-[#111111]">Banners syncing</div>
          <div className="mt-1 text-[12px] text-muted-foreground">Admin banners will appear here once added.</div>
        </div>
      )}

      <CityFilters
        labels={{
          all: "All",
          barbers: "Barbers",
          shops: "Shops",
          styles: "Styles",
          offers: "Offers",
          awards: "Awards",
          reels: "Reels"
        }}
      />

      <section className="flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div className="text-sm font-semibold text-[#111111]">Trending This Week</div>
          <Link href="/city/trending" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
            View All
          </Link>
        </div>
        <div className="grid grid-cols-3 gap-3">
          {topBarbers.slice(0, 3).map((b, i) => (
            <Link key={b.id} href={`/barber/${encodeURIComponent(b.id)}`} className="block">
              <div className="relative overflow-hidden rounded-[22px] border bg-white shadow-[0_16px_36px_rgba(17,17,17,0.08)]">
                <div className="absolute left-2 top-2 z-10 grid h-6 w-6 place-items-center rounded-full bg-[hsl(var(--gold))] text-[11px] font-black text-[#111111]">
                  {i + 1}
                </div>
                <div className="aspect-square w-full overflow-hidden">
                  <SafeImage src={b.avatar_url} fallbackKey="default_barber_avatar" alt={b.display_name ?? "Barber"} className="h-full w-full object-cover" />
                </div>
                <div className="p-2">
                  <div className="text-[11px] font-semibold text-[#111111] line-clamp-1">{b.display_name ?? "Barber"}</div>
                  <div className="mt-0.5 text-[10px] text-muted-foreground">{Number(b.followers_count ?? 0).toLocaleString()} followers</div>
                </div>
              </div>
            </Link>
          ))}
        </div>
      </section>

      <section className="flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div className="text-sm font-semibold text-[#111111]">Top Barbers</div>
          <Link href="/city/barbers" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
            View All
          </Link>
        </div>

        <div className="grid grid-cols-3 gap-3">
          {topBarbers.slice(0, 6).map((b) => (
            <Link key={b.id} href={`/barber/${encodeURIComponent(b.id)}`} className="block">
              <div className="overflow-hidden rounded-[22px] border bg-white shadow-[0_16px_36px_rgba(17,17,17,0.08)]">
                <div className="aspect-square w-full overflow-hidden">
                  <SafeImage src={b.avatar_url} fallbackKey="default_barber_avatar" alt={b.display_name ?? "Barber"} className="h-full w-full object-cover" />
                </div>
                <div className="p-2">
                  <div className="text-[11px] font-semibold text-[#111111] line-clamp-1">{b.display_name ?? "Barber"}</div>
                  <div className="mt-0.5 flex items-center gap-1 text-[10px] text-muted-foreground">
                    <span className="inline-flex h-1 w-1 rounded-full bg-[hsl(var(--gold))]" />
                    <span>{Number(b.rating_avg ?? 0).toFixed(1)}</span>
                  </div>
                </div>
              </div>
            </Link>
          ))}
        </div>
      </section>

      <CityHomeMore newShops={newShops} bestReels={bestReels} offers={offers} styles={styles} />

      {hadDataErrors && (
        <div className="rounded-[26px] border bg-white p-4 text-sm text-muted-foreground">
          Some City sections are unavailable right now. Refresh to try again.
        </div>
      )}

      <CustomerBottomNav />
    </main>
  );
}

import Link from "next/link";
import { cookies } from "next/headers";

import { createAppSupabaseServerClient } from "@/lib/supabase";
import { signedOrUrl } from "@hallaq/supabase/storage";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { SafeImage } from "@/components/safe-image";
import { HomeHeader } from "./home-header";
import { HomeHeroCarousel, type HomeHeroSlide } from "./home-hero-carousel";
import { HomeSearchBar } from "./home-search-bar";
import { NearbyBarbersRow } from "./nearby-barbers-row";
import { NearbyShopsRow } from "./nearby-shops-row";
import { CalendarDays, Gift, Scissors, Sparkles, Store, Tag, Users } from "lucide-react";

export const dynamic = "force-dynamic";

type Shop = {
  id: string;
  name?: string | null;
  area?: string | null;
  address?: string | null;
  is_featured?: boolean | null;
  is_verified?: boolean | null;
  badge_verified?: boolean | null;
  status?: string | null;
  rating_avg?: number | null;
  rating_count?: number | null;
  logo_url?: string | null;
  cover_url?: string | null;
  logo_path?: string | null;
  cover_path?: string | null;
  lat?: number | null;
  lng?: number | null;
};

type Barber = {
  id: string;
  display_name?: string | null;
  shop_id?: string | null;
  avatar_url?: string | null;
  avatar_path?: string | null;
  lat?: number | null;
  lng?: number | null;
  rating_avg?: number | null;
  rating_count?: number | null;
};

type Reel = {
  id: string;
  caption?: string | null;
  media_url?: string | null;
  media_path?: string | null;
  media_type?: string | null;
  thumbnail_url?: string | null;
  thumbnail_path?: string | null;
  shop_id?: string | null;
  barber_id?: string | null;
};

type City = { id: string; name: string; country: string };

export default async function CustomerHomePage() {
  const supabase = await createAppSupabaseServerClient();
  const cookieStore = await cookies();
  const selectedCity = decodeURIComponent(cookieStore.get("hallaq_city")?.value ?? "Manama");
  const {
    data: { user }
  } = await supabase.auth.getUser();
  const unreadCount = user
    ? (
        await supabase
          .from("notifications")
          .select("id", { count: "exact", head: true })
          .eq("profile_id", user.id)
          .eq("read", false)
      ).count ?? 0
    : 0;
  const [{ data: citiesRaw }, { data: adsRaw }] = await Promise.all([
    supabase.from("cities").select("id, name, country").eq("is_active", true).order("sort_order", { ascending: true }).limit(50),
    supabase.from("advertisements").select("id, title, image_url, link_url").eq("active", true).order("created_at", { ascending: false }).limit(10),
  ]);

  const cities = (citiesRaw ?? []) as City[];
  const selectedCityRow = cities.find((c) => c.name.trim().toLowerCase() === selectedCity.trim().toLowerCase()) ?? cities[0];
  const selectedCityId = selectedCityRow?.id ?? null;

  const shopsQuery: Promise<{ data: unknown[] | null }> = (selectedCityId
    ? supabase
        .from("barbershops")
        .select(
          "id, name, area, address, status, is_verified, badge_verified, rating_avg, rating_count, logo_url, cover_url, logo_path, cover_path, lat, lng, city_id"
        )
        .is("deleted_at", null)
        .eq("status", "approved")
        .eq("city_id", selectedCityId)
        .order("created_at", { ascending: false })
        .limit(30)
    : supabase
        .from("barbershops")
        .select("id, name, area, address, status, is_verified, badge_verified, rating_avg, rating_count, logo_url, cover_url, logo_path, cover_path, lat, lng")
        .is("deleted_at", null)
        .eq("status", "approved")
        .ilike("area", `%${selectedCity}%`)
        .order("created_at", { ascending: false })
        .limit(30)) as unknown as Promise<{ data: unknown[] | null }>;

  const barbersQuery: Promise<{ data: unknown[] | null }> = (selectedCityId
    ? supabase
        .from("barbers")
        .select("id, display_name, shop_id, avatar_url, avatar_path, lat, lng, rating_avg, rating_count, city_id")
        .eq("city_id", selectedCityId)
        .order("created_at", { ascending: false })
        .limit(20)
    : supabase.from("barbers").select("id, display_name, shop_id, avatar_url, avatar_path, lat, lng, rating_avg, rating_count").order("created_at", { ascending: false }).limit(20)) as unknown as Promise<{ data: unknown[] | null }>;

  const [{ data: shopsRaw }, { data: barbersRaw }] = await Promise.all([shopsQuery, barbersQuery]);
  const { data: reelsRaw } = selectedCityId
    ? await supabase
        .from("posts")
        .select("id, caption, media_url, media_path, thumbnail_url, thumbnail_path, media_type, shop_id, barber_id, status, barbershops!left(city_id), barbers!left(city_id)")
        .eq("status", "approved")
        .eq("is_active", true)
        .not("media_url", "is", null)
        .is("deleted_at", null)
        .or(`barbershops.city_id.eq.${selectedCityId},barbers.city_id.eq.${selectedCityId}`)
        .order("created_at", { ascending: false })
        .limit(12)
    : await supabase
        .from("posts")
        .select("id, caption, media_url, media_path, thumbnail_url, thumbnail_path, media_type, shop_id, barber_id, status")
        .eq("status", "approved")
        .eq("is_active", true)
        .not("media_url", "is", null)
        .is("deleted_at", null)
        .order("created_at", { ascending: false })
        .limit(12);
  const ads = (adsRaw ?? []) as { id: string; title: string | null; image_url: string | null; link_url: string | null }[];
  const slides: HomeHeroSlide[] =
    ads.length > 0
      ? ads.map((a) => ({
          id: a.id,
          title: "Book your next",
          subtitle: (a.title ?? "Experience").trim() || "Experience",
          imageUrl: a.image_url,
          href: a.link_url?.trim() ? a.link_url!.trim() : "/booking/new",
          buttonText: "Book Now",
          fallbackKey: "default_home_hero_banner"
        }))
      : [
          {
            id: "fallback",
            title: "Book your next",
            subtitle: "Experience",
            imageUrl: null,
            href: "/booking/new",
            buttonText: "Book Now",
            fallbackKey: "default_home_hero_banner"
          }
        ];

  const shops = (shopsRaw ?? []) as Shop[];
  const nearbyShops = await Promise.all(
    shops.map(async (s) => {
      const cover = await signedOrUrl(supabase, "shop-images", s.cover_path ?? s.cover_url);
      return { ...s, cover_url: cover ?? s.cover_url };
    })
  );

  const topBarbers = await Promise.all(
    ((barbersRaw ?? []) as Barber[]).map(async (b) => {
      const avatar = await signedOrUrl(supabase, "barber-images", b.avatar_path ?? b.avatar_url);
      return { ...b, avatar_url: avatar ?? b.avatar_url };
    })
  );

  const reels = await Promise.all(
    ((reelsRaw ?? []) as Reel[]).map(async (r) => {
      const ref = r.thumbnail_path ?? r.thumbnail_url;
      const poster = ref ? (await signedOrUrl(supabase, "reels", ref)) ?? (await signedOrUrl(supabase, "reels-media", ref)) : null;
      return { ...r, media_url: poster ?? r.thumbnail_url ?? null };
    })
  );
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-5 bg-black px-4 py-6 pb-28 text-white">
      <HomeHeader cities={cities} selectedCity={selectedCity} unreadCount={unreadCount} />

      <HomeSearchBar placeholder="Search barbers, shops, styles…" />

      <HomeHeroCarousel slides={slides} />

      <section className="flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div className="text-sm font-bold">Quick Actions</div>
          <Link href="/city" className="text-xs font-semibold text-[#9E9E9E]">
            View All
          </Link>
        </div>
        <div className="flex gap-3 overflow-x-auto pb-1">
          {[
            { href: "/booking/new", label: "Book\nAppointment", Icon: CalendarDays },
            { href: "/city/barbers", label: "Find\nBarbers", Icon: Users },
            { href: "/city/shops/new", label: "Explore\nShops", Icon: Store },
            { href: "/city/styles", label: "Hair\nStyles", Icon: Scissors },
            { href: "/city/offers", label: "Offers\n& Deals", Icon: Tag },
            { href: "/city/ai-studio", label: "AI\nStudio", Icon: Sparkles },
            { href: "/city/gift-cards", label: "Gift\nCards", Icon: Gift }
          ].map(({ href, label, Icon }) => (
            <Link
              key={href}
              href={href}
              className="flex w-[92px] shrink-0 flex-col items-center justify-center gap-2 rounded-[24px] border border-[#2A2A2A] bg-[#111111] px-3 py-3 text-center shadow-[0_18px_44px_rgba(0,0,0,0.55)]"
            >
              <div className="grid h-11 w-11 place-items-center rounded-[18px] border border-[hsl(var(--gold))]/25 bg-[#1A1A1A]">
                <Icon className="h-5 w-5 text-[hsl(var(--gold))]" />
              </div>
              <div className="whitespace-pre-line text-[11px] font-extrabold leading-[1.15]">{label}</div>
            </Link>
          ))}
        </div>
      </section>

      <section className="flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div className="text-sm font-bold">Barbershop Near Me</div>
          <Link href="/city/shops/new" className="text-xs font-semibold text-[#9E9E9E]">
            View All
          </Link>
        </div>
        <NearbyShopsRow shops={nearbyShops} />
      </section>

      <section className="flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div className="text-sm font-bold">Barbers Near Me</div>
          <Link href="/city/barbers" className="text-xs font-semibold text-[#9E9E9E]">
            View All
          </Link>
        </div>
        <NearbyBarbersRow barbers={topBarbers} shops={nearbyShops} />
      </section>

      <section className="flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div className="text-sm font-bold">Reels For You</div>
          <Link href="/discover" className="text-xs font-semibold text-[#9E9E9E]">
            View All
          </Link>
        </div>
        <div className="flex gap-3 overflow-x-auto pb-1">
          {reels.slice(0, 10).map((r) => (
            <Link key={r.id} href="/discover" className="block w-[84px] shrink-0 overflow-hidden rounded-[22px] border border-[#2A2A2A] bg-[#111111]">
              <div className="relative aspect-[9/16] w-full overflow-hidden">
                <SafeImage src={r.media_url ?? null} fallbackKey="default_reel_thumbnail" alt={r.caption ?? "Reel"} className="h-full w-full object-cover" />
                <div className="absolute left-2 top-2 grid h-7 w-7 place-items-center rounded-full border border-white/10 bg-black/35 text-white">
                  ▶
                </div>
              </div>
            </Link>
          ))}
        </div>
      </section>

      <CustomerBottomNav />
    </main>
  );
}

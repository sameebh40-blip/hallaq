import Link from "next/link";

import { signedOrUrl } from "@hallaq/supabase/storage";
import { getServerLocale, getT } from "@hallaq/ui/translations-server";
import { cn } from "@hallaq/ui/cn";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { RealtimeRefresh } from "@/components/realtime-refresh";
import { SafeImage } from "@/components/safe-image";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type Tab = "overview" | "reels" | "barbers" | "shops";

function tabFromParam(value: string | undefined): Tab {
  if (value === "reels") return "reels";
  if (value === "barbers") return "barbers";
  if (value === "shops") return "shops";
  return "overview";
}

type StyleMediaRow = {
  media_type?: unknown;
  image_url?: unknown;
  image_path?: unknown;
  post_id?: unknown;
};

type StyleBarberJoinRow = {
  barbers: Record<string, unknown> | null;
};

type StyleShopJoinRow = {
  barbershops: Record<string, unknown> | null;
};

function pickString(...values: unknown[]): string | null {
  for (const v of values) {
    if (typeof v === "string") {
      const t = v.trim();
      if (t) return t;
    }
  }
  return null;
}

export default async function CityStyleDetailsPage({
  params,
  searchParams
}: {
  params: Promise<{ id: string }>;
  searchParams?: Promise<{ tab?: string }>;
}) {
  const t = await getT();
  const locale = await getServerLocale();
  const { id } = await params;
  const sp = searchParams ? await searchParams : undefined;
  const tab = tabFromParam(sp?.tab);

  const supabase = await createAppSupabaseServerClient();

  const { data: styleRow, error: styleError } = await supabase
    .from("style_library")
    .select("id, name_en, name_ar, description_en, description_ar, category, ai_style_key, cover_url, cover_path, views_count")
    .eq("id", id)
    .eq("is_active", true)
    .eq("status", "approved")
    .maybeSingle();

  if (!styleRow || styleError) {
    return (
      <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 px-4 pt-6 pb-24">
        <header className="flex items-center justify-between">
          <div className="flex flex-col gap-1">
            <div className="text-[13px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">{t("customer.city.title")}</div>
            <div className="text-sm font-semibold text-[#111111]">Style</div>
          </div>
          <Link href="/city/styles" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
            Back
          </Link>
        </header>
        <div className="rounded-[26px] border bg-white p-4 text-sm text-muted-foreground">Style is unavailable right now.</div>
        <CustomerBottomNav />
      </main>
    );
  }

  const name = locale === "en" ? styleRow.name_en : styleRow.name_ar || styleRow.name_en;
  const desc = locale === "en" ? styleRow.description_en : styleRow.description_ar || styleRow.description_en;

  const coverSigned = await signedOrUrl(supabase, "style-library", styleRow.cover_path ?? styleRow.cover_url);
  const coverUrl = typeof coverSigned === "string" ? coverSigned.trim() : "";

  const [{ data: media }, { data: recommendedBarbers }, { data: styleBarbers }, { data: styleShops }] = await Promise.all([
    supabase
      .from("style_media")
      .select("id, media_type, image_url, image_path, post_id, sort_order")
      .eq("style_id", styleRow.id)
      .order("sort_order", { ascending: true })
      .limit(40),
    supabase
      .from("barbers")
      .select("id, display_name, avatar_url, avatar_path, rating_avg")
      .eq("status", "approved")
      .eq("is_active", true)
      .is("deleted_at", null)
      .order("rating_avg", { ascending: false })
      .limit(10),
    supabase
      .from("style_barbers")
      .select("barber_id, barbers(id, display_name, avatar_url, avatar_path, rating_avg, followers_count, is_verified)")
      .eq("style_id", styleRow.id)
      .limit(30),
    supabase
      .from("style_shops")
      .select("shop_id, barbershops(id, name, area, logo_url, logo_path, rating_avg)")
      .eq("style_id", styleRow.id)
      .limit(30)
  ]);

  const mediaRows = (media ?? []) as unknown as StyleMediaRow[];
  const gallery = await Promise.all(
    mediaRows
      .filter((m) => m.media_type === "image")
      .slice(0, 9)
      .map(async (m) => {
        const signed = await signedOrUrl(supabase, "style-library", pickString(m.image_path, m.image_url));
        return (typeof signed === "string" ? signed.trim() : "") || coverUrl || null;
      })
  );

  const styleBarberRows = (styleBarbers ?? []) as unknown as StyleBarberJoinRow[];
  const styleShopRows = (styleShops ?? []) as unknown as StyleShopJoinRow[];

  const barbersForTabRaw = styleBarberRows.map((r) => r.barbers).filter(Boolean) as Array<Record<string, unknown>>;
  const shopsForTabRaw = styleShopRows.map((r) => r.barbershops).filter(Boolean) as Array<Record<string, unknown>>;

  const barbersForTab = await Promise.all(
    barbersForTabRaw.map(async (b) => {
      const avatar = await signedOrUrl(supabase, "barber-images", pickString(b.avatar_path, b.avatar_url));
      return {
        id: String(b.id),
        name: String(b.display_name ?? "Barber"),
        avatarUrl: typeof avatar === "string" ? avatar.trim() : null,
        rating: Number(b.rating_avg ?? 0),
        followers: Number(b.followers_count ?? 0),
        verified: Boolean(b.is_verified ?? false)
      };
    })
  );

  const shopsForTab = await Promise.all(
    shopsForTabRaw.map(async (s) => {
      const logo = await signedOrUrl(supabase, "shop-images", pickString(s.logo_path, s.logo_url));
      return {
        id: String(s.id),
        name: String(s.name ?? "Shop"),
        area: String(s.area ?? "").trim(),
        logoUrl: typeof logo === "string" ? logo.trim() : null,
        rating: Number(s.rating_avg ?? 0)
      };
    })
  );

  const fallbackRecommended = await Promise.all(
    ((recommendedBarbers ?? []) as Array<Record<string, unknown>>).slice(0, 8).map(async (b) => {
      const avatar = await signedOrUrl(supabase, "barber-images", pickString(b.avatar_path, b.avatar_url));
      return {
        id: String(b.id),
        name: String(b.display_name ?? "Barber"),
        avatarUrl: typeof avatar === "string" ? avatar.trim() : null,
        rating: Number(b.rating_avg ?? 0),
        followers: 0,
        verified: false
      };
    })
  );

  const postIds = mediaRows
    .filter((m) => m.media_type === "post" && pickString(m.post_id))
    .map((m) => pickString(m.post_id) as string)
    .slice(0, 30);

  const { data: posts } = postIds.length
    ? await supabase
        .from("posts")
        .select("id, caption, thumbnail_url, thumbnail_path, media_url, media_path, likes_count, comments_count, status, deleted_at")
        .in("id", postIds)
        .eq("status", "approved")
        .eq("is_active", true)
        .not("media_url", "is", null)
        .is("deleted_at", null)
        .limit(30)
    : { data: [] as unknown[] };

  const reels = await Promise.all(
    ((posts ?? []) as Array<Record<string, unknown>>).map(async (r) => {
      const ref = String(r.thumbnail_path ?? r.thumbnail_url ?? "").trim() || null;
      const poster = ref
        ? (await signedOrUrl(supabase, "reels", ref)) ??
          (await signedOrUrl(supabase, "reels-media", ref)) ??
          (await signedOrUrl(supabase, "post-media", ref))
        : null;
      return {
        id: String(r.id),
        caption: String(r.caption ?? "Reel"),
        posterUrl: typeof poster === "string" ? poster.trim() : null,
        likes: Number(r.likes_count ?? 0),
        comments: Number(r.comments_count ?? 0)
      };
    })
  );

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 px-4 pt-6 pb-24">
      <RealtimeRefresh tables={["style_library", "style_media", "style_barbers", "style_shops", "barbers", "barbershops", "posts"]} />
      <header className="flex items-center justify-between">
        <div className="flex flex-col gap-1">
          <div className="text-[13px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">{t("customer.city.title")}</div>
          <div className="text-sm font-semibold text-[#111111]">{name}</div>
        </div>
        <Link href="/city/styles" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
          Back
        </Link>
      </header>

      <div className="flex gap-2 overflow-x-auto pb-1">
        {([
          { key: "overview", label: "Overview" },
          { key: "reels", label: "Reels" },
          { key: "barbers", label: "Barbers" },
          { key: "shops", label: "Shops" }
        ] as Array<{ key: Tab; label: string }>).map((x) => {
          const active = x.key === tab;
          const href = x.key === "overview" ? `/city/styles/${encodeURIComponent(styleRow.id)}` : `/city/styles/${encodeURIComponent(styleRow.id)}?tab=${encodeURIComponent(x.key)}`;
          return (
            <Link
              key={x.key}
              href={href}
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

      {tab === "overview" ? (
        <>
          <div className="overflow-hidden rounded-[28px] border bg-white shadow-[0_22px_60px_rgba(17,17,17,0.10)]">
            <div className="aspect-[16/10] w-full overflow-hidden">
              <SafeImage src={coverUrl} fallbackKey="default_style_image" alt={name} className="h-full w-full object-cover" />
            </div>
            <div className="p-4">
              <div className="text-sm font-semibold text-[#111111]">Overview</div>
              <div className="mt-1 text-[13px] text-muted-foreground">{(desc ?? "").trim() || "A premium style with clean detailing and a Bahrain-ready finish."}</div>
              <div className="mt-3 grid grid-cols-3 gap-2">
                <div className="rounded-[20px] bg-black/5 px-3 py-2 text-center">
                  <div className="text-[10px] font-semibold text-muted-foreground">Category</div>
                  <div className="mt-0.5 text-[12px] font-semibold text-[#111111]">{String(styleRow.category ?? "Style")}</div>
                </div>
                <div className="rounded-[20px] bg-black/5 px-3 py-2 text-center">
                  <div className="text-[10px] font-semibold text-muted-foreground">Views</div>
                  <div className="mt-0.5 text-[12px] font-semibold text-[#111111]">{Number(styleRow.views_count ?? 0).toLocaleString()}</div>
                </div>
                <Link
                  href={styleRow.ai_style_key ? `/city/ai-studio?style=${encodeURIComponent(styleRow.ai_style_key)}` : "/city/ai-studio"}
                  className="grid rounded-[20px] bg-[hsl(var(--gold))] px-3 py-2 text-center shadow-[0_14px_34px_rgba(212,175,55,0.22)]"
                >
                  <div className="text-[10px] font-semibold text-black/60">AI</div>
                  <div className="mt-0.5 text-[12px] font-semibold text-[#111111]">Preview</div>
                </Link>
              </div>
            </div>
          </div>

          <section className="flex flex-col gap-3">
            <div className="flex items-center justify-between">
              <div className="text-sm font-semibold text-[#111111]">Gallery</div>
            </div>
            <div className="grid grid-cols-3 gap-2">
              {(gallery.length ? gallery : [coverUrl, coverUrl, coverUrl]).slice(0, 9).map((url, idx) => (
                <div key={`${styleRow.id}:g:${idx}`} className="overflow-hidden rounded-[20px] border bg-white">
                  <SafeImage src={url} fallbackKey="default_style_image" alt="" className="aspect-square h-full w-full object-cover" />
                </div>
              ))}
            </div>
          </section>

          <section className="flex flex-col gap-3">
            <div className="flex items-center justify-between">
              <div className="text-sm font-semibold text-[#111111]">Popular Barbers</div>
              <Link href="/city/barbers" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
                View All
              </Link>
            </div>
            <div className="flex gap-3 overflow-x-auto pb-1">
              {(barbersForTab.length ? barbersForTab : fallbackRecommended).slice(0, 10).map((b) => (
                <Link key={b.id} href={`/barber/${encodeURIComponent(b.id)}`} className="block w-[140px] shrink-0">
                  <div className="overflow-hidden rounded-[24px] border bg-white shadow-[0_16px_36px_rgba(17,17,17,0.08)]">
                    <div className="aspect-[4/3] w-full overflow-hidden">
                      <SafeImage src={b.avatarUrl} fallbackKey="default_barber_avatar" alt={b.name} className="h-full w-full object-cover" />
                    </div>
                    <div className="p-3">
                      <div className="text-[12px] font-semibold text-[#111111] line-clamp-1">{b.name}</div>
                      <div className="mt-1 text-[11px] text-muted-foreground">★ {Number(b.rating ?? 0).toFixed(1)}</div>
                    </div>
                  </div>
                </Link>
              ))}
            </div>
          </section>

          <div className="grid grid-cols-2 gap-3">
            <Link
              href="/booking/new"
              className="grid h-12 place-items-center rounded-[22px] bg-black/5 text-[13px] font-semibold text-[#111111]"
            >
              Book Now
            </Link>
            <Link
              href={styleRow.ai_style_key ? `/city/ai-studio?style=${encodeURIComponent(styleRow.ai_style_key)}` : "/city/ai-studio"}
              className="grid h-12 place-items-center rounded-[22px] bg-[hsl(var(--gold))] text-[13px] font-semibold text-[#111111] shadow-[0_18px_42px_rgba(212,175,55,0.25)]"
            >
              Try in AI
            </Link>
          </div>
        </>
      ) : null}

      {tab === "reels" ? (
        <section className="flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <div className="text-sm font-semibold text-[#111111]">Reels</div>
            <Link href="/city/reels" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
              Open viewer
            </Link>
          </div>
          {reels.length ? (
            <div className="grid grid-cols-2 gap-3">
              {reels.map((r) => (
                <Link key={r.id} href="/city/reels" className="block">
                  <div className="relative overflow-hidden rounded-[24px] border bg-white shadow-[0_16px_36px_rgba(17,17,17,0.08)]">
                    <div className="aspect-[9/16] w-full overflow-hidden">
                      <SafeImage src={r.posterUrl} fallbackKey="default_reel_thumbnail" alt={r.caption} className="h-full w-full object-cover" />
                    </div>
                    <div className="absolute inset-x-0 bottom-0 flex items-center justify-between gap-2 bg-gradient-to-t from-black/65 via-black/15 to-transparent p-3 text-[11px] font-semibold text-white">
                      <div className="flex items-center gap-2">
                        <span>♥ {r.likes}</span>
                        <span>💬 {r.comments}</span>
                      </div>
                      <span className="rounded-full bg-white/14 px-2 py-1 text-[10px] backdrop-blur">Play</span>
                    </div>
                  </div>
                </Link>
              ))}
            </div>
          ) : (
            <div className="rounded-[26px] border bg-white p-4 text-sm text-muted-foreground">No reels linked to this style yet.</div>
          )}
        </section>
      ) : null}

      {tab === "barbers" ? (
        <section className="flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <div className="text-sm font-semibold text-[#111111]">Barbers</div>
          </div>
          {(barbersForTab.length ? barbersForTab : fallbackRecommended).length ? (
            <div className="flex flex-col gap-3">
              {(barbersForTab.length ? barbersForTab : fallbackRecommended).map((b) => (
                <div key={b.id} className="flex items-center gap-3 overflow-hidden rounded-[26px] border bg-white p-3 shadow-[0_16px_36px_rgba(17,17,17,0.08)]">
                  <Link href={`/barber/${encodeURIComponent(b.id)}`} className="h-12 w-12 shrink-0 overflow-hidden rounded-2xl border bg-white">
                    <SafeImage src={b.avatarUrl} fallbackKey="default_barber_avatar" alt={b.name} className="h-full w-full object-cover" />
                  </Link>
                  <div className="flex flex-1 flex-col">
                    <div className="flex items-center justify-between gap-2">
                      <Link href={`/barber/${encodeURIComponent(b.id)}`} className="text-[12px] font-semibold text-[#111111] line-clamp-1">
                        {b.name}
                      </Link>
                      {b.verified ? (
                        <div className="rounded-full bg-[hsl(var(--gold))/0.14] px-2 py-1 text-[10px] font-semibold text-[#111111]">Verified</div>
                      ) : null}
                    </div>
                    <div className="mt-0.5 text-[11px] text-muted-foreground">★ {Number(b.rating ?? 0).toFixed(1)}</div>
                    <div className="mt-3 grid grid-cols-2 gap-2">
                      <Link href={`/barber/${encodeURIComponent(b.id)}`} className="grid h-10 place-items-center rounded-[18px] bg-black/5 text-[11px] font-semibold text-[#111111]">
                        Profile
                      </Link>
                      <Link
                        href={`/booking/new?barberId=${encodeURIComponent(b.id)}`}
                        className="grid h-10 place-items-center rounded-[18px] bg-[hsl(var(--gold))] text-[11px] font-semibold text-[#111111] shadow-[0_14px_34px_rgba(212,175,55,0.22)]"
                      >
                        Book
                      </Link>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="rounded-[26px] border bg-white p-4 text-sm text-muted-foreground">No barbers linked yet.</div>
          )}
        </section>
      ) : null}

      {tab === "shops" ? (
        <section className="flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <div className="text-sm font-semibold text-[#111111]">Shops</div>
          </div>
          {shopsForTab.length ? (
            <div className="flex flex-col gap-3">
              {shopsForTab.map((s) => (
                <div key={s.id} className="flex items-center gap-3 overflow-hidden rounded-[26px] border bg-white p-3 shadow-[0_16px_36px_rgba(17,17,17,0.08)]">
                  <Link href={`/shop/${encodeURIComponent(s.id)}`} className="h-12 w-12 shrink-0 overflow-hidden rounded-2xl border bg-white">
                    <SafeImage src={s.logoUrl} fallbackKey="default_shop_logo" alt="" className="h-full w-full object-cover" />
                  </Link>
                  <div className="flex flex-1 flex-col">
                    <Link href={`/shop/${encodeURIComponent(s.id)}`} className="text-[12px] font-semibold text-[#111111] line-clamp-1">
                      {s.name}
                    </Link>
                    <div className="mt-0.5 text-[11px] text-muted-foreground line-clamp-1">{s.area}</div>
                    <div className="mt-1 text-[11px] font-semibold text-[#111111]">★ {s.rating.toFixed(1)}</div>
                    <div className="mt-3 grid grid-cols-2 gap-2">
                      <Link href={`/shop/${encodeURIComponent(s.id)}`} className="grid h-10 place-items-center rounded-[18px] bg-black/5 text-[11px] font-semibold text-[#111111]">
                        Profile
                      </Link>
                      <Link
                        href={`/booking/new?shopId=${encodeURIComponent(s.id)}`}
                        className="grid h-10 place-items-center rounded-[18px] bg-[hsl(var(--gold))] text-[11px] font-semibold text-[#111111] shadow-[0_14px_34px_rgba(212,175,55,0.22)]"
                      >
                        Book
                      </Link>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="rounded-[26px] border bg-white p-4 text-sm text-muted-foreground">No shops linked yet.</div>
          )}
        </section>
      ) : null}

      <CustomerBottomNav />
    </main>
  );
}

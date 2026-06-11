import Link from "next/link";

import { signedOrUrl } from "@hallaq/supabase/storage";
import { getT } from "@hallaq/ui/translations-server";
import { cn } from "@hallaq/ui/cn";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { RealtimeRefresh } from "@/components/realtime-refresh";
import { SafeImage } from "@/components/safe-image";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type SortKey = "topRated" | "mostFollowed" | "new";

function safeUrl(url: unknown, fallback: string) {
  const u = typeof url === "string" ? url.trim() : "";
  return u || fallback;
}

function sortFromParam(value: string | undefined): SortKey {
  if (value === "most-followed") return "mostFollowed";
  if (value === "new") return "new";
  return "topRated";
}

export default async function CityBarbersPage({ searchParams }: { searchParams: Promise<{ sort?: string }> }) {
  const t = await getT();
  const params = await searchParams;
  const sort = sortFromParam(params.sort);
  const supabase = await createAppSupabaseServerClient();

  const order = sort === "mostFollowed" ? "followers_count" : sort === "new" ? "created_at" : "rating_avg";

  const { data: barbers, error } = await supabase
    .from("barbers")
    .select("id, display_name, avatar_url, avatar_path, cover_url, cover_path, rating_avg, followers_count, is_verified, status, created_at")
    .eq("status", "approved")
    .eq("is_active", true)
    .is("deleted_at", null)
    .order(order, { ascending: false })
    .limit(60);

  const list = await Promise.all(
    ((barbers ?? []) as Array<Record<string, unknown>>).map(async (b) => {
      const avatar = await signedOrUrl(supabase, "barber-images", String(b.avatar_path ?? b.avatar_url ?? "").trim() || null);
      return {
        id: String(b.id),
        name: String(b.display_name ?? "Barber"),
        avatarUrl: safeUrl(avatar, ""),
        rating: Number(b.rating_avg ?? 0),
        followers: Number(b.followers_count ?? 0),
        verified: Boolean(b.is_verified ?? false)
      };
    })
  );

  const chips: Array<{ key: SortKey; label: string; href: string }> = [
    { key: "topRated", label: "Top Rated", href: "/city/barbers?sort=top-rated" },
    { key: "mostFollowed", label: "Trending", href: "/city/barbers?sort=most-followed" },
    { key: "new", label: "Rising Star", href: "/city/barbers?sort=new" }
  ];

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 pt-6 pb-24 text-white">
      <RealtimeRefresh tables={["barbers", "follows"]} />
      <header className="flex items-center justify-between">
        <div className="flex flex-col gap-1">
          <div className="text-[13px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">{t("customer.city.title")}</div>
          <div className="text-sm font-semibold text-white">Top Barbers</div>
        </div>
        <Link href="/city" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
          Back
        </Link>
      </header>

      <div className="flex gap-2 overflow-x-auto pb-1">
        {chips.map((c) => {
          const active = c.key === sort;
          return (
            <Link
              key={c.key}
              href={c.href}
              className={cn(
                "shrink-0 rounded-full border px-3 py-2 text-[12px] font-semibold leading-none transition",
                active
                  ? "border-[hsl(var(--gold))] bg-[hsl(var(--gold))/0.10] text-white"
                  : "border-[#2A2A2A] bg-[#111111] text-muted-foreground hover:border-[#3A3A3A]"
              )}
            >
              {c.label}
            </Link>
          );
        })}
      </div>

      {error ? (
        <div className="rounded-[26px] border border-[#2A2A2A] bg-[#111111] p-4 text-sm text-muted-foreground">
          Could not load barbers right now.
        </div>
      ) : null}

      <div className="grid grid-cols-2 gap-3">
        {list.map((b, i) => (
          <div key={b.id} className="relative overflow-hidden rounded-[26px] border border-[#2A2A2A] bg-[#111111] shadow-[0_16px_36px_rgba(0,0,0,0.35)]">
            <div className="absolute left-3 top-3 z-10 grid h-7 w-7 place-items-center rounded-full bg-black/70 text-[11px] font-black text-white shadow-[0_10px_24px_rgba(0,0,0,0.35)]">
              {i + 1}
            </div>
            <Link href={`/barber/${encodeURIComponent(b.id)}`} className="block">
              <div className="aspect-[4/5] w-full overflow-hidden">
                <SafeImage src={b.avatarUrl} fallbackKey="default_barber_avatar" alt={b.name} className="h-full w-full object-cover" />
              </div>
            </Link>
            <div className="p-3">
              <div className="flex items-center gap-2">
                <Link href={`/barber/${encodeURIComponent(b.id)}`} className="flex-1 text-[12px] font-semibold text-white line-clamp-1">
                  {b.name}
                </Link>
                {b.verified ? (
                  <div className="rounded-full bg-[hsl(var(--gold))/0.14] px-2 py-1 text-[10px] font-semibold text-[hsl(var(--gold))]">Verified</div>
                ) : null}
              </div>
              <div className="mt-1 flex items-center justify-between text-[11px] text-muted-foreground">
                <span>★ {b.rating.toFixed(1)}</span>
                <span>{b.followers.toLocaleString()} followers</span>
              </div>
              <div className="mt-3 grid grid-cols-2 gap-2">
                <Link
                  href={`/barber/${encodeURIComponent(b.id)}`}
                  className="rounded-[18px] border border-[#2A2A2A] bg-black/30 px-3 py-2 text-center text-[11px] font-semibold text-white"
                >
                  Profile
                </Link>
                <Link
                  href={`/booking/new?barberId=${encodeURIComponent(b.id)}`}
                  className="rounded-[18px] bg-[hsl(var(--gold))] px-3 py-2 text-center text-[11px] font-semibold text-[#111111] shadow-[0_14px_34px_rgba(212,175,55,0.22)]"
                >
                  Book
                </Link>
              </div>
            </div>
          </div>
        ))}
      </div>

      <CustomerBottomNav />
    </main>
  );
}

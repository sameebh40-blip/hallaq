import Link from "next/link";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type ShopRow = {
  id: string;
  name: string | null;
  logo_url: string | null;
  logo_path: string | null;
  cover_url: string | null;
  cover_path: string | null;
  area: string | null;
  address: string | null;
  phone: string | null;
  status: string | null;
  created_at: string;
};

type ScoreRow = {
  id: string;
  name: string;
  score: number;
  missing: string[];
};

export default async function ShopHealthPage() {
  const supabase = await createSupabaseServerClient();

  const { data: shopsRaw } = await supabase
    .from("barbershops")
    .select("id, name, logo_url, logo_path, cover_url, cover_path, area, address, phone, status, created_at")
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(200);

  const shops = (shopsRaw ?? []) as unknown as ShopRow[];
  const shopIds = shops.map((s) => s.id);

  const now = new Date();
  const start30 = new Date(now);
  start30.setUTCDate(start30.getUTCDate() - 30);

  const [servicesRaw, productsRaw, reelsRaw, reviewsRaw, bookingsRaw] = await Promise.all([
    shopIds.length ? supabase.from("services").select("id, shop_id").in("shop_id", shopIds).is("deleted_at", null).limit(50000) : Promise.resolve({ data: [] }),
    shopIds.length ? supabase.from("products").select("id, shop_id").in("shop_id", shopIds).is("deleted_at", null).limit(50000) : Promise.resolve({ data: [] }),
    shopIds.length ? supabase.from("reels").select("id, shop_id").in("shop_id", shopIds).is("deleted_at", null).limit(50000) : Promise.resolve({ data: [] }),
    shopIds.length
      ? supabase
          .from("reviews")
          .select("id, target_id")
          .eq("target_type", "shop")
          .in("target_id", shopIds as unknown as string[])
          .limit(50000)
      : Promise.resolve({ data: [] }),
    shopIds.length
      ? supabase
          .from("bookings")
          .select("id, shop_id, status, created_at")
          .in("shop_id", shopIds)
          .gte("created_at", start30.toISOString())
          .limit(50000)
      : Promise.resolve({ data: [] })
  ]);

  const countBy = (rows: Array<Record<string, unknown>>, key: string) => {
    const m = new Map<string, number>();
    for (const r of rows) {
      const k = String(r[key] ?? "").trim();
      if (!k) continue;
      m.set(k, (m.get(k) ?? 0) + 1);
    }
    return m;
  };

  const servicesByShop = countBy((servicesRaw.data ?? []) as Array<Record<string, unknown>>, "shop_id");
  const productsByShop = countBy((productsRaw.data ?? []) as Array<Record<string, unknown>>, "shop_id");
  const reelsByShop = countBy((reelsRaw.data ?? []) as Array<Record<string, unknown>>, "shop_id");
  const reviewsByShop = countBy((reviewsRaw.data ?? []) as Array<Record<string, unknown>>, "target_id");

  const bookingsByShop = new Map<string, { total: number; completed: number }>();
  for (const r of (bookingsRaw.data ?? []) as Array<Record<string, unknown>>) {
    const shopId = String(r.shop_id ?? "").trim();
    if (!shopId) continue;
    const st = String(r.status ?? "").trim();
    const cur = bookingsByShop.get(shopId) ?? { total: 0, completed: 0 };
    cur.total += 1;
    if (st === "completed") cur.completed += 1;
    bookingsByShop.set(shopId, cur);
  }

  const scoreRows: ScoreRow[] = shops.map((s) => {
    const missing: string[] = [];

    const hasLogo = Boolean((s.logo_path ?? "").trim() || (s.logo_url ?? "").trim());
    const hasCover = Boolean((s.cover_path ?? "").trim() || (s.cover_url ?? "").trim());
    const svcCount = servicesByShop.get(s.id) ?? 0;
    const prodCount = productsByShop.get(s.id) ?? 0;
    const reelCount = reelsByShop.get(s.id) ?? 0;
    const reviewCount = reviewsByShop.get(s.id) ?? 0;
    const booking = bookingsByShop.get(s.id) ?? { total: 0, completed: 0 };

    const profileComplete = Boolean((s.name ?? "").trim() && (s.area ?? "").trim() && (s.address ?? "").trim() && (s.phone ?? "").trim());

    const w = {
      logo: 10,
      cover: 10,
      services: 15,
      products: 10,
      reels: 10,
      reviews: 10,
      bookingCompletion: 20,
      profile: 15
    };

    let score = 0;
    if (hasLogo) score += w.logo;
    else missing.push("logo");
    if (hasCover) score += w.cover;
    else missing.push("cover");
    if (svcCount > 0) score += w.services;
    else missing.push("services");
    if (prodCount > 0) score += w.products;
    else missing.push("products");
    if (reelCount > 0) score += w.reels;
    else missing.push("reels");
    if (reviewCount > 0) score += w.reviews;
    else missing.push("reviews");

    const completionRate = booking.total > 0 ? booking.completed / booking.total : 0;
    if (completionRate >= 0.7) score += w.bookingCompletion;
    else {
      score += Math.round(w.bookingCompletion * completionRate);
      missing.push("booking completion");
    }

    if (profileComplete) score += w.profile;
    else missing.push("profile completeness");

    return { id: s.id, name: (s.name ?? "").trim() || "Shop", score: Math.max(0, Math.min(100, score)), missing };
  });

  scoreRows.sort((a, b) => a.score - b.score);

  return (
    <PageFrame
      title="Shop Health Score"
      subtitle="Score 0–100 per shop based on images, catalog, reels, reviews, bookings, and profile completeness."
      actions={
        <Button asChild size="sm" variant="secondary">
          <Link href="/missing-images">Missing Images</Link>
        </Button>
      }
    >
      {scoreRows.length ? (
        <div className="flex flex-col gap-3">
          {scoreRows.map((s) => (
            <LuxuryCard key={s.id} className="border border-white/10 bg-white/5 p-4">
              <div className="flex flex-col gap-2">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div className="flex flex-col gap-0.5">
                    <div className="text-sm font-semibold">{s.name}</div>
                    <div className="text-[11px] text-muted-foreground">{s.id}</div>
                  </div>
                  <div className="text-2xl font-semibold tracking-tight">{s.score}</div>
                </div>
                <div className="text-xs text-muted-foreground">
                  Missing: {s.missing.length ? s.missing.join(", ") : "—"}
                </div>
                <div className="flex items-center gap-2 pt-1">
                  <Button asChild size="sm" variant="secondary">
                    <Link href={`/stores/${encodeURIComponent(s.id)}`}>Open Shop</Link>
                  </Button>
                  <Button asChild size="sm" variant="ghost">
                    <Link href="/missing-images">Fix</Link>
                  </Button>
                </div>
              </div>
            </LuxuryCard>
          ))}
        </div>
      ) : (
        <div className="text-sm text-muted-foreground">No shops found.</div>
      )}
    </PageFrame>
  );
}


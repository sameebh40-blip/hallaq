import Link from "next/link";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type BarberRow = {
  id: string;
  profile_id: string | null;
  display_name: string | null;
  avatar_url: string | null;
  avatar_path: string | null;
  cover_url: string | null;
  cover_path: string | null;
  area: string | null;
  slug: string | null;
  bio: string | null;
  created_at: string;
};

type ScoreRow = {
  id: string;
  name: string;
  score: number;
  missing: string[];
};

export default async function BarberHealthPage() {
  const supabase = await createSupabaseServerClient();

  const { data: barbersRaw } = await supabase
    .from("barbers")
    .select("id, profile_id, display_name, avatar_url, avatar_path, cover_url, cover_path, area, slug, bio, created_at")
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(200);

  const barbers = (barbersRaw ?? []) as unknown as BarberRow[];
  const barberIds = barbers.map((b) => b.id);

  const now = new Date();
  const start30 = new Date(now);
  start30.setUTCDate(start30.getUTCDate() - 30);

  const [portfolioRaw, reelsRaw, reviewsRaw, bookingsRaw, workingHoursRaw, servicesEffRaw] = await Promise.all([
    barberIds.length ? supabase.from("portfolio_items").select("id, barber_id").in("barber_id", barberIds).is("deleted_at", null).limit(50000) : Promise.resolve({ data: [] }),
    barberIds.length ? supabase.from("reels").select("id, barber_id").in("barber_id", barberIds).is("deleted_at", null).limit(50000) : Promise.resolve({ data: [] }),
    barberIds.length
      ? supabase.from("reviews").select("id, target_id").eq("target_type", "barber").in("target_id", barberIds as unknown as string[]).limit(50000)
      : Promise.resolve({ data: [] }),
    barberIds.length
      ? supabase
          .from("bookings")
          .select("id, barber_id, status, created_at")
          .in("barber_id", barberIds)
          .gte("created_at", start30.toISOString())
          .limit(50000)
      : Promise.resolve({ data: [] }),
    barberIds.length ? supabase.from("barber_working_hours").select("id, barber_id, enabled").in("barber_id", barberIds).limit(50000) : Promise.resolve({ data: [] }),
    barberIds.length ? supabase.from("barber_services_effective").select("id, barber_ref").in("barber_ref", barberIds).limit(50000) : Promise.resolve({ data: [] })
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

  const portfolioByBarber = countBy((portfolioRaw.data ?? []) as Array<Record<string, unknown>>, "barber_id");
  const reelsByBarber = countBy((reelsRaw.data ?? []) as Array<Record<string, unknown>>, "barber_id");
  const reviewsByBarber = countBy((reviewsRaw.data ?? []) as Array<Record<string, unknown>>, "target_id");

  const bookingsByBarber = new Map<string, { total: number; completed: number }>();
  for (const r of (bookingsRaw.data ?? []) as Array<Record<string, unknown>>) {
    const barberId = String(r.barber_id ?? "").trim();
    if (!barberId) continue;
    const st = String(r.status ?? "").trim();
    const cur = bookingsByBarber.get(barberId) ?? { total: 0, completed: 0 };
    cur.total += 1;
    if (st === "completed") cur.completed += 1;
    bookingsByBarber.set(barberId, cur);
  }

  const workingByBarber = new Set<string>();
  for (const r of (workingHoursRaw.data ?? []) as Array<Record<string, unknown>>) {
    const barberId = String(r.barber_id ?? "").trim();
    const enabled = Boolean(r.enabled ?? true);
    if (barberId && enabled) workingByBarber.add(barberId);
  }

  const servicesByBarber = countBy((servicesEffRaw.data ?? []) as Array<Record<string, unknown>>, "barber_ref");

  const w = {
    avatar: 10,
    cover: 10,
    availability: 15,
    portfolio: 10,
    services: 15,
    reviews: 10,
    bookings: 15,
    reels: 10,
    profile: 5
  };

  const scoreRows: ScoreRow[] = barbers.map((b) => {
    const missing: string[] = [];
    let score = 0;

    const hasAvatar = Boolean((b.avatar_path ?? "").trim() || (b.avatar_url ?? "").trim());
    const hasCover = Boolean((b.cover_path ?? "").trim() || (b.cover_url ?? "").trim());
    const hasAvailability = workingByBarber.has(b.id);
    const portfolioCount = portfolioByBarber.get(b.id) ?? 0;
    const serviceCount = servicesByBarber.get(b.id) ?? 0;
    const reelCount = reelsByBarber.get(b.id) ?? 0;
    const reviewCount = reviewsByBarber.get(b.id) ?? 0;
    const booking = bookingsByBarber.get(b.id) ?? { total: 0, completed: 0 };
    const completionRate = booking.total > 0 ? booking.completed / booking.total : 0;
    const profileComplete = Boolean((b.display_name ?? "").trim() && (b.slug ?? "").trim() && (b.area ?? "").trim());

    if (hasAvatar) score += w.avatar;
    else missing.push("avatar");
    if (hasCover) score += w.cover;
    else missing.push("cover");
    if (hasAvailability) score += w.availability;
    else missing.push("availability");
    if (portfolioCount > 0) score += w.portfolio;
    else missing.push("portfolio");
    if (serviceCount > 0) score += w.services;
    else missing.push("services");
    if (reviewCount > 0) score += w.reviews;
    else missing.push("reviews");

    if (completionRate >= 0.7) score += w.bookings;
    else {
      score += Math.round(w.bookings * completionRate);
      missing.push("booking completion");
    }

    if (reelCount > 0) score += w.reels;
    else missing.push("reels");
    if (profileComplete) score += w.profile;
    else missing.push("profile completeness");

    return { id: b.id, name: (b.display_name ?? "").trim() || "Barber", score: Math.max(0, Math.min(100, score)), missing };
  });

  scoreRows.sort((a, b) => a.score - b.score);

  return (
    <PageFrame
      title="Barber Health Score"
      subtitle="Score 0–100 per barber based on images, availability, portfolio, services, reviews, bookings, and profile completeness."
      actions={
        <Button asChild size="sm" variant="secondary">
          <Link href="/missing-images">Missing Images</Link>
        </Button>
      }
    >
      {scoreRows.length ? (
        <div className="flex flex-col gap-3">
          {scoreRows.map((b) => (
            <LuxuryCard key={b.id} className="border border-white/10 bg-white/5 p-4">
              <div className="flex flex-col gap-2">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div className="flex flex-col gap-0.5">
                    <div className="text-sm font-semibold">{b.name}</div>
                    <div className="text-[11px] text-muted-foreground">{b.id}</div>
                  </div>
                  <div className="text-2xl font-semibold tracking-tight">{b.score}</div>
                </div>
                <div className="text-xs text-muted-foreground">
                  Missing: {b.missing.length ? b.missing.join(", ") : "—"}
                </div>
                <div className="flex items-center gap-2 pt-1">
                  <Button asChild size="sm" variant="secondary">
                    <Link href={`/barbers/${encodeURIComponent(b.id)}`}>Open Barber</Link>
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
        <div className="text-sm text-muted-foreground">No barbers found.</div>
      )}
    </PageFrame>
  );
}


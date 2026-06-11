import Link from "next/link";

import { signedOrUrl } from "@hallaq/supabase/storage";
import { getT } from "@hallaq/ui/translations-server";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { RealtimeRefresh } from "@/components/realtime-refresh";
import { SafeImage } from "@/components/safe-image";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

function ring(score: number) {
  const s = Math.max(0, Math.min(100, score));
  if (s >= 85) return "stroke-emerald-500";
  if (s >= 70) return "stroke-[hsl(var(--gold))]";
  if (s >= 50) return "stroke-amber-500";
  return "stroke-rose-500";
}

export default async function CityHealthScoreBarberPage({ params }: { params: Promise<{ id: string }> }) {
  const t = await getT();
  const { id } = await params;
  const supabase = await createAppSupabaseServerClient();

  const [{ data: barber }, { data: scoreJson }] = await Promise.all([
    supabase.from("barbers").select("id, display_name, avatar_url, avatar_path, rating_avg, rating_count, followers_count").eq("id", id).maybeSingle(),
    supabase.rpc("business_health_score", { p_entity_type: "barber", p_entity_id: id })
  ]);

  const avatar = await signedOrUrl(supabase, "barber-images", barber?.avatar_path ?? barber?.avatar_url);
  const payload = scoreJson as unknown as { score?: number; metrics?: Record<string, unknown> } | null;
  const score = Number(payload?.score ?? 0);
  const metrics = (payload?.metrics ?? {}) as Record<string, unknown>;

  const circumference = 2 * Math.PI * 46;
  const dash = circumference * (1 - Math.max(0, Math.min(100, score)) / 100);

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 px-4 pt-6 pb-24">
      <RealtimeRefresh tables={["bookings", "barbers", "reviews", "follows"]} />
      <header className="flex items-center justify-between">
        <div className="flex flex-col gap-1">
          <div className="text-[13px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">{t("customer.city.title")}</div>
          <div className="text-sm font-semibold text-[#111111]">Business Health Score</div>
        </div>
        <Link href="/city" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
          Back
        </Link>
      </header>

      <div className="overflow-hidden rounded-[28px] border bg-white p-4 shadow-[0_18px_48px_rgba(17,17,17,0.10)]">
        <div className="flex items-center gap-3">
          <div className="h-14 w-14 overflow-hidden rounded-2xl border bg-white">
            <SafeImage src={avatar} fallbackKey="default_barber_avatar" alt="" className="h-full w-full object-cover" />
          </div>
          <div className="flex flex-1 flex-col">
            <div className="text-[12px] font-semibold text-[#111111] line-clamp-1">{barber?.display_name ?? "Barber"}</div>
            <div className="mt-0.5 text-[11px] text-muted-foreground">
              ★ {Number(barber?.rating_avg ?? 0).toFixed(1)} • {Number(barber?.followers_count ?? 0).toLocaleString()} followers
            </div>
          </div>
        </div>

        <div className="mt-5 grid grid-cols-2 gap-4">
          <div className="grid place-items-center rounded-[26px] bg-black/5 p-4">
            <div className="relative h-[120px] w-[120px]">
              <svg viewBox="0 0 120 120" className="h-full w-full">
                <circle cx="60" cy="60" r="46" className="stroke-black/10" strokeWidth="10" fill="none" />
                <circle
                  cx="60"
                  cy="60"
                  r="46"
                  className={ring(score)}
                  strokeWidth="10"
                  fill="none"
                  strokeLinecap="round"
                  strokeDasharray={circumference}
                  strokeDashoffset={dash}
                  transform="rotate(-90 60 60)"
                />
              </svg>
              <div className="absolute inset-0 grid place-items-center">
                <div className="text-center">
                  <div className="text-3xl font-black text-[#111111]">{Math.round(score)}</div>
                  <div className="text-[11px] font-semibold text-muted-foreground">/ 100</div>
                </div>
              </div>
            </div>
            <div className="mt-3 text-[12px] font-semibold text-[#111111]">Score</div>
          </div>

          <div className="flex flex-col gap-2">
            <div className="rounded-[22px] bg-black/5 px-4 py-3">
              <div className="text-[10px] font-semibold text-muted-foreground">Reviews</div>
              <div className="mt-1 text-base font-black text-[#111111]">{Number(metrics.reviews ?? 0)}</div>
            </div>
            <div className="rounded-[22px] bg-black/5 px-4 py-3">
              <div className="text-[10px] font-semibold text-muted-foreground">Completion Rate</div>
              <div className="mt-1 text-base font-black text-[#111111]">{Number(metrics.completionRate ?? 0)}%</div>
            </div>
            <div className="rounded-[22px] bg-black/5 px-4 py-3">
              <div className="text-[10px] font-semibold text-muted-foreground">Bookings (30d)</div>
              <div className="mt-1 text-base font-black text-[#111111]">{Number(metrics.bookings30d ?? 0)}</div>
            </div>
          </div>
        </div>

        <div className="mt-4 rounded-[24px] border border-[hsl(var(--gold))/0.35] bg-[hsl(var(--gold))/0.10] p-4">
          <div className="text-[12px] font-semibold text-[#111111]">Keep improving</div>
          <div className="mt-1 text-[12px] text-muted-foreground">More completed bookings and consistent reviews raise your score automatically.</div>
        </div>
      </div>

      <CustomerBottomNav />
    </main>
  );
}

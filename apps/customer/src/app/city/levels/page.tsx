import Link from "next/link";
import { redirect } from "next/navigation";

import { getT } from "@hallaq/ui/translations-server";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { RealtimeRefresh } from "@/components/realtime-refresh";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type Tier = "Silver" | "Gold" | "Platinum";

function tierFromDb(value: unknown): Tier {
  if (value === "Gold") return "Gold";
  if (value === "Platinum") return "Platinum";
  return "Silver";
}

function nextTier(tier: Tier): Tier | null {
  if (tier === "Silver") return "Gold";
  if (tier === "Gold") return "Platinum";
  return null;
}

function tierThreshold(tier: Tier) {
  if (tier === "Gold") return 500;
  if (tier === "Platinum") return 1400;
  return 0;
}

export default async function CityLevelsPage() {
  const t = await getT();
  const supabase = await createAppSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) redirect("/auth/sign-in?next=/city/levels");

  const { data: membership } = await supabase
    .from("customer_membership")
    .select("points, tier, updated_at")
    .eq("user_id", user.id)
    .maybeSingle();

  const points = Number(membership?.points ?? 0);
  const tier = tierFromDb(membership?.tier);
  const next = nextTier(tier);
  const currentFloor = tierThreshold(tier);
  const nextGoal = next ? tierThreshold(next) : null;
  const progress = nextGoal ? Math.min(1, Math.max(0, (points - currentFloor) / Math.max(1, nextGoal - currentFloor))) : 1;

  const benefits =
    tier === "Platinum"
      ? ["Priority booking", "Exclusive offers", "VIP support", "Early access drops"]
      : tier === "Gold"
        ? ["Member-only offers", "Faster booking", "Bonus points boosts"]
        : ["Points on bookings", "Member offers", "Level progress tracking"];

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 px-4 pt-6 pb-24">
      <RealtimeRefresh tables={["customer_membership", "loyalty_ledger"]} />
      <header className="flex items-center justify-between">
        <div className="flex flex-col gap-1">
          <div className="text-[13px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">{t("customer.city.title")}</div>
          <div className="text-sm font-semibold text-[#111111]">Hallaq Levels</div>
        </div>
        <Link href="/city" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
          Back
        </Link>
      </header>

      <div className="overflow-hidden rounded-[28px] border bg-white p-4 shadow-[0_22px_60px_rgba(17,17,17,0.10)]">
        <div className="flex items-start justify-between gap-3">
          <div className="flex flex-col">
            <div className="text-[11px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">{tier.toUpperCase()}</div>
            <div className="mt-2 text-[28px] font-black text-[#111111]">{points.toLocaleString()}</div>
            <div className="mt-0.5 text-[12px] text-muted-foreground">Points</div>
          </div>
          <div className="grid h-12 w-12 place-items-center rounded-2xl bg-[hsl(var(--gold))/0.14] text-[18px] font-black text-[#111111]">
            {tier === "Platinum" ? "P" : tier === "Gold" ? "G" : "S"}
          </div>
        </div>

        <div className="mt-4">
          <div className="flex items-center justify-between text-[11px] font-semibold text-muted-foreground">
            <span>{tier}</span>
            <span>{next ? `Next: ${next}` : "Max level"}</span>
          </div>
          <div className="mt-2 h-3 overflow-hidden rounded-full bg-black/10">
            <div className="h-full rounded-full bg-[hsl(var(--gold))]" style={{ width: `${Math.round(progress * 100)}%` }} />
          </div>
          <div className="mt-2 text-[11px] text-muted-foreground">
            {nextGoal ? `${Math.max(0, nextGoal - points).toLocaleString()} points to reach ${next}` : "You are at the highest level."}
          </div>
        </div>
      </div>

      <div className="overflow-hidden rounded-[28px] border bg-white p-4 shadow-[0_16px_36px_rgba(17,17,17,0.08)]">
        <div className="text-sm font-semibold text-[#111111]">Benefits</div>
        <div className="mt-3 flex flex-col gap-2">
          {benefits.map((b) => (
            <div key={b} className="rounded-[22px] bg-black/5 px-4 py-3 text-[12px] font-semibold text-[#111111]">
              {b}
            </div>
          ))}
        </div>
        <Link
          href="/profile"
          className="mt-4 grid h-12 place-items-center rounded-[22px] bg-[hsl(var(--gold))] text-[13px] font-semibold text-[#111111] shadow-[0_18px_42px_rgba(212,175,55,0.25)]"
        >
          View Benefits
        </Link>
      </div>

      <CustomerBottomNav />
    </main>
  );
}


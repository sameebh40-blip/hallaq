import Link from "next/link";

import { getServerLocale, getT } from "@hallaq/ui/translations-server";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type AwardCategory = { id: string; name_en: string; name_ar: string };
type Award = { id: string; category_id: string; year: number; target_type: string; target_id: string };

export default async function CityAwardsPage() {
  const t = await getT();
  const locale = await getServerLocale();
  const supabase = await createAppSupabaseServerClient();

  const [{ data: categories, error: catError }, { data: awards, error: awardsError }] = await Promise.all([
    supabase.from("award_categories").select("id, name_en, name_ar").order("created_at", { ascending: false }).limit(20),
    supabase.from("awards").select("id, category_id, year, target_type, target_id").order("year", { ascending: false }).limit(50)
  ]);

  const canRead = !catError && !awardsError;
  const cats = (categories ?? []) as AwardCategory[];
  const list = (awards ?? []) as Award[];

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 px-4 pt-6 pb-24">
      <header className="flex items-center justify-between">
        <div className="flex flex-col gap-1">
          <div className="text-[13px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">{t("customer.city.title")}</div>
          <div className="text-sm font-semibold text-[#111111]">Hallaq Awards</div>
        </div>
        <Link href="/city" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
          Back
        </Link>
      </header>

      <div className="overflow-hidden rounded-[28px] border bg-[#111111] p-5 text-white shadow-[0_18px_48px_rgba(0,0,0,0.18)]">
        <div className="text-[11px] font-semibold tracking-[0.22em] text-white/70">HALLAQ AWARDS</div>
        <div className="mt-2 text-sm font-semibold">Premium rankings across Bahrain’s grooming scene.</div>
        <div className="mt-1 text-[12px] text-white/80">Winners, stats, and the reason behind the win.</div>
      </div>

      {!canRead ? (
        <div className="rounded-[26px] border bg-white p-4 text-sm text-muted-foreground">
          Awards data is not available yet for customer view.
        </div>
      ) : (
        <div className="flex flex-col gap-3">
          {cats.map((c) => {
            const label = locale === "en" ? c.name_en : c.name_ar;
            const winners = list.filter((a) => a.category_id === c.id).slice(0, 1);
            return (
              <div key={c.id} className="overflow-hidden rounded-[26px] border bg-white p-4 shadow-[0_16px_36px_rgba(17,17,17,0.08)]">
                <div className="text-[12px] font-semibold text-[#111111]">{label}</div>
                {winners.length ? (
                  <Link href={`/city/awards/${encodeURIComponent(winners[0].id)}`} className="mt-2 flex items-center justify-between rounded-[22px] bg-black/5 p-3">
                    <div className="flex flex-col">
                      <div className="text-[11px] font-semibold text-[#111111]">Winner</div>
                      <div className="mt-0.5 text-[11px] text-muted-foreground">
                        {winners[0].target_type} • {winners[0].year}
                      </div>
                    </div>
                    <div className="rounded-full bg-[hsl(var(--gold))] px-3 py-1 text-[11px] font-semibold text-[#111111]">View</div>
                  </Link>
                ) : (
                  <div className="mt-2 text-[11px] text-muted-foreground">No winner set yet.</div>
                )}
              </div>
            );
          })}
        </div>
      )}

      <CustomerBottomNav />
    </main>
  );
}

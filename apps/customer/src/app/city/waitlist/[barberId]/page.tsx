import Link from "next/link";

import { getT } from "@hallaq/ui/translations-server";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { RealtimeRefresh } from "@/components/realtime-refresh";
import { createAppSupabaseServerClient } from "@/lib/supabase";

import { WaitlistClient } from "./waitlist-client";

export const dynamic = "force-dynamic";

export default async function CityWaitlistPage({ params }: { params: Promise<{ barberId: string }> }) {
  const t = await getT();
  const { barberId } = await params;
  const supabase = await createAppSupabaseServerClient();

  const { data: barber } = await supabase.from("barbers").select("id, display_name").eq("id", barberId).maybeSingle();

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 px-4 pt-6 pb-24">
      <RealtimeRefresh tables={["waitlist_entries", "availability_cache_days", "notifications"]} />
      <header className="flex items-center justify-between">
        <div className="flex flex-col gap-1">
          <div className="text-[13px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">{t("customer.city.title")}</div>
          <div className="text-sm font-semibold text-[#111111]">Join Waitlist</div>
          <div className="text-[12px] text-muted-foreground">{barber?.display_name ?? "Barber"}</div>
        </div>
        <Link href="/city" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
          Back
        </Link>
      </header>

      <WaitlistClient barberId={barberId} />

      <CustomerBottomNav />
    </main>
  );
}

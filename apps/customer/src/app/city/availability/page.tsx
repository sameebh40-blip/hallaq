import Link from "next/link";

import { signedOrUrl } from "@hallaq/supabase/storage";
import { getT } from "@hallaq/ui/translations-server";
import { cn } from "@hallaq/ui/cn";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { RealtimeRefresh } from "@/components/realtime-refresh";
import { SafeImage } from "@/components/safe-image";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

function safeUrl(url: unknown, fallback: string) {
  const u = typeof url === "string" ? url.trim() : "";
  return u || fallback;
}

function badge(status: string) {
  if (status === "available_now") return { label: "Available Now", cls: "bg-emerald-500/12 text-emerald-700 border-emerald-500/20" };
  if (status === "busy_today") return { label: "Busy Today", cls: "bg-amber-500/12 text-amber-700 border-amber-500/20" };
  return { label: "Fully Booked", cls: "bg-rose-500/12 text-rose-700 border-rose-500/20" };
}

export default async function CityAvailabilityPage() {
  const t = await getT();
  const supabase = await createAppSupabaseServerClient();

  const { data: barbers } = await supabase
    .from("barbers")
    .select("id, display_name, avatar_url, avatar_path, rating_avg, followers_count, available_now")
    .eq("status", "approved")
    .eq("is_active", true)
    .is("deleted_at", null)
    .order("rating_avg", { ascending: false })
    .limit(30);

  const ids = ((barbers ?? []) as Array<{ id: string }>).map((b) => b.id);
  const { data: statuses } = ids.length ? await supabase.rpc("barbers_availability_status", { p_barbers: ids }) : { data: [] };
  const statusMap = new Map<string, string>();
  for (const row of (statuses ?? []) as Array<{ barber_id: string; status: string }>) statusMap.set(row.barber_id, row.status);

  const list = await Promise.all(
    ((barbers ?? []) as Array<Record<string, unknown>>).map(async (b) => {
      const avatar = await signedOrUrl(supabase, "barber-images", String(b.avatar_path ?? b.avatar_url ?? "").trim() || null);
      return {
        id: String(b.id),
        name: String(b.display_name ?? "Barber"),
        avatarUrl: safeUrl(avatar, ""),
        rating: Number(b.rating_avg ?? 0),
        followers: Number(b.followers_count ?? 0),
        status: statusMap.get(String(b.id)) ?? (b.available_now ? "available_now" : "busy_today")
      };
    })
  );

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 pt-6 pb-24 text-white">
      <RealtimeRefresh tables={["availability_cache_days", "barbers", "bookings"]} />
      <header className="flex items-center justify-between">
        <div className="flex flex-col gap-1">
          <div className="text-[13px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">{t("customer.city.title")}</div>
          <div className="text-sm font-semibold text-white">Live Availability</div>
          <div className="text-[12px] text-muted-foreground">Green: Available Now • Yellow: Busy Today • Red: Fully Booked</div>
        </div>
        <Link href="/city" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
          Back
        </Link>
      </header>

      <div className="flex flex-col gap-3">
        {list.map((b) => {
          const meta = badge(b.status);
          return (
            <div
              key={b.id}
              className="flex items-center gap-3 overflow-hidden rounded-[26px] border border-[#2A2A2A] bg-[#111111] p-3 shadow-[0_16px_36px_rgba(0,0,0,0.35)]"
            >
              <Link
                href={`/barber/${encodeURIComponent(b.id)}`}
                className="h-14 w-14 shrink-0 overflow-hidden rounded-2xl border border-[#2A2A2A] bg-black/30"
              >
                <SafeImage src={b.avatarUrl} fallbackKey="default_barber_avatar" alt={b.name} className="h-full w-full object-cover" />
              </Link>
              <div className="flex flex-1 flex-col">
                <div className="flex items-center justify-between gap-2">
                  <Link href={`/barber/${encodeURIComponent(b.id)}`} className="text-[12px] font-semibold text-white line-clamp-1">
                    {b.name}
                  </Link>
                  <div className={cn("rounded-full border px-2 py-1 text-[10px] font-semibold", meta.cls)}>{meta.label}</div>
                </div>
                <div className="mt-1 flex items-center justify-between text-[11px] text-muted-foreground">
                  <span>★ {b.rating.toFixed(1)}</span>
                  <span>{b.followers.toLocaleString()} followers</span>
                </div>
                <div className="mt-3 grid grid-cols-2 gap-2">
                  <Link
                    href={`/city/waitlist/${encodeURIComponent(b.id)}`}
                    className="grid h-10 place-items-center rounded-[18px] border border-[#2A2A2A] bg-black/30 text-[11px] font-semibold text-white"
                  >
                    Waitlist
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
          );
        })}
      </div>

      <CustomerBottomNav />
    </main>
  );
}

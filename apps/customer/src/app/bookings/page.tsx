import Link from "next/link";
import { redirect } from "next/navigation";

import { createAppSupabaseServerClient } from "@/lib/supabase";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { RealtimeRefresh } from "@/components/realtime-refresh";
import { SafeImage } from "@/components/safe-image";

export const dynamic = "force-dynamic";

function formatDate(value: string) {
  const date = new Date(value);
  return Intl.DateTimeFormat("en", { dateStyle: "medium" }).format(date);
}

function formatTime(value: string) {
  const date = new Date(value);
  return Intl.DateTimeFormat("en", { timeStyle: "short" }).format(date);
}

type BookingRow = {
  id: string;
  start_at: string;
  end_at: string;
  status: string;
  created_at: string;
  updated_at: string;
  cancelled_at: string | null;
  cancelled_by_profile_id: string | null;
  cancel_reason: string | null;
  cancelled_reason: string | null;
  rescheduled_at: string | null;
  rescheduled_by_profile_id: string | null;
  customer_profile_id: string;
  barbers: Array<{ profile_id: string | null; display_name: string | null; avatar_url: string | null }> | null;
  barbershops: Array<{ owner_profile_id: string | null; name: string | null }> | null;
  services: Array<{ name_en: string | null; name_ar: string | null }> | null;
};

type TabKey =
  | "upcoming"
  | "completed"
  | "cancelled";

function isAutoAccepted(r: BookingRow) {
  if (r.status !== "confirmed") return false;
  if (r.cancelled_at || r.rescheduled_at) return false;
  const a = new Date(r.created_at).getTime();
  const b = new Date(r.updated_at).getTime();
  return Math.abs(b - a) <= 6_000;
}

function cancelLabel(r: BookingRow) {
  if (r.status !== "cancelled") return null;
  const by = r.cancelled_by_profile_id;
  const barberProfileId = r.barbers?.[0]?.profile_id ?? null;
  const shopOwnerProfileId = r.barbershops?.[0]?.owner_profile_id ?? null;
  if (!by) return "Cancelled";
  if (by === r.customer_profile_id) return "Cancelled by Client";
  if (by === barberProfileId) return "Cancelled by Barber";
  if (by === shopOwnerProfileId) return "Cancelled by Shop";
  return "Cancelled";
}

function statusChip(r: BookingRow) {
  if (r.rescheduled_at && r.status !== "cancelled") return { label: "Rescheduled", tone: "gold" as const };
  if (r.status === "cancelled" || r.status === "rejected") return { label: cancelLabel(r) ?? "Cancelled", tone: "red" as const };
  if (r.status === "no_show") return { label: "No Show", tone: "red" as const };
  if (r.status === "completed") return { label: "Completed", tone: "blue" as const };
  if (r.status === "in_progress") return { label: "In Progress", tone: "gold" as const };
  if (r.status === "pending") return { label: "Pending", tone: "gold" as const };
  if (r.status === "confirmed" || r.status === "accepted")
    return isAutoAccepted(r) ? { label: "Confirmed", tone: "gold" as const } : { label: "Confirmed", tone: "green" as const };
  return { label: r.status, tone: "gold" as const };
}

function matchesTab(r: BookingRow, tab: TabKey, nowMs: number) {
  const startMs = new Date(r.start_at).getTime();
  if (tab === "upcoming") {
    if (r.status === "in_progress") return true;
    return (r.status === "pending" || r.status === "confirmed" || r.status === "accepted" || r.status === "rescheduled") && startMs >= nowMs;
  }
  if (tab === "completed") return r.status === "completed";
  if (tab === "cancelled") return r.status === "cancelled" || r.status === "rejected" || r.status === "no_show";
  return true;
}

export default async function CustomerBookingsPage({
  searchParams
}: {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
}) {
  const supabase = await createAppSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) redirect("/auth/sign-in?next=/bookings");

  const { data: rows, error } = await supabase
    .from("bookings")
    .select(
      "id, start_at, end_at, status, created_at, updated_at, cancelled_at, cancelled_by_profile_id, cancel_reason, cancelled_reason, rescheduled_at, rescheduled_by_profile_id, customer_profile_id, barbers(profile_id, display_name, avatar_url), barbershops(owner_profile_id, name), services(name_en, name_ar)"
    )
    .eq("customer_profile_id", user.id)
    .order("start_at", { ascending: false })
    .limit(80);

  const sp = (await searchParams) ?? {};
  const tab = (typeof sp.tab === "string" ? sp.tab : "upcoming") as TabKey;
  const nowMs = Date.now();
  const list = ((rows ?? []) as BookingRow[]).filter((r) => matchesTab(r, tab, nowMs));

  const tabs: { key: TabKey; label: string }[] = [
    { key: "upcoming", label: "Upcoming" },
    { key: "completed", label: "Completed" },
    { key: "cancelled", label: "Cancelled" }
  ];

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 py-6 pb-28 text-white">
      <RealtimeRefresh subscriptions={[{ table: "bookings", filter: `customer_profile_id=eq.${user.id}` }]} />
      <div className="text-lg font-extrabold">Bookings</div>

      <div className="flex gap-2 overflow-x-auto pb-1">
        {tabs.map((t) => {
          const active = t.key === tab;
          return (
            <a
              key={t.key}
              href={`/bookings?tab=${t.key}`}
              className={
                active
                  ? "shrink-0 rounded-full border border-[hsl(var(--gold))]/55 bg-[#111111] px-4 py-2 text-xs font-extrabold text-[hsl(var(--gold))] shadow-[0_18px_42px_rgba(212,175,55,0.18)]"
                  : "shrink-0 rounded-full border border-[#2A2A2A] bg-[#111111] px-4 py-2 text-xs font-semibold text-[#9E9E9E]"
              }
            >
              {t.label}
            </a>
          );
        })}
      </div>

      {error ? (
        <div className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-6">
          <div className="text-sm font-extrabold">Could not load bookings</div>
          <div className="pt-1 text-sm font-semibold text-[#9E9E9E]">Please try again.</div>
        </div>
      ) : list.length ? (
        <div className="flex flex-col gap-3">
          {list.map((r) => {
            const chip = statusChip(r);
            const barber = r.barbers?.[0] ?? null;
            const shop = r.barbershops?.[0] ?? null;
            const serviceRow = r.services?.[0] ?? null;
            const title = barber?.display_name || shop?.name || "Appointment";
            const service = serviceRow?.name_en || serviceRow?.name_ar || "";
            const cancelReason = (r.cancelled_reason ?? r.cancel_reason ?? "").trim();
            const tone =
              chip.tone === "gold"
                ? "border-[hsl(var(--gold))]/35 text-[hsl(var(--gold))]"
                : chip.tone === "green"
                  ? "border-emerald-500/25 text-emerald-400"
                  : chip.tone === "blue"
                    ? "border-sky-500/25 text-sky-400"
                    : "border-rose-500/25 text-rose-400";

            return (
              <Link
                key={r.id}
                href={`/bookings/${encodeURIComponent(r.id)}`}
                className="block rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-4 shadow-[0_18px_44px_rgba(0,0,0,0.55)]"
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="flex min-w-0 flex-1 items-start gap-3">
                    <div className="h-12 w-12 overflow-hidden rounded-[18px] border border-[#2A2A2A] bg-black">
                      <SafeImage src={barber?.avatar_url ?? null} fallbackKey="default_barber_avatar" alt={title} className="h-full w-full object-cover" />
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-sm font-extrabold text-white">{title}</div>
                      {service ? <div className="truncate pt-1 text-[12px] font-semibold text-[#9E9E9E]">{service}</div> : null}
                      <div className="pt-2 text-[12px] font-semibold text-[#9E9E9E]">
                        {formatDate(r.start_at)} • {formatTime(r.start_at)} - {formatTime(r.end_at)}
                      </div>
                      {r.status === "cancelled" && cancelReason ? (
                        <div className="truncate pt-2 text-[12px] font-semibold text-rose-200">{cancelReason}</div>
                      ) : null}
                    </div>
                  </div>
                  <div className={`shrink-0 rounded-full border bg-black/30 px-3 py-1 text-[11px] font-extrabold ${tone}`}>{chip.label}</div>
                </div>
              </Link>
            );
          })}
        </div>
      ) : (
        <div className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-6">
          <div className="text-sm font-extrabold">No bookings</div>
          <div className="pt-1 text-sm font-semibold text-[#9E9E9E]">Nothing to show in this category.</div>
          <div className="pt-4">
            <a
              href="/discover"
              className="inline-flex h-12 w-full items-center justify-center rounded-[14px] bg-[hsl(var(--gold))] px-5 text-sm font-extrabold text-black shadow-[0_18px_42px_rgba(212,175,55,0.28)]"
            >
              Discover barbers
            </a>
          </div>
        </div>
      )}
      <CustomerBottomNav />
    </main>
  );
}

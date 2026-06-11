import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type BookingRow = {
  id: string;
  start_at: string;
  end_at: string;
  status: string;
  shop_id: string | null;
  shop_name: string | null;
  barber_id: string | null;
  barber_name: string | null;
  customer_name: string | null;
  customer_email: string | null;
  service_name_en: string | null;
  deposit_required_amount: number | null;
};

function formatTime(value: string) {
  const date = new Date(value);
  return Intl.DateTimeFormat("en", { timeStyle: "short" }).format(date);
}

function toDateInputValue(date: Date) {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function parseDayRange(day: string) {
  const startLocal = new Date(`${day}T00:00:00`);
  const endLocal = new Date(`${day}T23:59:59`);
  return { startIso: startLocal.toISOString(), endIso: endLocal.toISOString() };
}

export default async function AdminCalendarPage({
  searchParams
}: {
  searchParams?: Promise<{ day?: string; shop?: string; status?: string; error?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const today = toDateInputValue(new Date());
  const day = (params?.day ?? "").trim() || today;
  const shopId = (params?.shop ?? "").trim();
  const statusFilter = (params?.status ?? "").trim();
  const error = (params?.error ?? "").trim();

  const supabase = await createSupabaseServerClient();
  const { startIso, endIso } = parseDayRange(day);

  const { data: shops } = await supabase
    .from("barbershops")
    .select("id, name")
    .order("created_at", { ascending: false })
    .limit(500);

  let query = supabase
    .from("bookings")
    .select(
      "id, start_at, end_at, status, shop_id, barber_id, customer_profile_id, service_id, deposit_required_amount, profiles(full_name, email), services(name_en), barbers(display_name), barbershops(name)"
    )
    .gte("start_at", startIso)
    .lte("start_at", endIso)
    .order("start_at", { ascending: true })
    .limit(1000);

  if (shopId && shopId !== "all") query = query.eq("shop_id", shopId);
  if (statusFilter && statusFilter !== "all") query = query.eq("status", statusFilter);

  const { data: raw } = await query;
  const rows =
    (raw ?? []).map((row) => {
      const r = row as Record<string, unknown>;
      const rawProfile = r.profiles as unknown;
      const profile =
        (Array.isArray(rawProfile) ? (rawProfile[0] as Record<string, unknown> | undefined) : (rawProfile as Record<string, unknown> | null)) ??
        null;

      const rawService = r.services as unknown;
      const service =
        (Array.isArray(rawService) ? (rawService[0] as Record<string, unknown> | undefined) : (rawService as Record<string, unknown> | null)) ??
        null;

      const rawBarber = r.barbers as unknown;
      const barber =
        (Array.isArray(rawBarber) ? (rawBarber[0] as Record<string, unknown> | undefined) : (rawBarber as Record<string, unknown> | null)) ??
        null;

      const rawShop = r.barbershops as unknown;
      const shopRow =
        (Array.isArray(rawShop) ? (rawShop[0] as Record<string, unknown> | undefined) : (rawShop as Record<string, unknown> | null)) ?? null;

      return {
        id: String(r.id ?? ""),
        start_at: String(r.start_at ?? ""),
        end_at: String(r.end_at ?? ""),
        status: String(r.status ?? ""),
        shop_id: (r.shop_id as string | null | undefined) ?? null,
        shop_name: (shopRow?.name as string | null | undefined) ?? null,
        barber_id: (r.barber_id as string | null | undefined) ?? null,
        barber_name: (barber?.display_name as string | null | undefined) ?? null,
        customer_name: (profile?.full_name as string | null | undefined) ?? null,
        customer_email: (profile?.email as string | null | undefined) ?? null,
        service_name_en: (service?.name_en as string | null | undefined) ?? null,
        deposit_required_amount: (r.deposit_required_amount as number | null | undefined) ?? null
      } satisfies BookingRow;
    }) ?? [];

  async function reschedule(formData: FormData) {
    "use server";
    const id = String(formData.get("id") ?? "");
    const startAtLocal = String(formData.get("start_at") ?? "");
    if (!id || !startAtLocal) redirect(`/calendar?day=${encodeURIComponent(day)}&shop=${encodeURIComponent(shopId)}&status=${encodeURIComponent(statusFilter)}`);

    const supabase = await createSupabaseServerClient();
    const iso = new Date(startAtLocal).toISOString();
    const { error } = await supabase.rpc("reschedule_booking", { booking_id: id, new_start_at: iso });
    if (error) {
      redirect(
        `/calendar?day=${encodeURIComponent(day)}&shop=${encodeURIComponent(shopId)}&status=${encodeURIComponent(statusFilter)}&error=${encodeURIComponent(error.message)}`
      );
    }
    redirect(`/calendar?day=${encodeURIComponent(day)}&shop=${encodeURIComponent(shopId)}&status=${encodeURIComponent(statusFilter)}`);
  }

  return (
    <PageFrame title="Calendar" subtitle="Daily schedule across all shops.">
      <div className="flex flex-col gap-4">
        {error ? <LuxuryCard className="border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard> : null}
        <LuxuryCard className="p-4">
          <form method="get" className="flex flex-wrap items-end gap-2">
            <div className="grid gap-2">
              <div className="text-xs text-muted-foreground">Day</div>
              <input
                type="date"
                name="day"
                defaultValue={day}
                className="h-9 rounded-md border border-white/10 bg-white/5 px-3 text-sm"
              />
            </div>
            <div className="grid gap-2">
              <div className="text-xs text-muted-foreground">Shop</div>
              <select
                name="shop"
                defaultValue={shopId || "all"}
                className="h-9 rounded-md border border-white/10 bg-white/5 px-3 text-sm"
              >
                <option value="all">All</option>
                {(shops ?? []).map((s) => (
                  <option key={s.id} value={s.id}>
                    {s.name}
                  </option>
                ))}
              </select>
            </div>
            <div className="grid gap-2">
              <div className="text-xs text-muted-foreground">Status</div>
              <select
                name="status"
                defaultValue={statusFilter || "all"}
                className="h-9 rounded-md border border-white/10 bg-white/5 px-3 text-sm"
              >
                <option value="all">All</option>
                <option value="pending">Pending</option>
                <option value="confirmed">Confirmed</option>
                <option value="in_progress">In Progress</option>
                <option value="rescheduled">Rescheduled</option>
                <option value="no_show">No Show</option>
                <option value="completed">Completed</option>
                <option value="cancelled">Cancelled</option>
              </select>
            </div>
            <Button type="submit" size="sm" variant="secondary">
              View
            </Button>
          </form>
        </LuxuryCard>

        {(rows ?? []).length ? (
          <LuxuryCard className="p-4">
            <div className="grid gap-2">
              {((rows ?? []) as BookingRow[]).map((r) => (
                <div key={r.id} className="rounded-lg border border-white/10 bg-white/5 p-3">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <div className="font-medium">
                      {formatTime(r.start_at)} - {formatTime(r.end_at)}
                    </div>
                    <div className="text-xs text-muted-foreground">{r.status}</div>
                  </div>
                  <div className="mt-2 text-sm">{r.service_name_en ?? "Service"}</div>
                  <div className="mt-1 text-xs text-muted-foreground">
                    {(r.shop_name ?? "").trim() || "Shop"} • {(r.barber_name ?? "").trim() || "Barber"}
                  </div>
                  <div className="mt-1 text-xs text-muted-foreground">
                    {(r.customer_name ?? "").trim() || "Customer"} • {(r.customer_email ?? "").trim() || "—"}
                  </div>
                  {Number(r.deposit_required_amount ?? 0) > 0 ? (
                    <div className="mt-2 text-xs text-amber-200">
                      Deposit: {Number(r.deposit_required_amount).toFixed(3)} BHD
                    </div>
                  ) : null}
                  <div className="mt-3">
                    <form action={reschedule} className="flex flex-wrap items-center gap-2">
                      <input type="hidden" name="id" value={r.id} />
                      <input
                        type="datetime-local"
                        name="start_at"
                        className="h-9 rounded-md border border-white/10 bg-white/5 px-2 text-xs text-muted-foreground"
                      />
                      <Button type="submit" size="sm" variant="ghost">
                        Reschedule
                      </Button>
                    </form>
                  </div>
                  <div className="mt-2 font-mono text-[10px] text-muted-foreground">{r.id}</div>
                </div>
              ))}
            </div>
          </LuxuryCard>
        ) : (
          <LuxuryCard className="p-8 text-center text-sm text-muted-foreground">No bookings for this day.</LuxuryCard>
        )}
      </div>
    </PageFrame>
  );
}

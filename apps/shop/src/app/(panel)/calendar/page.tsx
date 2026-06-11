import { redirect } from "next/navigation";

import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { getMyShop } from "@/lib/my-shop";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type BookingRow = {
  id: string;
  start_at: string;
  end_at: string;
  status: string;
  barber_id: string | null;
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

export default async function ShopCalendarPage({
  searchParams
}: {
  searchParams?: Promise<{ day?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const today = toDateInputValue(new Date());
  const day = (params?.day ?? "").trim() || today;

  const supabase = await createAppSupabaseServerClient();
  const shop = await getMyShop(supabase);
  if (!shop) return <div className="text-sm text-muted-foreground">No shop assigned to this account.</div>;

  const { startIso, endIso } = parseDayRange(day);

  const { data: barbers } = await supabase
    .from("barbers")
    .select("id, display_name")
    .eq("shop_id", shop.id)
    .order("display_name", { ascending: true })
    .limit(200);

  const { data: rowsRaw } = await supabase
    .from("bookings")
    .select(
      "id, start_at, end_at, status, barber_id, customer_profile_id, service_id, deposit_required_amount, profiles(full_name, email), services(name_en), barbers(display_name)"
    )
    .eq("shop_id", shop.id)
    .gte("start_at", startIso)
    .lte("start_at", endIso)
    .order("start_at", { ascending: true })
    .limit(500);

  const rows =
    (rowsRaw ?? []).map((row) => {
      const r = row as Record<string, unknown>;
      const rawProfile = r.profiles as unknown;
      const profile =
        (Array.isArray(rawProfile) ? (rawProfile[0] as Record<string, unknown> | undefined) : (rawProfile as Record<string, unknown> | null)) ??
        null;

      const rawService = r.services as unknown;
      const service =
        (Array.isArray(rawService) ? (rawService[0] as Record<string, unknown> | undefined) : (rawService as Record<string, unknown> | null)) ??
        null;

      return {
        id: String(r.id ?? ""),
        start_at: String(r.start_at ?? ""),
        end_at: String(r.end_at ?? ""),
        status: String(r.status ?? ""),
        barber_id: (r.barber_id as string | null | undefined) ?? null,
        customer_name: (profile?.full_name as string | null | undefined) ?? null,
        customer_email: (profile?.email as string | null | undefined) ?? null,
        service_name_en: (service?.name_en as string | null | undefined) ?? null,
        deposit_required_amount: (r.deposit_required_amount as number | null | undefined) ?? null
      } satisfies BookingRow;
    }) ?? [];

  const barberNameById = new Map((barbers ?? []).map((b) => [b.id, b.display_name]));
  const grouped = new Map<string, BookingRow[]>();
  for (const r of rows) {
    const key = (r.barber_id ?? "").trim() || "unassigned";
    const list = grouped.get(key) ?? [];
    list.push(r);
    grouped.set(key, list);
  }

  const orderedKeys = [
    ...(barbers ?? []).map((b) => b.id).filter((id) => grouped.has(id)),
    ...[...grouped.keys()].filter((k) => k === "unassigned"),
  ];

  async function reschedule(formData: FormData) {
    "use server";
    const id = String(formData.get("id") ?? "");
    const startAtLocal = String(formData.get("start_at") ?? "");
    if (!id || !startAtLocal) redirect(`/calendar?day=${encodeURIComponent(day)}`);

    const supabase = await createAppSupabaseServerClient();
    const iso = new Date(startAtLocal).toISOString();
    await supabase.rpc("reschedule_booking", { booking_id: id, new_start_at: iso });
    redirect(`/calendar?day=${encodeURIComponent(day)}`);
  }

  return (
    <div className="flex flex-col gap-4">
      <LuxuryCard className="p-4">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div className="grid gap-1">
            <div className="text-base font-semibold">Calendar</div>
            <div className="text-sm text-muted-foreground">Daily schedule by barber.</div>
          </div>
          <form method="get" className="flex items-center gap-2">
            <input
              type="date"
              name="day"
              defaultValue={day}
              className="h-9 rounded-md border border-white/10 bg-white/5 px-3 text-sm"
            />
            <Button type="submit" size="sm" variant="secondary">
              View
            </Button>
          </form>
        </div>
      </LuxuryCard>

      {orderedKeys.length ? (
        <div className="grid gap-4">
          {orderedKeys.map((barberId) => {
            const items = grouped.get(barberId) ?? [];
            const title =
              barberId === "unassigned" ? "Unassigned" : barberNameById.get(barberId) ?? "Barber";
            return (
              <LuxuryCard key={barberId} className="p-4">
                <div className="flex items-center justify-between gap-3">
                  <div className="text-sm font-semibold">{title}</div>
                  <div className="text-xs text-muted-foreground">{items.length} bookings</div>
                </div>
                <div className="mt-3 grid gap-2">
                  {items.map((r) => (
                    <div key={r.id} className="rounded-lg border border-white/10 bg-white/5 p-3">
                      <div className="flex flex-wrap items-center justify-between gap-2">
                        <div className="font-medium">
                          {formatTime(r.start_at)} - {formatTime(r.end_at)}
                        </div>
                        <div className="text-xs text-muted-foreground">{r.status}</div>
                      </div>
                      <div className="mt-2 text-sm">{r.service_name_en ?? "Service"}</div>
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
                    </div>
                  ))}
                  {!items.length ? <div className="text-sm text-muted-foreground">No bookings</div> : null}
                </div>
              </LuxuryCard>
            );
          })}
        </div>
      ) : (
        <LuxuryCard className="p-8 text-center text-sm text-muted-foreground">No bookings for this day.</LuxuryCard>
      )}
    </div>
  );
}

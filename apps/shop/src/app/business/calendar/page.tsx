import { redirect } from "next/navigation";

import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getMyProfile } from "@hallaq/supabase/profile";

import { DayCalendarBoard } from "./day-calendar-board";
import { getMyShopContext } from "@/lib/my-shop-context";
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
  duration_minutes: number;
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

function monthLabel(value: string) {
  const d = new Date(`${value}T00:00:00`);
  return new Intl.DateTimeFormat("en", { month: "long", year: "numeric" }).format(d);
}

export default async function BusinessCalendarPage({
  searchParams
}: {
  searchParams?: Promise<{ day?: string; view?: string; shopId?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const today = toDateInputValue(new Date());
  const day = (params?.day ?? "").trim() || today;
  const view = (params?.view ?? "").trim() || "day";

  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);
  const ctx = await getMyShopContext(supabase);

  const shopId = ctx.shop?.id ?? (profile?.role === "admin" ? (params?.shopId ?? null) : null);
  if (!shopId) return <div className="text-sm text-muted-foreground">No shop selected.</div>;

  const baseDate = new Date(`${day}T00:00:00`);
  const startOfWeek = new Date(baseDate);
  startOfWeek.setDate(baseDate.getDate() - baseDate.getDay());
  const endOfWeek = new Date(startOfWeek);
  endOfWeek.setDate(startOfWeek.getDate() + 6);

  const monthStart = new Date(baseDate.getFullYear(), baseDate.getMonth(), 1);
  const monthEnd = new Date(baseDate.getFullYear(), baseDate.getMonth() + 1, 0);
  const { startIso: dayStartIso, endIso: dayEndIso } = parseDayRange(day);
  const { startIso: weekStartIso } = parseDayRange(toDateInputValue(startOfWeek));
  const { endIso: weekEndIso } = parseDayRange(toDateInputValue(endOfWeek));
  const { startIso: monthStartIso } = parseDayRange(toDateInputValue(monthStart));
  const { endIso: monthEndIso } = parseDayRange(toDateInputValue(monthEnd));

  const { data: barbers } = await supabase
    .from("barbers")
    .select("id, display_name")
    .eq("shop_id", shopId)
    .order("display_name", { ascending: true })
    .limit(200);

  const { data: shopMeta } = await supabase.from("barbershops").select("buffer_minutes").eq("id", shopId).maybeSingle();

  let query = supabase
    .from("bookings")
    .select(
      "id, start_at, end_at, status, barber_id, customer_profile_id, service_id, deposit_required_amount, profiles(full_name, email), services(name_en), barbers(display_name)"
    )
    .eq("shop_id", shopId)
    .order("start_at", { ascending: true })
    .limit(2000);

  if (view === "week") {
    query = query.gte("start_at", weekStartIso).lte("start_at", weekEndIso);
  } else if (view === "month") {
    query = query.gte("start_at", monthStartIso).lte("start_at", monthEndIso);
  } else {
    query = query.gte("start_at", dayStartIso).lte("start_at", dayEndIso);
  }

  const { data: rowsRaw } = await query;

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
        deposit_required_amount: (r.deposit_required_amount as number | null | undefined) ?? null,
        duration_minutes: Math.max(
          30,
          Math.round((new Date(String(r.end_at ?? "")).getTime() - new Date(String(r.start_at ?? "")).getTime()) / 60_000) || 30
        )
      } satisfies BookingRow;
    }) ?? [];

  const barberNameById = new Map((barbers ?? []).map((b) => [b.id, b.display_name]));
  const groupedByBarber = new Map<string, BookingRow[]>();
  for (const r of rows) {
    const key = (r.barber_id ?? "").trim() || "unassigned";
    const list = groupedByBarber.get(key) ?? [];
    list.push(r);
    groupedByBarber.set(key, list);
  }

  const orderedBarberKeys = [
    ...(barbers ?? []).map((b) => b.id).filter((id) => groupedByBarber.has(id)),
    ...[...groupedByBarber.keys()].filter((k) => k === "unassigned")
  ];

  const groupedByDay = new Map<string, BookingRow[]>();
  for (const r of rows) {
    const key = toDateInputValue(new Date(r.start_at));
    const list = groupedByDay.get(key) ?? [];
    list.push(r);
    groupedByDay.set(key, list);
  }

  const weekDays: string[] = [];
  for (let i = 0; i < 7; i++) {
    const d = new Date(startOfWeek);
    d.setDate(startOfWeek.getDate() + i);
    weekDays.push(toDateInputValue(d));
  }

  const monthGrid: string[] = [];
  const gridStart = new Date(monthStart);
  gridStart.setDate(monthStart.getDate() - monthStart.getDay());
  for (let i = 0; i < 42; i++) {
    const d = new Date(gridStart);
    d.setDate(gridStart.getDate() + i);
    monthGrid.push(toDateInputValue(d));
  }

  async function reschedule(formData: FormData) {
    "use server";
    const id = String(formData.get("id") ?? "");
    const startAtLocal = String(formData.get("start_at") ?? "");
    if (!id || !startAtLocal) redirect(`/business/calendar?day=${encodeURIComponent(day)}`);

    const supabase = await createAppSupabaseServerClient();
    const iso = new Date(startAtLocal).toISOString();
    await supabase.rpc("reschedule_booking", { booking_id: id, new_start_at: iso });
    redirect(`/business/calendar?day=${encodeURIComponent(day)}`);
  }

  return (
    <div className="flex flex-col gap-4">
      <LuxuryCard className="p-4">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div className="grid gap-1">
            <div className="text-base font-semibold">Calendar</div>
            <div className="text-sm text-muted-foreground">
              {view === "month" ? monthLabel(day) : view === "week" ? "Week view" : "Daily schedule by barber."}
            </div>
          </div>
          <form method="get" className="flex flex-wrap items-center gap-2">
            {profile?.role === "admin" && !ctx.shop ? <input type="hidden" name="shopId" value={shopId} /> : null}
            <select name="view" defaultValue={view} className="h-9 rounded-md border border-white/10 bg-white/5 px-2 text-sm">
              <option value="day">Day</option>
              <option value="week">Week</option>
              <option value="month">Month</option>
            </select>
            <input type="date" name="day" defaultValue={day} className="h-9 rounded-md border border-white/10 bg-white/5 px-3 text-sm" />
            <Button type="submit" size="sm" variant="secondary">
              View
            </Button>
          </form>
        </div>
      </LuxuryCard>

      {view === "month" ? (
        <LuxuryCard className="p-4">
          <div className="grid grid-cols-7 gap-2">
            {monthGrid.map((d) => {
              const inMonth = d.slice(0, 7) === day.slice(0, 7);
              const count = groupedByDay.get(d)?.length ?? 0;
              return (
                <a
                  key={d}
                  href={`/business/calendar?view=day&day=${encodeURIComponent(d)}`}
                  className={`rounded-xl border px-3 py-2 text-sm transition ${
                    inMonth ? "border-white/10 bg-white/5 hover:bg-white/10" : "border-transparent bg-white/0 text-muted-foreground/60 hover:bg-white/5"
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <div className="font-semibold">{Number(d.split("-")[2])}</div>
                    {count ? <div className="text-xs text-amber-200">{count}</div> : <div className="text-xs text-muted-foreground">0</div>}
                  </div>
                </a>
              );
            })}
          </div>
        </LuxuryCard>
      ) : view === "week" ? (
        <div className="grid gap-4 lg:grid-cols-7">
          {weekDays.map((d) => {
            const list = groupedByDay.get(d) ?? [];
            return (
              <LuxuryCard key={d} className="p-4">
                <div className="flex items-center justify-between gap-2">
                  <a href={`/business/calendar?view=day&day=${encodeURIComponent(d)}`} className="text-sm font-semibold">
                    {d}
                  </a>
                  <div className="text-xs text-muted-foreground">{list.length}</div>
                </div>
                <div className="mt-3 grid gap-2">
                  {list.map((r) => (
                    <div key={r.id} className="rounded-lg border border-white/10 bg-white/5 p-3">
                      <div className="flex items-center justify-between gap-2">
                        <div className="text-xs font-medium">
                          {formatTime(r.start_at)}-{formatTime(r.end_at)}
                        </div>
                        <div className="text-[11px] text-muted-foreground">{r.status}</div>
                      </div>
                      <div className="mt-1 truncate text-xs">{r.service_name_en ?? "Service"}</div>
                      <div className="mt-1 truncate text-[11px] text-muted-foreground">
                        {(r.customer_name ?? "").trim() || "Customer"} • {(barberNameById.get(r.barber_id ?? "") ?? "Unassigned").trim() || "Unassigned"}
                      </div>
                    </div>
                  ))}
                  {!list.length ? <div className="text-sm text-muted-foreground">No bookings</div> : null}
                </div>
              </LuxuryCard>
            );
          })}
        </div>
      ) : orderedBarberKeys.length ? (
        <>
          <DayCalendarBoard
            day={day}
            shopId={shopId}
            bufferMinutes={Number((shopMeta as { buffer_minutes?: number | null } | null)?.buffer_minutes ?? 0)}
            barbers={(barbers ?? []).map((b) => ({ id: b.id, name: b.display_name ?? "Barber" }))}
            rows={rows.filter((row) => row.barber_id)}
          />

          <div className="grid gap-4">
            {orderedBarberKeys.map((barberId) => {
              const items = groupedByBarber.get(barberId) ?? [];
              const title = barberId === "unassigned" ? "Unassigned" : barberNameById.get(barberId) ?? "Barber";
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
                          <div className="mt-2 text-xs text-amber-200">Deposit: {Number(r.deposit_required_amount).toFixed(3)} BHD</div>
                        ) : null}
                        <div className="mt-3">
                          <form action={reschedule} className="flex flex-wrap items-center gap-2">
                            <input type="hidden" name="id" value={r.id} />
                            <input
                              type="datetime-local"
                              name="start_at"
                              defaultValue={r.start_at ? new Date(new Date(r.start_at).getTime() - new Date(r.start_at).getTimezoneOffset() * 60_000).toISOString().slice(0, 16) : ""}
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
        </>
      ) : (
        <LuxuryCard className="p-8 text-center text-sm text-muted-foreground">No bookings for this period.</LuxuryCard>
      )}
    </div>
  );
}

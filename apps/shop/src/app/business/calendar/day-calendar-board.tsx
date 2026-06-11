"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";

type BarberLane = {
  id: string;
  name: string;
};

type BookingItem = {
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

type PendingMove = {
  bookingId: string;
  barberId: string;
  startIso: string;
};

const HOUR_START = 8;
const HOUR_END = 22;
const SLOT_MINUTES = 30;
const PIXELS_PER_MINUTE = 1.2;

function formatTime(value: string) {
  return Intl.DateTimeFormat("en", { timeStyle: "short" }).format(new Date(value));
}

function combineDateAndMinutes(day: string, minutesFromMidnight: number) {
  const hours = Math.floor(minutesFromMidnight / 60);
  const minutes = minutesFromMidnight % 60;
  const hh = String(hours).padStart(2, "0");
  const mm = String(minutes).padStart(2, "0");
  return new Date(`${day}T${hh}:${mm}:00`);
}

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong.";
  if (m.includes("BOOKING_OVERLAP")) return "That slot conflicts with another booking.";
  if (m.includes("BARBER_TIME_OFF")) return "The barber is not available at that time.";
  if (m.includes("TOO_LATE_TO_RESCHEDULE")) return "This booking can no longer be rescheduled.";
  if (m.includes("BOOKING_NOT_RESCHEDULABLE")) return "This booking cannot be rescheduled from its current status.";
  if (m.toLowerCase().includes("permission") || m.includes("FORBIDDEN")) return "Permission denied.";
  return m;
}

export function DayCalendarBoard({
  day,
  shopId,
  bufferMinutes,
  barbers,
  rows
}: {
  day: string;
  shopId: string;
  bufferMinutes: number;
  barbers: BarberLane[];
  rows: BookingItem[];
}) {
  const router = useRouter();
  const [draggingId, setDraggingId] = useState<string | null>(null);
  const [hoverSlot, setHoverSlot] = useState<PendingMove | null>(null);
  const [pendingMove, setPendingMove] = useState<PendingMove | null>(null);
  const [saving, setSaving] = useState(false);
  const [availabilityLoading, setAvailabilityLoading] = useState(false);
  const [availableByBarber, setAvailableByBarber] = useState<Record<string, Set<number>>>({});
  const [error, setError] = useState<string | null>(null);

  const bookingsByBarber = useMemo(() => {
    const map = new Map<string, BookingItem[]>();
    for (const row of rows) {
      const key = row.barber_id ?? "unassigned";
      const list = map.get(key) ?? [];
      list.push(row);
      map.set(key, list);
    }
    return map;
  }, [rows]);

  const slots = useMemo(() => {
    const values: number[] = [];
    for (let mins = HOUR_START * 60; mins <= HOUR_END * 60; mins += SLOT_MINUTES) values.push(mins);
    return values;
  }, []);

  const gridHeight = (HOUR_END - HOUR_START) * 60 * PIXELS_PER_MINUTE;

  function overlaps(candidate: PendingMove) {
    const moving = rows.find((r) => r.id === candidate.bookingId);
    if (!moving) return true;
    const start = new Date(candidate.startIso);
    const end = new Date(start.getTime() + moving.duration_minutes * 60_000);
    const laneRows = bookingsByBarber.get(candidate.barberId) ?? [];

    return laneRows.some((row) => {
      if (row.id === moving.id) return false;
      if (!["pending", "confirmed", "rescheduled", "in_progress"].includes(row.status)) return false;
      const rowStart = new Date(row.start_at).getTime();
      const rowEnd = new Date(row.end_at).getTime() + bufferMinutes * 60_000;
      return start.getTime() < rowEnd && end.getTime() > rowStart;
    });
  }

  function isAvailable(candidate: PendingMove) {
    const set = availableByBarber[candidate.barberId];
    if (!set || set.size === 0) return true;
    return set.has(new Date(candidate.startIso).getTime());
  }

  async function loadAvailability(bookingId: string) {
    const moving = rows.find((r) => r.id === bookingId);
    if (!moving) return;
    setAvailabilityLoading(true);
    try {
      const subset = barbers.slice(0, 24);
      const results = await Promise.all(
        subset.map(async (b) => {
          const url = new URL("/business/calendar/available", window.location.origin);
          url.searchParams.set("barberId", b.id);
          url.searchParams.set("day", day);
          url.searchParams.set("durationMinutes", String(moving.duration_minutes));
          url.searchParams.set("excludeBookingId", bookingId);
          url.searchParams.set("shopId", shopId);
          const res = await fetch(url.toString(), { method: "GET" });
          const json = (await res.json().catch(() => null)) as { times?: string[] } | null;
          const set = new Set<number>();
          for (const t of json?.times ?? []) {
            const ms = new Date(t).getTime();
            if (Number.isFinite(ms)) set.add(ms);
          }
          return [b.id, set] as const;
        })
      );

      const next: Record<string, Set<number>> = {};
      for (const [id, set] of results) next[id] = set;
      setAvailableByBarber(next);
    } catch {
      setAvailableByBarber({});
    } finally {
      setAvailabilityLoading(false);
    }
  }

  async function commitMove(move: PendingMove) {
    setSaving(true);
    setError(null);
    try {
      const res = await fetch("/business/calendar/move", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          bookingId: move.bookingId,
          shopId,
          newStartAt: move.startIso,
          barberId: move.barberId
        })
      });

      const payload = (await res.json().catch(() => null)) as { error?: string } | null;
      if (!res.ok) {
        setError(userFacingDbError(payload?.error ?? "Failed to move booking."));
        return;
      }

      setPendingMove(null);
      setHoverSlot(null);
      setDraggingId(null);
      router.refresh();
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="grid gap-4">
      <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="grid gap-1">
            <div className="text-sm font-semibold">Drag & drop scheduler</div>
            <div className="text-xs text-muted-foreground">Drag a booking onto an available slot (including other barbers), then confirm the move.</div>
          </div>
          {pendingMove ? (
            <div className="flex items-center gap-2">
              <div className="text-xs text-muted-foreground">{formatTime(pendingMove.startIso)}</div>
              <button
                type="button"
                onClick={() => void commitMove(pendingMove)}
                disabled={saving}
                className="rounded-md border border-white/10 bg-white/10 px-3 py-2 text-xs font-medium transition hover:bg-white/15 disabled:opacity-50"
              >
                {saving ? "Saving..." : "Confirm move"}
              </button>
              <button
                type="button"
                onClick={() => {
                  setPendingMove(null);
                  setHoverSlot(null);
                  setDraggingId(null);
                }}
                className="rounded-md border border-white/10 bg-white/5 px-3 py-2 text-xs text-muted-foreground transition hover:bg-white/10 hover:text-foreground"
              >
                Cancel
              </button>
            </div>
          ) : null}
        </div>
        {availabilityLoading ? <div className="mt-2 text-xs text-muted-foreground">Loading availability…</div> : null}
        {error ? <div className="mt-3 rounded-md border border-red-500/40 bg-red-500/10 px-3 py-2 text-sm text-red-200">{error}</div> : null}
      </div>

      <div className="grid gap-4 xl:grid-cols-2 2xl:grid-cols-3">
        {barbers.map((barber) => {
          const laneRows = bookingsByBarber.get(barber.id) ?? [];
          return (
            <div key={barber.id} className="rounded-2xl border border-white/10 bg-white/5 p-4">
              <div className="mb-3 flex items-center justify-between gap-2">
                <div className="text-sm font-semibold">{barber.name}</div>
                <div className="text-xs text-muted-foreground">{laneRows.length} bookings</div>
              </div>

              <div className="relative overflow-hidden rounded-xl border border-white/10 bg-black/20" style={{ height: `${gridHeight}px` }}>
                {slots.map((slotMins) => {
                  const slotDate = combineDateAndMinutes(day, slotMins);
                  const slotIso = slotDate.toISOString();
                  const candidate =
                    draggingId && slotDate.getTime() > Date.now()
                      ? {
                          bookingId: draggingId,
                          barberId: barber.id,
                          startIso: slotIso
                        }
                      : null;

                  const blocked = candidate ? overlaps(candidate) || !isAvailable(candidate) : false;
                  const activeHover =
                    hoverSlot?.bookingId === draggingId && hoverSlot?.barberId === barber.id && hoverSlot?.startIso === slotIso;

                  return (
                    <div
                      key={`${barber.id}-${slotMins}`}
                      className={`absolute inset-x-0 border-t px-2 ${
                        activeHover
                          ? blocked
                            ? "border-red-500/40 bg-red-500/10"
                            : "border-amber-400/40 bg-amber-400/10"
                          : "border-white/10"
                      }`}
                      style={{ top: `${(slotMins - HOUR_START * 60) * PIXELS_PER_MINUTE}px`, height: `${SLOT_MINUTES * PIXELS_PER_MINUTE}px` }}
                      onDragOver={(event) => {
                        if (!candidate) return;
                        event.preventDefault();
                        setHoverSlot(candidate);
                      }}
                      onDrop={(event) => {
                        if (!candidate) return;
                        event.preventDefault();
                        if (blocked) {
                          setError("That slot is not available.");
                          return;
                        }
                        setError(null);
                        setPendingMove(candidate);
                        setHoverSlot(candidate);
                      }}
                    >
                      <div className="pt-1 text-[10px] text-muted-foreground">
                        {slotDate.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })}
                      </div>
                    </div>
                  );
                })}

                {laneRows.map((row) => {
                  const start = new Date(row.start_at);
                  const dayMinutes = start.getHours() * 60 + start.getMinutes();
                  const top = Math.max(0, dayMinutes - HOUR_START * 60) * PIXELS_PER_MINUTE;
                  const height = Math.max(SLOT_MINUTES, row.duration_minutes) * PIXELS_PER_MINUTE;
                  const isDragging = draggingId === row.id;
                  const late = start.getTime() <= Date.now();
                  return (
                    <div
                      key={row.id}
                      draggable={!late}
                      onDragStart={() => {
                        setDraggingId(row.id);
                        setPendingMove(null);
                        setError(null);
                        void loadAvailability(row.id);
                      }}
                      onDragEnd={() => {
                        setDraggingId(null);
                        setHoverSlot(null);
                      }}
                      className={`absolute left-2 right-2 rounded-xl border px-3 py-2 shadow-soft transition ${
                        isDragging
                          ? "border-amber-400/50 bg-amber-400/15 opacity-70"
                          : "border-white/10 bg-neutral-900/95 hover:border-white/20"
                      } ${late ? "cursor-not-allowed opacity-70" : "cursor-grab active:cursor-grabbing"}`}
                      style={{ top: `${top}px`, minHeight: `${height}px` }}
                    >
                      <div className="flex items-center justify-between gap-2">
                        <div className="truncate text-xs font-semibold">{row.service_name_en ?? "Service"}</div>
                        <div className="text-[10px] uppercase tracking-wide text-muted-foreground">{row.status}</div>
                      </div>
                      <div className="mt-1 text-[11px] text-white/90">
                        {(row.customer_name ?? "").trim() || "Customer"}
                        {row.customer_email ? ` • ${row.customer_email}` : ""}
                      </div>
                      <div className="mt-1 text-[10px] text-muted-foreground">
                        {formatTime(row.start_at)} - {formatTime(row.end_at)}
                      </div>
                      {Number(row.deposit_required_amount ?? 0) > 0 ? (
                        <div className="mt-1 text-[10px] text-amber-200">Deposit {Number(row.deposit_required_amount).toFixed(3)} BHD</div>
                      ) : null}
                    </div>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

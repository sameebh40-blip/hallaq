"use client";

import { useEffect, useMemo, useState } from "react";

import { Button } from "@hallaq/ui/button";
import { cn } from "@hallaq/ui/cn";

import { createSupabaseBrowserClient } from "@hallaq/supabase/browser";

type Props = {
  bookingId: string;
  barberId: string;
  durationMinutes: number;
  initialMonth: string;
  successHref: string;
};

function isoDate(date: Date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function monthLabel(date: Date) {
  return new Intl.DateTimeFormat("en", { month: "long", year: "numeric", timeZone: "Asia/Bahrain" }).format(date);
}

function formatTimeBahrain(iso: string) {
  return new Intl.DateTimeFormat("en", { hour: "numeric", minute: "2-digit", hour12: true, timeZone: "Asia/Bahrain" }).format(new Date(iso));
}

function createMonthGrid(anchor: Date) {
  const first = new Date(anchor.getFullYear(), anchor.getMonth(), 1);
  const startWeekday = first.getDay();
  const start = new Date(first);
  start.setDate(first.getDate() - startWeekday);
  const cells: Date[] = [];
  for (let i = 0; i < 42; i++) {
    const d = new Date(start);
    d.setDate(start.getDate() + i);
    cells.push(d);
  }
  return cells;
}

function segmentedTimes(times: string[]) {
  const morning: string[] = [];
  const afternoon: string[] = [];
  const evening: string[] = [];
  for (const t of times) {
    const d = new Date(t);
    const h = Number(new Intl.DateTimeFormat("en", { hour: "numeric", hour12: false, timeZone: "Asia/Bahrain" }).format(d));
    if (h < 12) morning.push(t);
    else if (h < 17) afternoon.push(t);
    else evening.push(t);
  }
  return { morning, afternoon, evening };
}

export function AdminAppointmentRescheduleClient({ bookingId, barberId, durationMinutes, initialMonth, successHref }: Props) {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [month, setMonth] = useState(() => {
    const d = new Date(initialMonth);
    return Number.isNaN(d.getTime()) ? new Date() : d;
  });
  const [availableDays, setAvailableDays] = useState<Set<string>>(new Set());
  const [calendarLoading, setCalendarLoading] = useState(false);
  const [selectedDate, setSelectedDate] = useState<Date | null>(null);
  const [timeLoading, setTimeLoading] = useState(false);
  const [times, setTimes] = useState<string[]>([]);
  const [selectedTime, setSelectedTime] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function userFacingDbError(message: string) {
    const m = (message ?? "").trim();
    if (!m) return "Something went wrong.";
    const l = m.toLowerCase();
    if (l.includes("too_late_to_reschedule")) return "This booking can no longer be rescheduled.";
    if (l.includes("booking_overlap") || l.includes("exclude")) return "This time is no longer available. Please choose another time.";
    if (l.includes("barber_time_off")) return "The barber is not available at that time. Please choose another time.";
    if (l.includes("forbidden") || l.includes("permission denied") || l.includes("row-level security")) return "Permission denied.";
    return m;
  }

  const monthCells = useMemo(() => createMonthGrid(month), [month]);
  const timeGroups = useMemo(() => segmentedTimes(times), [times]);

  useEffect(() => {
    void loadDays(month);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function loadDays(target: Date) {
    setCalendarLoading(true);
    setError(null);
    const monthIso = `${target.getFullYear()}-${String(target.getMonth() + 1).padStart(2, "0")}-01`;
    const { data, error } = await supabase.rpc("get_available_days", {
      barber: barberId,
      month: monthIso,
      duration_minutes: durationMinutes,
      slot_minutes: 30
    });
    if (error) {
      setAvailableDays(new Set());
      setCalendarLoading(false);
      setError(userFacingDbError(error.message));
      return;
    }
    const next = new Set<string>();
    for (const row of ((data ?? []) as Array<{ day?: string; has_slots?: boolean }>)) {
      if (row.day && row.has_slots) next.add(String(row.day));
    }
    setAvailableDays(next);
    setCalendarLoading(false);
  }

  async function loadTimes(day: Date) {
    setTimeLoading(true);
    setError(null);
    const { data, error } = await supabase.rpc("get_available_times", {
      barber: barberId,
      day: isoDate(day),
      duration_minutes: durationMinutes
    });
    if (error) {
      setTimeLoading(false);
      setTimes([]);
      setError(userFacingDbError(error.message));
      return;
    }
    const next = ((data ?? []) as Array<{ start_at?: string } | string>)
      .map((row) => (typeof row === "string" ? row : row.start_at ?? ""))
      .filter(Boolean);
    setTimes(next);
    setTimeLoading(false);
  }

  async function save() {
    if (!selectedTime) return;
    setSaving(true);
    setError(null);
    const { error } = await supabase.rpc("reschedule_booking", {
      booking_id: bookingId,
      new_start_at: selectedTime
    });
    if (error) {
      setSaving(false);
      setError(userFacingDbError(error.message));
      return;
    }
    window.location.href = successHref;
  }

  const monthKey = `${month.getFullYear()}-${month.getMonth()}`;

  return (
    <div className="flex flex-col gap-4">
      {error ? <div className="rounded-[18px] border border-rose-500/25 bg-rose-500/10 px-4 py-3 text-sm font-semibold text-rose-200">{error}</div> : null}
      <div className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-4">
        <div className="flex items-center justify-between">
          <button
            type="button"
            className="rounded-[14px] border border-[#2A2A2A] bg-black/20 px-3 py-2 text-[12px] font-extrabold text-white"
            onClick={() => {
              const next = new Date(month.getFullYear(), month.getMonth() - 1, 1);
              setMonth(next);
              void loadDays(next);
            }}
          >
            Prev
          </button>
          <div className="text-sm font-extrabold text-white">{monthLabel(month)}</div>
          <button
            type="button"
            className="rounded-[14px] border border-[#2A2A2A] bg-black/20 px-3 py-2 text-[12px] font-extrabold text-white"
            onClick={() => {
              const next = new Date(month.getFullYear(), month.getMonth() + 1, 1);
              setMonth(next);
              void loadDays(next);
            }}
          >
            Next
          </button>
        </div>
        <div className="mt-4 grid grid-cols-7 gap-2 text-center text-[11px] font-extrabold text-[#9E9E9E]">
          {["S", "M", "T", "W", "T", "F", "S"].map((d) => (
            <div key={d}>{d}</div>
          ))}
        </div>
        <div className="mt-3 grid grid-cols-7 gap-2">
          {monthCells.map((d, idx) => {
            const key = isoDate(d);
            const selected = selectedDate ? isoDate(selectedDate) === key : false;
            const inMonth = d.getMonth() === month.getMonth();
            const isPast = d.getTime() < new Date().setHours(0, 0, 0, 0);
            const enabled = inMonth && !isPast && availableDays.has(key);
            return (
              <button
                key={`${monthKey}-${idx}`}
                type="button"
                disabled={calendarLoading || !enabled}
                className={cn(
                  "flex h-10 w-10 items-center justify-center rounded-[18px] text-sm font-extrabold",
                  selected ? "bg-[hsl(var(--gold))] text-black" : "bg-black/20 text-white",
                  !enabled ? "opacity-40" : ""
                )}
                onClick={() => {
                  setSelectedDate(d);
                  setSelectedTime(null);
                  void loadTimes(d);
                }}
              >
                {d.getDate()}
              </button>
            );
          })}
        </div>
      </div>

      <div className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-4">
        {timeLoading ? (
          <div className="text-sm font-semibold text-[#9E9E9E]">Loading times...</div>
        ) : times.length ? (
          <div className="flex flex-col gap-5">
            {([
              ["Morning", timeGroups.morning],
              ["Afternoon", timeGroups.afternoon],
              ["Evening", timeGroups.evening]
            ] as const).map(([label, items]) =>
              items.length ? (
                <div key={label}>
                  <div className="text-[12px] font-extrabold text-[#9E9E9E]">{label}</div>
                  <div className="mt-2 grid grid-cols-3 gap-2">
                    {items.map((t) => (
                      <button
                        key={t}
                        type="button"
                        className={cn(
                          "rounded-[16px] border px-3 py-3 text-[12px] font-extrabold",
                          selectedTime === t ? "border-[hsl(var(--gold))] bg-[hsl(var(--gold))] text-black" : "border-[#2A2A2A] bg-black/20 text-white"
                        )}
                        onClick={() => setSelectedTime(t)}
                      >
                        {formatTimeBahrain(t)}
                      </button>
                    ))}
                  </div>
                </div>
              ) : null
            )}
          </div>
        ) : (
          <div className="text-sm font-semibold text-[#9E9E9E]">Choose a date to see available times.</div>
        )}
      </div>

      <Button className="h-12 w-full rounded-[16px] bg-[hsl(var(--gold))] text-black hover:bg-[hsl(var(--gold))]" disabled={!selectedTime || saving} onClick={() => void save()}>
        {saving ? "Saving..." : "Confirm Changes"}
      </Button>
    </div>
  );
}

"use client";

import { useEffect, useRef, useState } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { createAppSupabaseBrowserClient } from "@/lib/supabase-browser";

type Booking = {
  id: string;
  start_at: string;
  end_at: string;
  status: string;
  customer_name: string | null;
  service_name: string | null;
};

const HOUR_HEIGHT = 64; // px per hour
const START_HOUR = 0;
const END_HOUR = 24;
const TOTAL_HOURS = END_HOUR - START_HOUR;

const STATUS_COLORS: Record<string, string> = {
  pending: "bg-yellow-100 border-yellow-300 text-yellow-900",
  confirmed: "bg-blue-100 border-blue-300 text-blue-900",
  in_progress: "bg-sky-200 border-sky-400 text-sky-900",
  completed: "bg-green-100 border-green-300 text-green-900",
  cancelled: "bg-gray-100 border-gray-300 text-gray-500 line-through",
  no_show: "bg-red-100 border-red-300 text-red-800",
};

function toLocalDateString(date: Date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}

function fmt12(hour: number) {
  if (hour === 0) return "12 am";
  if (hour < 12) return `${hour} am`;
  if (hour === 12) return "12 pm";
  return `${hour - 12} pm`;
}

function minutesFromMidnight(iso: string) {
  const d = new Date(iso);
  return d.getHours() * 60 + d.getMinutes();
}

export function BarberCalendar({ barberId, shopId }: { barberId: string; shopId?: string | null }) {
  const [date, setDate] = useState(() => new Date());
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loading, setLoading] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  const dateStr = toLocalDateString(date);

  useEffect(() => {
    // Scroll to 7am on mount
    if (scrollRef.current) {
      scrollRef.current.scrollTop = 7 * HOUR_HEIGHT - 16;
    }
  }, []);

  useEffect(() => {
    setLoading(true);
    const supabase = createAppSupabaseBrowserClient();
    const dayStart = `${dateStr}T00:00:00`;
    const dayEnd = `${dateStr}T23:59:59`;

    const baseQuery = supabase
      .from("bookings")
      .select("id, start_at, end_at, status, profiles(full_name), services(name_en, name_ar)")
      .gte("start_at", dayStart)
      .lte("start_at", dayEnd)
      .order("start_at", { ascending: true });

    (shopId
      ? baseQuery.eq("shop_id", shopId).or(`barber_id.eq.${barberId},barber_id.is.null`)
      : baseQuery.eq("barber_id", barberId))
      .then(({ data }) => {
        const rows = (data ?? []) as Array<Record<string, unknown>>;
        setBookings(
          rows.map((r) => {
            const rawProfile = r.profiles as unknown;
            const profile =
              (Array.isArray(rawProfile)
                ? (rawProfile[0] as Record<string, unknown> | undefined)
                : (rawProfile as Record<string, unknown> | null)) ?? null;
            const rawService = r.services as unknown;
            const service =
              (Array.isArray(rawService)
                ? (rawService[0] as Record<string, unknown> | undefined)
                : (rawService as Record<string, unknown> | null)) ?? null;
            return {
              id: String(r.id ?? ""),
              start_at: String(r.start_at ?? ""),
              end_at: String(r.end_at ?? ""),
              status: String(r.status ?? "pending"),
              customer_name: (profile?.full_name as string | null) ?? null,
              service_name:
                ((service?.name_en ?? service?.name_ar) as string | null) ?? null,
            };
          })
        );
        setLoading(false);
      });
  }, [barberId, dateStr]);

  function goDay(delta: number) {
    setDate((d) => {
      const next = new Date(d);
      next.setDate(next.getDate() + delta);
      return next;
    });
  }

  function goToday() {
    setDate(new Date());
  }

  const isToday = toLocalDateString(new Date()) === dateStr;

  const displayDate = date.toLocaleDateString("en", {
    weekday: "short",
    month: "short",
    day: "numeric",
  });

  return (
    <div className="flex flex-col gap-0 overflow-hidden rounded-2xl border bg-white shadow-soft">
      {/* Header */}
      <div className="flex items-center gap-2 border-b px-4 py-3">
        <button
          onClick={goToday}
          className="rounded-xl border px-3 py-1.5 text-xs font-semibold text-[#111111] hover:bg-secondary/60 transition-colors"
        >
          Today
        </button>
        <button
          onClick={() => goDay(-1)}
          className="rounded-xl border p-1.5 hover:bg-secondary/60 transition-colors"
        >
          <ChevronLeft className="h-4 w-4 text-[#111111]" />
        </button>
        <button
          onClick={() => goDay(1)}
          className="rounded-xl border p-1.5 hover:bg-secondary/60 transition-colors"
        >
          <ChevronRight className="h-4 w-4 text-[#111111]" />
        </button>
        <span className="flex-1 text-center text-sm font-semibold text-[#111111]">
          {displayDate}
          {isToday && (
            <span className="ml-2 rounded-full bg-[#111111] px-2 py-0.5 text-[10px] font-semibold text-white">
              Today
            </span>
          )}
        </span>
        {loading && (
          <span className="text-[10px] text-muted-foreground animate-pulse">
            Loading...
          </span>
        )}
      </div>

      {/* Calendar grid */}
      <div
        ref={scrollRef}
        className="relative overflow-y-auto"
        style={{ height: "520px" }}
      >
        <div
          className="relative"
          style={{ height: TOTAL_HOURS * HOUR_HEIGHT }}
        >
          {/* Hour lines + labels */}
          {Array.from({ length: TOTAL_HOURS + 1 }, (_, i) => i + START_HOUR).map((hour) => (
            <div
              key={hour}
              className="absolute left-0 right-0 flex items-start"
              style={{ top: (hour - START_HOUR) * HOUR_HEIGHT }}
            >
              <span className="w-14 shrink-0 pr-3 pt-0.5 text-right text-[10px] font-medium text-muted-foreground select-none">
                {hour < END_HOUR ? fmt12(hour) : ""}
              </span>
              <div className="flex-1 border-t border-border/60" />
            </div>
          ))}

          {/* Half-hour dashed lines */}
          {Array.from({ length: TOTAL_HOURS }, (_, i) => i + START_HOUR).map((hour) => (
            <div
              key={`half-${hour}`}
              className="absolute left-14 right-0 border-t border-dashed border-border/30"
              style={{ top: (hour - START_HOUR) * HOUR_HEIGHT + HOUR_HEIGHT / 2 }}
            />
          ))}

          {/* Current time indicator */}
          {isToday && (() => {
            const now = new Date();
            const mins = now.getHours() * 60 + now.getMinutes();
            const top = (mins / 60) * HOUR_HEIGHT;
            return (
              <div
                className="absolute left-14 right-0 z-20 flex items-center"
                style={{ top }}
              >
                <div className="h-2.5 w-2.5 rounded-full bg-rose-500 -translate-x-1.5" />
                <div className="flex-1 border-t-2 border-rose-500" />
              </div>
            );
          })()}

          {/* Booking blocks */}
          {bookings.map((b) => {
            const startMin = minutesFromMidnight(b.start_at);
            const endMin = minutesFromMidnight(b.end_at);
            const durMin = Math.max(endMin - startMin, 15);
            const top = (startMin / 60) * HOUR_HEIGHT;
            const height = Math.max((durMin / 60) * HOUR_HEIGHT, 24);

            const startFmt = new Date(b.start_at).toLocaleTimeString("en", {
              hour: "numeric",
              minute: "2-digit",
              hour12: true,
            });
            const endFmt = new Date(b.end_at).toLocaleTimeString("en", {
              hour: "numeric",
              minute: "2-digit",
              hour12: true,
            });

            const colorClass = STATUS_COLORS[b.status] ?? STATUS_COLORS.confirmed;

            return (
              <div
                key={b.id}
                className={`absolute left-14 right-2 z-10 rounded-lg border px-2 py-1 text-xs ${colorClass} overflow-hidden`}
                style={{ top: top + 1, height: height - 2 }}
              >
                <div className="font-semibold truncate leading-tight">
                  {startFmt} – {endFmt}{" "}
                  <span className="font-normal opacity-70">
                    {b.customer_name ?? "Walk-In"}
                  </span>
                </div>
                {height > 32 && (
                  <div className="truncate opacity-80 text-[10px]">
                    {b.service_name ?? "Service"}
                  </div>
                )}
              </div>
            );
          })}

          {/* Empty state */}
          {!loading && bookings.length === 0 && (
            <div
              className="absolute left-14 right-2 flex items-center justify-center text-xs text-muted-foreground"
              style={{ top: 8 * HOUR_HEIGHT, height: 3 * HOUR_HEIGHT }}
            >
              No bookings for this day
            </div>
          )}
        </div>
      </div>

      {/* Footer legend */}
      <div className="flex flex-wrap gap-2 border-t px-4 py-2">
        {Object.entries(STATUS_COLORS).map(([status, cls]) => (
          <span key={status} className={`rounded-full border px-2 py-0.5 text-[10px] font-medium ${cls}`}>
            {status.replace("_", " ")}
          </span>
        ))}
      </div>
    </div>
  );
}


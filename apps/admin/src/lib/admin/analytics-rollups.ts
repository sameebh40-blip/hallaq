import { createSupabaseServerClient } from "@hallaq/supabase/server";

import type { ChartPoint } from "@/components/simple-line-chart";

function isoDay(d: Date) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

export async function getFunnelDaily(days = 30) {
  const supabase = await createSupabaseServerClient();
  const start = new Date();
  start.setDate(start.getDate() - Math.max(1, days - 1));
  const startDay = isoDay(start);

  const { data } = await supabase
    .from("analytics_funnel_daily")
    .select("day, home_view_sessions, shop_open_sessions, barber_open_sessions, booking_started_sessions, booking_completed_sessions")
    .gte("day", startDay)
    .order("day", { ascending: true });

  const rows = (data ?? []) as Array<{
    day: string;
    home_view_sessions: number;
    shop_open_sessions: number;
    barber_open_sessions: number;
    booking_started_sessions: number;
    booking_completed_sessions: number;
  }>;

  const conversionPoints: ChartPoint[] = rows.map((r) => {
    const home = Number(r.home_view_sessions ?? 0);
    const completed = Number(r.booking_completed_sessions ?? 0);
    const pct = home ? (completed / home) * 100 : 0;
    return { label: r.day.slice(5), value: Math.round(pct * 10) / 10 };
  });

  const startedPoints: ChartPoint[] = rows.map((r) => ({ label: r.day.slice(5), value: Number(r.booking_started_sessions ?? 0) }));
  const completedPoints: ChartPoint[] = rows.map((r) => ({ label: r.day.slice(5), value: Number(r.booking_completed_sessions ?? 0) }));
  const homePoints: ChartPoint[] = rows.map((r) => ({ label: r.day.slice(5), value: Number(r.home_view_sessions ?? 0) }));

  return { rows, conversionPoints, startedPoints, completedPoints, homePoints };
}

export async function getTopPlatforms(days = 30, limit = 8) {
  const supabase = await createSupabaseServerClient();
  const start = new Date();
  start.setDate(start.getDate() - Math.max(1, days - 1));
  const startDay = isoDay(start);

  const { data } = await supabase
    .from("analytics_device_daily")
    .select("platform, sessions")
    .gte("day", startDay);

  const rows = (data ?? []) as Array<{ platform: string; sessions: number }>;
  const map = new Map<string, number>();
  rows.forEach((r) => map.set(r.platform, (map.get(r.platform) ?? 0) + Number(r.sessions ?? 0)));

  return Array.from(map.entries())
    .map(([platform, sessions]) => ({ platform, sessions }))
    .sort((a, b) => b.sessions - a.sessions)
    .slice(0, limit);
}


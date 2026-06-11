import { NextResponse } from "next/server";

import { getMyProfile } from "@hallaq/supabase/profile";

import { getMyShopContext } from "@/lib/my-shop-context";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  const url = new URL(req.url);
  const barberId = (url.searchParams.get("barberId") ?? "").trim();
  const day = (url.searchParams.get("day") ?? "").trim();
  const durationMinutes = Number(url.searchParams.get("durationMinutes") ?? 0);
  const excludeBookingId = (url.searchParams.get("excludeBookingId") ?? "").trim();
  const requestedShopId = (url.searchParams.get("shopId") ?? "").trim();

  if (!barberId || !day || !excludeBookingId || !Number.isFinite(durationMinutes) || durationMinutes <= 0) {
    return NextResponse.json({ error: "Missing barberId/day/durationMinutes/excludeBookingId." }, { status: 400 });
  }

  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);
  const ctx = await getMyShopContext(supabase);
  const shopId = ctx.shop?.id ?? (profile?.role === "admin" ? requestedShopId || null : null);
  if (!shopId) return NextResponse.json({ error: "No shop selected." }, { status: 400 });

  const { data: barber, error: barberError } = await supabase.from("barbers").select("id, shop_id").eq("id", barberId).maybeSingle();
  if (barberError) return NextResponse.json({ error: barberError.message }, { status: 500 });
  if (!barber || barber.shop_id !== shopId) return NextResponse.json({ error: "Barber not found in this shop." }, { status: 404 });

  const { data, error } = await supabase.rpc("get_available_times_for_booking_move", {
    barber: barberId,
    day,
    duration_minutes: Math.round(durationMinutes),
    exclude_booking_id: excludeBookingId,
    slot_minutes: 15
  });

  if (error) return NextResponse.json({ error: error.message }, { status: 400 });

  const times = ((data ?? []) as Array<{ start_at: string }>).map((r) => r.start_at);
  return NextResponse.json({ times });
}


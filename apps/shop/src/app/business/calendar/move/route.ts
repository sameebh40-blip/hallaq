import { NextResponse } from "next/server";

import { getMyProfile } from "@hallaq/supabase/profile";

import { getMyShopContext } from "@/lib/my-shop-context";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

export async function POST(req: Request) {
  const body = (await req.json().catch(() => null)) as { bookingId?: string; newStartAt?: string; shopId?: string; barberId?: string } | null;
  const bookingId = String(body?.bookingId ?? "").trim();
  const newStartAt = String(body?.newStartAt ?? "").trim();
  const requestedShopId = String(body?.shopId ?? "").trim();
  const newBarberId = String(body?.barberId ?? "").trim();

  if (!bookingId || !newStartAt) {
    return NextResponse.json({ error: "Missing bookingId or newStartAt." }, { status: 400 });
  }

  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);
  const ctx = await getMyShopContext(supabase);
  const shopId = ctx.shop?.id ?? (profile?.role === "admin" ? requestedShopId || null : null);

  if (!shopId) {
    return NextResponse.json({ error: "No shop selected." }, { status: 400 });
  }

  const { data: booking, error: bookingError } = await supabase.from("bookings").select("id, shop_id, barber_id").eq("id", bookingId).maybeSingle();
  if (bookingError) {
    return NextResponse.json({ error: bookingError.message }, { status: 500 });
  }
  if (!booking || booking.shop_id !== shopId) {
    return NextResponse.json({ error: "Booking not found in this shop." }, { status: 404 });
  }

  const iso = new Date(newStartAt).toISOString();
  const useReassign = newBarberId && newBarberId !== booking.barber_id;
  const { error } = useReassign
    ? await supabase.rpc("reassign_booking", { booking_id: bookingId, new_barber_id: newBarberId, new_start_at: iso })
    : await supabase.rpc("reschedule_booking", { booking_id: bookingId, new_start_at: iso });

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 400 });
  }

  return NextResponse.json({ ok: true });
}

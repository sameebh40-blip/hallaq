import Link from "next/link";

import { ShopAppointmentRescheduleClient } from "@/app/(panel)/appointments/[id]/reschedule/reschedule-client";
import { getMyShop } from "@/lib/my-shop";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type BookingRow = {
  id: string;
  start_at: string;
  barber_id: string | null;
  duration_minutes: number | null;
  status: string;
};

export default async function ShopAppointmentReschedulePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const bookingId = String(id ?? "").trim();

  const supabase = await createAppSupabaseServerClient();
  const shop = await getMyShop(supabase);
  if (!shop) {
    return <div className="text-sm text-muted-foreground">No shop assigned to this account.</div>;
  }

  const { data } = await supabase
    .from("bookings")
    .select("id, start_at, barber_id, duration_minutes, status")
    .eq("id", bookingId)
    .eq("shop_id", shop.id)
    .maybeSingle();

  const row = (data as BookingRow | null) ?? null;
  if (!row || !row.barber_id || !["pending", "confirmed", "rescheduled"].includes(row.status)) {
    return (
      <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 py-6 text-white">
        <Link href="/appointments" className="text-sm font-extrabold text-[hsl(var(--gold))]">
          Back
        </Link>
        <div className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-6">
          <div className="text-sm font-extrabold text-white">This booking cannot be rescheduled.</div>
          <div className="pt-1 text-sm font-semibold text-[#9E9E9E]">Try another booking.</div>
        </div>
      </main>
    );
  }

  const month = new Date(row.start_at);
  month.setDate(1);

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 py-6 pb-20 text-white">
      <Link href="/appointments" className="text-sm font-extrabold text-[hsl(var(--gold))]">
        Back
      </Link>
      <div>
        <div className="text-lg font-extrabold text-white">Reschedule Appointment</div>
        <div className="pt-1 text-sm font-semibold text-[#9E9E9E]">Choose a real available time for this booking.</div>
      </div>
      <ShopAppointmentRescheduleClient
        bookingId={row.id}
        barberId={row.barber_id}
        durationMinutes={row.duration_minutes ?? 30}
        initialMonth={month.toISOString()}
        successHref="/appointments"
      />
    </main>
  );
}

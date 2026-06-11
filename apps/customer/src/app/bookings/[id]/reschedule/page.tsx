import Link from "next/link";
import { redirect } from "next/navigation";

import { createAppSupabaseServerClient } from "@/lib/supabase";
import { RescheduleClient } from "@/app/bookings/[id]/reschedule/reschedule-client";

export const dynamic = "force-dynamic";

type BookingRow = {
  id: string;
  start_at: string;
  barber_id: string | null;
  duration_minutes: number | null;
  status: string;
};

export default async function BookingReschedulePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const bookingId = String(id ?? "").trim();

  const supabase = await createAppSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/sign-in?next=${encodeURIComponent(`/bookings/${bookingId}/reschedule`)}`);

  const { data } = await supabase
    .from("bookings")
    .select("id, start_at, barber_id, duration_minutes, status")
    .eq("id", bookingId)
    .eq("customer_profile_id", user.id)
    .maybeSingle();

  const row = (data as BookingRow | null) ?? null;
  if (!row || !row.barber_id || !["pending", "confirmed", "rescheduled"].includes(row.status)) {
    return (
      <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 py-6 text-white">
        <Link href={`/bookings/${encodeURIComponent(bookingId)}`} className="text-sm font-extrabold text-[hsl(var(--gold))]">
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
      <Link href={`/bookings/${encodeURIComponent(bookingId)}`} className="text-sm font-extrabold text-[hsl(var(--gold))]">
        Back
      </Link>
      <div>
        <div className="text-lg font-extrabold text-white">Reschedule Booking</div>
        <div className="pt-1 text-sm font-semibold text-[#9E9E9E]">Choose a new date and time.</div>
      </div>
      <RescheduleClient bookingId={row.id} barberId={row.barber_id} durationMinutes={row.duration_minutes ?? 30} initialMonth={month.toISOString()} />
    </main>
  );
}


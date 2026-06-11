import Link from "next/link";

import { createSupabaseServerClient } from "@hallaq/supabase/server";

import { AdminAppointmentRescheduleClient } from "@/app/(panel)/appointments/[id]/reschedule/reschedule-client";
import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type BookingRow = {
  id: string;
  start_at: string;
  barber_id: string | null;
  duration_minutes: number | null;
  status: string;
};

export default async function AdminAppointmentReschedulePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const bookingId = String(id ?? "").trim();

  const supabase = await createSupabaseServerClient();
  const { data } = await supabase
    .from("bookings")
    .select("id, start_at, barber_id, duration_minutes, status")
    .eq("id", bookingId)
    .maybeSingle();

  const row = (data as BookingRow | null) ?? null;
  if (!row || !row.barber_id || !["pending", "confirmed", "rescheduled"].includes(row.status)) {
    return (
      <PageFrame title="Reschedule appointment" subtitle="Choose a real available time.">
        <div className="mx-auto flex min-h-[40vh] max-w-md flex-col gap-4 text-white">
          <Link href="/appointments" className="text-sm font-extrabold text-[hsl(var(--gold))]">
            Back
          </Link>
          <div className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-6">
            <div className="text-sm font-extrabold text-white">This booking cannot be rescheduled.</div>
            <div className="pt-1 text-sm font-semibold text-[#9E9E9E]">Try another booking.</div>
          </div>
        </div>
      </PageFrame>
    );
  }

  const month = new Date(row.start_at);
  month.setDate(1);

  return (
    <PageFrame title="Reschedule appointment" subtitle="Choose a real available time.">
      <div className="mx-auto flex min-h-[40vh] max-w-md flex-col gap-4 text-white">
        <Link href="/appointments" className="text-sm font-extrabold text-[hsl(var(--gold))]">
          Back
        </Link>
        <AdminAppointmentRescheduleClient
          bookingId={row.id}
          barberId={row.barber_id}
          durationMinutes={row.duration_minutes ?? 30}
          initialMonth={month.toISOString()}
          successHref="/appointments"
        />
      </div>
    </PageFrame>
  );
}

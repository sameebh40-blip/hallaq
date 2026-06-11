import Link from "next/link";

import { BusinessBookingRescheduleClient } from "@/app/business/bookings/[id]/reschedule/reschedule-client";
import { getMyProfile } from "@hallaq/supabase/profile";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { BusinessPageHeader } from "@/components/business/page-header";
import { getMyShopContext } from "@/lib/my-shop-context";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type BookingRow = {
  id: string;
  start_at: string;
  barber_id: string | null;
  duration_minutes: number | null;
  status: string;
};

export default async function BusinessBookingReschedulePage({
  params,
  searchParams
}: {
  params: Promise<{ id: string }>;
  searchParams?: Promise<{ shopId?: string }>;
}) {
  const { id } = await params;
  const bookingId = String(id ?? "").trim();
  const sp = searchParams ? await searchParams : undefined;

  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);
  const ctx = await getMyShopContext(supabase);
  const shopId = ctx.shop?.id ?? (profile?.role === "admin" ? (sp?.shopId ?? null) : null);

  if (!shopId) {
    return <div className="text-sm text-muted-foreground">No shop selected.</div>;
  }

  const { data } = await supabase
    .from("bookings")
    .select("id, start_at, barber_id, duration_minutes, status")
    .eq("id", bookingId)
    .eq("shop_id", shopId)
    .maybeSingle();

  const row = (data as BookingRow | null) ?? null;
  if (!row || !row.barber_id || !["pending", "confirmed", "rescheduled"].includes(row.status)) {
    return (
      <div className="mx-auto grid w-full max-w-3xl gap-4">
        <BusinessPageHeader
          title="Reschedule Booking"
          subtitle="Choose a real available time for this booking."
          actions={
            <Button asChild variant="ghost" size="sm">
              <Link href="/business/bookings">Back</Link>
            </Button>
          }
        />
        <LuxuryCard className="p-6">
          <div className="text-sm font-semibold text-white">This booking cannot be rescheduled.</div>
          <div className="pt-1 text-sm text-muted-foreground">Try another booking.</div>
        </LuxuryCard>
      </div>
    );
  }

  const month = new Date(row.start_at);
  month.setDate(1);

  return (
    <div className="mx-auto grid w-full max-w-3xl gap-4">
      <BusinessPageHeader
        title="Reschedule Booking"
        subtitle="Choose a real available time for this booking."
        actions={
          <Button asChild variant="ghost" size="sm">
            <Link href="/business/bookings">Back</Link>
          </Button>
        }
      />
      <BusinessBookingRescheduleClient
        bookingId={row.id}
        barberId={row.barber_id}
        durationMinutes={row.duration_minutes ?? 30}
        initialMonth={month.toISOString()}
        successHref="/business/bookings"
      />
    </div>
  );
}

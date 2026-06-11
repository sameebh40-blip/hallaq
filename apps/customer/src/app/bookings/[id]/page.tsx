import Link from "next/link";
import { redirect } from "next/navigation";

import { createAppSupabaseServerClient } from "@/lib/supabase";
import { RealtimeRefresh } from "@/components/realtime-refresh";
import { SafeImage } from "@/components/safe-image";
import { BookingDetailsClientActions } from "@/app/bookings/[id]/booking-details-client";

export const dynamic = "force-dynamic";

function formatDateTime(value: string) {
  const d = new Date(value);
  return Intl.DateTimeFormat("en", { dateStyle: "medium", timeStyle: "short", timeZone: "Asia/Bahrain" }).format(d);
}

function formatBhd(value: number | string | null | undefined) {
  return `BHD ${Number(value ?? 0).toFixed(3)}`;
}

type BookingRow = {
  id: string;
  customer_profile_id: string;
  start_at: string;
  end_at: string;
  status: string;
  rescheduled_at: string | null;
  total_price: number | string | null;
  price_bhd: number | string | null;
  discount_amount: number | string | null;
  deposit_required_amount: number | string | null;
  payment_method: string | null;
  payment_status: string | null;
  source: string | null;
  cancelled_at: string | null;
  cancelled_by_profile_id: string | null;
  cancelled_by: string | null;
  cancel_reason: string | null;
  cancelled_reason: string | null;
  barbers: Array<{ id: string; profile_id: string | null; display_name: string | null; avatar_url: string | null }> | null;
  barbershops: Array<{
    id: string;
    owner_profile_id: string | null;
    name: string | null;
    area: string | null;
    address: string | null;
    phone: string | null;
    whatsapp: string | null;
    google_maps_url: string | null;
    lat: number | null;
    lng: number | null;
  }> | null;
  services: Array<{ id: string; name_en: string | null; name_ar: string | null; duration_minutes: number | null; price_bhd: number | string | null; image_url: string | null }> | null;
};

function cancelledByLabel(
  cancelledByProfileId: string | null,
  cancelledByLegacy: string | null,
  viewerId: string,
  customerProfileId: string,
  barberProfileId: string | null,
  shopOwnerProfileId: string | null
) {
  const byProfileId = (cancelledByProfileId ?? "").trim();
  if (byProfileId) {
    if (byProfileId === viewerId || byProfileId === customerProfileId) return "Cancelled by You";
    if (barberProfileId && byProfileId === barberProfileId) return "Cancelled by Barber";
    if (shopOwnerProfileId && byProfileId === shopOwnerProfileId) return "Cancelled by Shop";
    return "Cancelled";
  }

  const legacy = (cancelledByLegacy ?? "").trim();
  if (!legacy) return "Cancelled";
  const normalized = legacy.toLowerCase();
  if (normalized === "customer" || normalized === "client" || normalized === "you") return "Cancelled by You";
  if (normalized === "barber") return "Cancelled by Barber";
  if (normalized === "shop" || normalized === "shop_owner" || normalized === "owner") return "Cancelled by Shop";
  if (normalized === "admin" || normalized === "hallaq") return "Cancelled by HALLAQ";
  return "Cancelled";
}

function paymentMethodLabel(method: string | null) {
  switch ((method ?? "cash").trim().toLowerCase()) {
    case "card":
      return "Card";
    case "benefitpay":
      return "BenefitPay";
    case "apple_pay":
      return "Apple Pay";
    case "stc_pay":
      return "STC Pay";
    default:
      return "Cash at Shop";
  }
}

function statusBadge(status: string, cancelledLabel: string, rescheduledAt: string | null) {
  const s = (status ?? "").trim();
  if (rescheduledAt && s !== "cancelled") return { label: "Rescheduled", tone: "gold" as const };
  if (s === "cancelled") return { label: cancelledLabel, tone: "red" as const };
  if (s === "completed") return { label: "Completed", tone: "green" as const };
  if (s === "in_progress") return { label: "In progress", tone: "gold" as const };
  if (s === "confirmed") return { label: "Confirmed", tone: "gold" as const };
  if (s === "pending") return { label: "Pending", tone: "gold" as const };
  if (s === "rescheduled") return { label: "Rescheduled", tone: "gold" as const };
  if (s === "no_show") return { label: "No show", tone: "red" as const };
  return { label: s || "Booking", tone: "gold" as const };
}

export default async function BookingDetailsPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const bookingId = String(id ?? "").trim();

  const supabase = await createAppSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/sign-in?next=${encodeURIComponent(`/bookings/${bookingId}`)}`);

  const { data, error } = await supabase
    .from("bookings")
    .select(
      "id, customer_profile_id, start_at, end_at, status, rescheduled_at, total_price, price_bhd, discount_amount, deposit_required_amount, payment_method, payment_status, source, cancelled_at, cancelled_by_profile_id, cancelled_by, cancel_reason, cancelled_reason, barbers(id, profile_id, display_name, avatar_url), barbershops(id, owner_profile_id, name, area, address, phone, whatsapp, google_maps_url, lat, lng), services(id, name_en, name_ar, duration_minutes, price_bhd, image_url)"
    )
    .eq("id", bookingId)
    .maybeSingle();

  const row = (data as BookingRow | null) ?? null;
  if (!row || error) {
    return (
      <main className="mx-auto flex min-h-dvh max-w-md flex-col bg-black px-4 py-6 text-white">
        <Link href="/bookings" className="text-sm font-extrabold text-[hsl(var(--gold))]">
          Back
        </Link>
        <div className="mt-6 rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-6">
          <div className="text-sm font-extrabold">Booking not found</div>
          <div className="pt-1 text-sm font-semibold text-[#9E9E9E]">Please go back and try again.</div>
        </div>
      </main>
    );
  }

  const barber = row.barbers?.[0] ?? null;
  const shop = row.barbershops?.[0] ?? null;
  const service = row.services?.[0] ?? null;
  const cancelLabel = cancelledByLabel(
    row.cancelled_by_profile_id,
    row.cancelled_by,
    user.id,
    row.customer_profile_id,
    barber?.profile_id ?? null,
    shop?.owner_profile_id ?? null
  );
  const badge = statusBadge(row.status, cancelLabel, row.rescheduled_at);
  const badgeTone =
    badge.tone === "red"
      ? "border-rose-500/30 text-rose-300"
      : badge.tone === "green"
        ? "border-emerald-500/30 text-emerald-300"
        : "border-[hsl(var(--gold))]/35 text-[hsl(var(--gold))]";

  const directionsHref =
    (shop?.google_maps_url ?? "").trim() ||
    (typeof shop?.lat === "number" && typeof shop?.lng === "number"
      ? `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(`${shop.lat},${shop.lng}`)}`
      : shop?.address
        ? `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent([shop.name, shop.area, shop.address].filter(Boolean).join(", "))}`
        : null);
  const shareUrl = `/bookings/${encodeURIComponent(row.id)}`;
  const cancelReason = (row.cancelled_reason ?? row.cancel_reason ?? "").trim();

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 py-6 pb-28 text-white">
      <RealtimeRefresh subscriptions={[{ table: "bookings", filter: `id=eq.${bookingId}` }]} />
      <Link href="/bookings" className="inline-flex items-center gap-2 text-sm font-extrabold text-[hsl(var(--gold))]">
        <span>Back</span>
      </Link>

      <div className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-5 shadow-[0_18px_44px_rgba(0,0,0,0.55)]">
        <div className="flex items-start justify-between gap-3">
          <div className="flex min-w-0 flex-1 items-start gap-3">
            <div className="h-14 w-14 overflow-hidden rounded-[20px] border border-[#2A2A2A] bg-black">
              <SafeImage src={barber?.avatar_url ?? null} fallbackKey="default_barber_avatar" alt={barber?.display_name ?? "Barber"} className="h-full w-full object-cover" />
            </div>
            <div className="min-w-0 flex-1">
              <div className="truncate text-sm font-extrabold text-white">{barber?.display_name ?? shop?.name ?? "Booking"}</div>
              {shop?.name ? <div className="truncate pt-1 text-[12px] font-semibold text-[#9E9E9E]">{shop.name}</div> : null}
              {service?.name_en || service?.name_ar ? (
                <div className="truncate pt-2 text-[12px] font-semibold text-[#9E9E9E]">{service.name_en ?? service.name_ar}</div>
              ) : null}
            </div>
          </div>
          <div className={`shrink-0 rounded-full border bg-black/20 px-3 py-2 text-[11px] font-extrabold ${badgeTone}`}>{badge.label}</div>
        </div>

        <div className="mt-5 grid gap-3 text-sm">
          {row.status === "cancelled" && cancelReason ? (
            <div className="rounded-[18px] border border-rose-500/25 bg-rose-500/10 p-4 text-[13px] font-semibold text-rose-200">
              {cancelReason}
            </div>
          ) : null}
          <div className="flex items-center justify-between gap-3">
            <div className="text-[#9E9E9E]">Date & Time</div>
            <div className="text-right font-extrabold text-white">{formatDateTime(row.start_at)}</div>
          </div>
          <div className="flex items-center justify-between gap-3">
            <div className="text-[#9E9E9E]">Ends</div>
            <div className="text-right font-extrabold text-white">{formatDateTime(row.end_at)}</div>
          </div>
          {shop?.area ? (
            <div className="flex items-center justify-between gap-3">
              <div className="text-[#9E9E9E]">Area</div>
              <div className="text-right font-extrabold text-white">{shop.area}</div>
            </div>
          ) : null}
          {shop?.address ? (
            <div className="flex items-center justify-between gap-3">
              <div className="text-[#9E9E9E]">Address</div>
              <div className="text-right font-extrabold text-white">{shop.address}</div>
            </div>
          ) : null}
          <div className="flex items-center justify-between gap-3">
            <div className="text-[#9E9E9E]">Payment</div>
            <div className="text-right font-extrabold text-white">{paymentMethodLabel(row.payment_method)}</div>
          </div>
          <div className="flex items-center justify-between gap-3">
            <div className="text-[#9E9E9E]">Payment status</div>
            <div className="text-right font-extrabold text-white">{(row.payment_status ?? "unpaid").replaceAll("_", " ").toUpperCase()}</div>
          </div>
          {Number(row.deposit_required_amount ?? 0) > 0 ? (
            <div className="flex items-center justify-between gap-3">
              <div className="text-[#9E9E9E]">Deposit required</div>
              <div className="text-right font-extrabold text-white">{formatBhd(row.deposit_required_amount)}</div>
            </div>
          ) : null}
          <div className="flex items-center justify-between gap-3">
            <div className="text-[#9E9E9E]">Total</div>
            <div className="text-right text-base font-extrabold text-[hsl(var(--gold))]">{formatBhd(row.total_price ?? row.price_bhd)}</div>
          </div>
          {row.discount_amount && Number(row.discount_amount) > 0 ? (
            <div className="flex items-center justify-between gap-3">
              <div className="text-[#9E9E9E]">Discount</div>
              <div className="text-right font-extrabold text-emerald-400">- {formatBhd(row.discount_amount)}</div>
            </div>
          ) : null}
          <div className="flex items-center justify-between gap-3 pt-2">
            <div className="text-[#9E9E9E]">Booking ID</div>
            <div className="text-right font-extrabold text-white">{row.id}</div>
          </div>
        </div>
      </div>

      <BookingDetailsClientActions
        bookingId={row.id}
        shopPhone={shop?.phone ?? null}
        shopWhatsapp={shop?.whatsapp ?? null}
        directionsHref={directionsHref}
        shareUrl={shareUrl}
        status={row.status}
        startAt={row.start_at}
        endAt={row.end_at}
      />
    </main>
  );
}

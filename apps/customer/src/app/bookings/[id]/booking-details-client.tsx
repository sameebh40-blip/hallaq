"use client";

import Link from "next/link";
import { useState } from "react";

import { Button } from "@hallaq/ui/button";
import { Phone, MessageCircle, CalendarDays, MapPin, Share2 } from "lucide-react";

import { createAppSupabaseBrowserClient } from "@/lib/supabase-browser";

type Props = {
  bookingId: string;
  shopPhone: string | null;
  shopWhatsapp: string | null;
  directionsHref: string | null;
  shareUrl: string;
  status: string;
  startAt: string;
  endAt: string;
};

export function BookingDetailsClientActions({ bookingId, shopPhone, shopWhatsapp, directionsHref, shareUrl, status, startAt, endAt }: Props) {
  const [busy, setBusy] = useState(false);
  const normalizedStatus = status === "accepted" ? "confirmed" : status === "rejected" ? "cancelled" : status;
  const canManage =
    ["pending", "confirmed", "rescheduled"].includes(normalizedStatus) && new Date(startAt).getTime() > Date.now();

  function userFacingDbError(message: string) {
    const m = (message ?? "").trim();
    if (!m) return "Something went wrong.";
    const l = m.toLowerCase();
    if (l.includes("too_late_to_cancel")) return "This booking can no longer be cancelled.";
    if (l.includes("too_late_to_reschedule")) return "This booking can no longer be rescheduled.";
    if (l.includes("booking_overlap") || l.includes("exclude")) return "This time is no longer available. Please select another time.";
    if (l.includes("barber_time_off")) return "The barber is not available at that time. Please select another time.";
    if (l.includes("forbidden") || l.includes("permission denied") || l.includes("row-level security")) return "Permission denied.";
    return m;
  }

  async function cancel() {
    const ok = window.confirm("Cancel this booking?");
    if (!ok) return;
    const reason = window.prompt("Cancellation reason (optional):", "") ?? "";
    setBusy(true);
    try {
      const supabase = createAppSupabaseBrowserClient();
      const { error } = await supabase.rpc("cancel_booking", { booking_id: bookingId, reason: reason.trim() || null });
      if (error) {
        window.alert(userFacingDbError(error.message));
        return;
      }
      window.location.reload();
    } finally {
      setBusy(false);
    }
  }

  async function shareBooking() {
    const absoluteShareUrl =
      typeof window !== "undefined" && shareUrl.startsWith("/") ? `${window.location.origin}${shareUrl}` : shareUrl;
    const payload = {
      title: `HALLAQ booking ${bookingId}`,
      text: `Booking ${bookingId}`,
      url: absoluteShareUrl
    };
    if (navigator.share) {
      try {
        await navigator.share(payload);
        return;
      } catch {}
    }
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(absoluteShareUrl);
      window.alert("Booking link copied.");
      return;
    }
    window.prompt("Copy booking link:", absoluteShareUrl);
  }

  const telHref = shopPhone ? `tel:${encodeURIComponent(shopPhone)}` : null;
  const waHref = shopWhatsapp ? `https://wa.me/${encodeURIComponent(shopWhatsapp.replace(/[^\d]/g, ""))}` : null;
  const icsHref = `/api/calendar/booking.ics?bookingId=${encodeURIComponent(bookingId)}&startAt=${encodeURIComponent(startAt)}&endAt=${encodeURIComponent(endAt)}`;

  return (
    <div className="grid gap-3">
      <div className="grid grid-cols-2 gap-3">
        {canManage ? (
          <Link
            href={`/bookings/${encodeURIComponent(bookingId)}/reschedule`}
            className="inline-flex h-12 w-full items-center justify-center rounded-[16px] border border-[#2A2A2A] bg-[#111111] px-5 text-sm font-extrabold text-white"
          >
            Reschedule
          </Link>
        ) : (
          <div className="inline-flex h-12 w-full items-center justify-center rounded-[16px] border border-[#2A2A2A] bg-[#111111] px-5 text-sm font-extrabold text-[#6F6F6F]">
            Reschedule
          </div>
        )}
        <Button
          variant="destructive"
          className="h-12 w-full rounded-[16px]"
          disabled={busy || !canManage}
          onClick={() => void cancel()}
        >
          Cancel Booking
        </Button>
      </div>

      <div className="grid grid-cols-5 gap-3">
        <a
          href={telHref ?? "#"}
          aria-disabled={!telHref}
          className="inline-flex h-12 w-full items-center justify-center gap-2 rounded-[16px] border border-[#2A2A2A] bg-black/20 px-4 text-[12px] font-extrabold text-white disabled:opacity-50"
        >
          <Phone className="h-4 w-4 text-[hsl(var(--gold))]" />
          Call
        </a>
        <a
          href={waHref ?? "#"}
          aria-disabled={!waHref}
          className="inline-flex h-12 w-full items-center justify-center gap-2 rounded-[16px] border border-[#2A2A2A] bg-black/20 px-4 text-[12px] font-extrabold text-white disabled:opacity-50"
        >
          <MessageCircle className="h-4 w-4 text-[hsl(var(--gold))]" />
          WhatsApp
        </a>
        <a
          href={directionsHref ?? "#"}
          aria-disabled={!directionsHref}
          className="inline-flex h-12 w-full items-center justify-center gap-2 rounded-[16px] border border-[#2A2A2A] bg-black/20 px-4 text-[12px] font-extrabold text-white disabled:opacity-50"
        >
          <MapPin className="h-4 w-4 text-[hsl(var(--gold))]" />
          Directions
        </a>
        <a
          href={icsHref}
          className="inline-flex h-12 w-full items-center justify-center gap-2 rounded-[16px] border border-[#2A2A2A] bg-black/20 px-4 text-[12px] font-extrabold text-white"
        >
          <CalendarDays className="h-4 w-4 text-[hsl(var(--gold))]" />
          Calendar
        </a>
        <button
          type="button"
          onClick={() => void shareBooking()}
          className="inline-flex h-12 w-full items-center justify-center gap-2 rounded-[16px] border border-[#2A2A2A] bg-black/20 px-4 text-[12px] font-extrabold text-white"
        >
          <Share2 className="h-4 w-4 text-[hsl(var(--gold))]" />
          Share
        </button>
      </div>
    </div>
  );
}

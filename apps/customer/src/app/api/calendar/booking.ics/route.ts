import { NextRequest } from "next/server";

function escapeText(value: string) {
  return value.replace(/\\/g, "\\\\").replace(/\n/g, "\\n").replace(/,/g, "\\,").replace(/;/g, "\\;");
}

function toUtcStamp(value: string) {
  return new Date(value).toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
}

export async function GET(request: NextRequest) {
  const bookingId = request.nextUrl.searchParams.get("bookingId") ?? "booking";
  const startAt = request.nextUrl.searchParams.get("startAt");
  const endAt = request.nextUrl.searchParams.get("endAt");

  if (!startAt || !endAt) {
    return new Response("Missing start/end", { status: 400 });
  }

  const now = new Date().toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
  const ics = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//HALLAQ//Booking//EN",
    "BEGIN:VEVENT",
    `UID:${escapeText(bookingId)}@hallaq.com`,
    `DTSTAMP:${now}`,
    `DTSTART:${toUtcStamp(startAt)}`,
    `DTEND:${toUtcStamp(endAt)}`,
    "SUMMARY:HALLAQ Booking",
    "DESCRIPTION:Your HALLAQ appointment booking.",
    "END:VEVENT",
    "END:VCALENDAR"
  ].join("\r\n");

  return new Response(ics, {
    status: 200,
    headers: {
      "Content-Type": "text/calendar; charset=utf-8",
      "Content-Disposition": `attachment; filename="hallaq-booking-${bookingId}.ics"`
    }
  });
}

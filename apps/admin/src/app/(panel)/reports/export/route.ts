import { createSupabaseServerClient } from "@hallaq/supabase/server";

function toCsv(rows: Array<Record<string, unknown>>) {
  const headers = Array.from(
    rows.reduce((acc, r) => {
      Object.keys(r).forEach((k) => acc.add(k));
      return acc;
    }, new Set<string>())
  );

  const esc = (v: unknown) => {
    const s = String(v ?? "");
    return `"${s.replaceAll('"', '""')}"`;
  };

  return [headers.join(","), ...rows.map((r) => headers.map((h) => esc(r[h])).join(","))].join("\n");
}

export async function GET(request: Request) {
  const url = new URL(request.url);
  const type = url.searchParams.get("type") ?? "users";

  const supabase = await createSupabaseServerClient();

  let filename = `hallaq-${type}.csv`;
  let rows: Array<Record<string, unknown>> = [];

  if (type === "users") {
    const { data } = await supabase
      .from("profiles")
      .select("id, full_name, phone, role, area, created_at")
      .order("created_at", { ascending: false })
      .limit(10000);
    rows = data ?? [];
  } else if (type === "bookings") {
    const { data } = await supabase
      .from("bookings")
      .select("id, customer_profile_id, barber_id, shop_id, status, start_at, end_at, total_price, currency, created_at")
      .order("created_at", { ascending: false })
      .limit(10000);
    rows = data ?? [];
  } else if (type === "stores") {
    const { data } = await supabase
      .from("barbershops")
      .select("id, name, owner_profile_id, area, address, phone, whatsapp, instagram, is_verified, is_featured, created_at")
      .order("created_at", { ascending: false })
      .limit(10000);
    rows = data ?? [];
  } else if (type === "barbers") {
    const { data } = await supabase
      .from("barbers")
      .select(
        "id, profile_id, shop_id, display_name, area, is_independent, is_verified, is_hallaq_certified, badge_elite, badge_trending, created_at"
      )
      .order("created_at", { ascending: false })
      .limit(10000);
    rows = data ?? [];
  } else if (type === "revenue") {
    const { data } = await supabase
      .from("payments")
      .select("id, booking_id, payer_profile_id, payee_type, payee_id, amount, currency, status, captured_at, created_at")
      .order("created_at", { ascending: false })
      .limit(10000);
    rows = data ?? [];
  } else if (type === "reviews") {
    const { data } = await supabase
      .from("reviews")
      .select("id, customer_profile_id, target_type, target_id, rating, text, created_at")
      .order("created_at", { ascending: false })
      .limit(10000);
    rows = data ?? [];
  } else {
    filename = "hallaq-export.csv";
    rows = [];
  }

  const csv = toCsv(rows);

  return new Response(csv, {
    headers: {
      "content-type": "text/csv; charset=utf-8",
      "content-disposition": `attachment; filename="${filename}"`
    }
  });
}

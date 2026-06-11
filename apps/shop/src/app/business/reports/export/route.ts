import { PDFDocument, StandardFonts } from "pdf-lib";
import { NextResponse } from "next/server";
import * as XLSX from "xlsx";

import { getMyProfile } from "@hallaq/supabase/profile";

import { getMyShopContext } from "@/lib/my-shop-context";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type ExportDataset = {
  title: string;
  columns: string[];
  rows: string[][];
};

function csvEscape(v: unknown) {
  const s = String(v ?? "");
  if (s.includes('"') || s.includes(",") || s.includes("\n")) return `"${s.replaceAll('"', '""')}"`;
  return s;
}

function toCell(v: unknown) {
  if (v === null || v === undefined) return "";
  if (typeof v === "number") return Number.isFinite(v) ? String(v) : "";
  if (typeof v === "boolean") return v ? "true" : "false";
  return String(v);
}

function toMoney(v: unknown) {
  return Number(v ?? 0).toFixed(3);
}

function buildCsv(dataset: ExportDataset) {
  const lines = [dataset.columns.join(",")];
  for (const row of dataset.rows) {
    lines.push(row.map((value) => csvEscape(value)).join(","));
  }
  return `${lines.join("\n")}\n`;
}

function buildXlsx(dataset: ExportDataset) {
  const workbook = XLSX.utils.book_new();
  const sheet = XLSX.utils.aoa_to_sheet([dataset.columns, ...dataset.rows]);
  XLSX.utils.book_append_sheet(workbook, sheet, dataset.title.slice(0, 31));
  return XLSX.write(workbook, { type: "buffer", bookType: "xlsx" });
}

async function buildPdf(dataset: ExportDataset, subtitle: string) {
  const pdf = await PDFDocument.create();
  const font = await pdf.embedFont(StandardFonts.Helvetica);
  const bold = await pdf.embedFont(StandardFonts.HelveticaBold);

  const pageSize: [number, number] = [842, 595];
  const margin = 36;
  const fontSize = 9;
  const lineHeight = 14;
  const maxChars = 132;

  const lines = [
    dataset.title,
    subtitle,
    "",
    dataset.columns.join(" | "),
    ...dataset.rows.map((row) =>
      row
        .map((cell) => String(cell).replaceAll(/\s+/g, " ").trim())
        .join(" | ")
        .slice(0, maxChars)
    )
  ];

  let page = pdf.addPage(pageSize);
  let y = page.getHeight() - margin;
  let lineIndex = 0;

  while (lineIndex < lines.length) {
    if (y < margin + lineHeight) {
      page = pdf.addPage(pageSize);
      y = page.getHeight() - margin;
    }

    const line = lines[lineIndex] ?? "";
    page.drawText(line, {
      x: margin,
      y,
      size: lineIndex === 0 ? 14 : fontSize,
      font: lineIndex <= 1 ? bold : font
    });
    y -= lineIndex === 0 ? 20 : lineHeight;
    lineIndex += 1;
  }

  return await pdf.save();
}

async function getDataset({
  supabase,
  shopId,
  kind,
  from,
  to
}: {
  supabase: Awaited<ReturnType<typeof createAppSupabaseServerClient>>;
  shopId: string;
  kind: string;
  from: string;
  to: string;
}): Promise<ExportDataset> {
  if (kind === "bookings") {
    let q = supabase
      .from("bookings")
      .select("id, start_at, end_at, status, total_price, currency, created_at, customer_profile_id, barber_id, service_id")
      .eq("shop_id", shopId)
      .order("created_at", { ascending: false })
      .limit(5000);

    if (from) q = q.gte("start_at", from);
    if (to) q = q.lte("start_at", `${to}T23:59:59.999Z`);

    const { data } = await q;
    const rows = (data ?? []) as Array<{
      id: string;
      start_at: string | null;
      end_at: string | null;
      status: string | null;
      total_price: number | null;
      currency: string | null;
      created_at: string | null;
      customer_profile_id: string | null;
      barber_id: string | null;
      service_id: string | null;
    }>;

    return {
      title: "Bookings",
      columns: ["id", "start_at", "end_at", "status", "total_price", "currency", "created_at", "customer_profile_id", "barber_id", "service_id"],
      rows: rows.map((r) => [
        toCell(r.id),
        toCell(r.start_at),
        toCell(r.end_at),
        toCell(r.status),
        toMoney(r.total_price),
        toCell(r.currency ?? "BHD"),
        toCell(r.created_at),
        toCell(r.customer_profile_id),
        toCell(r.barber_id),
        toCell(r.service_id)
      ])
    };
  }

  if (kind === "orders") {
    let q = supabase
      .from("orders")
      .select("id, status, total_amount, currency, payment_method, payment_status, created_at, customer_profile_id")
      .eq("shop_id", shopId)
      .order("created_at", { ascending: false })
      .limit(5000);

    if (from) q = q.gte("created_at", from);
    if (to) q = q.lte("created_at", `${to}T23:59:59.999Z`);

    const { data } = await q;
    const rows = (data ?? []) as Array<{
      id: string;
      status: string | null;
      total_amount: number | null;
      currency: string | null;
      payment_method: string | null;
      payment_status: string | null;
      created_at: string | null;
      customer_profile_id: string | null;
    }>;

    return {
      title: "Orders",
      columns: ["id", "status", "total_amount", "currency", "payment_method", "payment_status", "created_at", "customer_profile_id"],
      rows: rows.map((r) => [
        toCell(r.id),
        toCell(r.status),
        toMoney(r.total_amount),
        toCell(r.currency ?? "BHD"),
        toCell(r.payment_method),
        toCell(r.payment_status),
        toCell(r.created_at),
        toCell(r.customer_profile_id)
      ])
    };
  }

  if (kind === "products") {
    let q = supabase
      .from("products")
      .select("id, name, description, price, currency, stock, active, created_at")
      .eq("shop_id", shopId)
      .order("created_at", { ascending: false })
      .limit(5000);

    if (from) q = q.gte("created_at", from);
    if (to) q = q.lte("created_at", `${to}T23:59:59.999Z`);

    const { data } = await q;
    const rows = (data ?? []) as Array<{
      id: string;
      name: string | null;
      description: string | null;
      price: number | null;
      currency: string | null;
      stock: number | null;
      active: boolean | null;
      created_at: string | null;
    }>;

    return {
      title: "Products",
      columns: ["id", "name", "description", "price", "currency", "stock", "active", "created_at"],
      rows: rows.map((r) => [
        toCell(r.id),
        toCell(r.name),
        toCell(r.description),
        toMoney(r.price),
        toCell(r.currency ?? "BHD"),
        toCell(r.stock),
        toCell(Boolean(r.active)),
        toCell(r.created_at)
      ])
    };
  }

  if (kind === "reviews") {
    let q = supabase
      .from("reviews")
      .select("id, barber_id, shop_id, rating, comment, text, reply_text, created_at")
      .eq("shop_id", shopId)
      .order("created_at", { ascending: false })
      .limit(5000);

    if (from) q = q.gte("created_at", from);
    if (to) q = q.lte("created_at", `${to}T23:59:59.999Z`);

    const { data } = await q;
    const rows = (data ?? []) as Array<{
      id: string;
      barber_id: string | null;
      shop_id: string | null;
      rating: number | null;
      comment: string | null;
      text: string | null;
      reply_text: string | null;
      created_at: string | null;
    }>;

    return {
      title: "Reviews",
      columns: ["id", "barber_id", "shop_id", "rating", "comment", "text", "reply_text", "created_at"],
      rows: rows.map((r) => [
        toCell(r.id),
        toCell(r.barber_id),
        toCell(r.shop_id),
        toCell(r.rating),
        toCell(r.comment),
        toCell(r.text),
        toCell(r.reply_text),
        toCell(r.created_at)
      ])
    };
  }

  let q = supabase
    .from("shop_revenue_daily")
    .select("day, gross_revenue, net_revenue, currency, bookings_count")
    .eq("shop_id", shopId)
    .order("day", { ascending: true })
    .limit(5000);

  if (from) q = q.gte("day", from);
  if (to) q = q.lte("day", to);

  const { data } = await q;
  const rows = (data ?? []) as Array<{ day: string; gross_revenue: number | null; net_revenue: number | null; currency: string | null; bookings_count: number | null }>;

  return {
    title: "Revenue",
    columns: ["day", "bookings_count", "gross_revenue", "net_revenue", "currency"],
    rows: rows.map((r) => [toCell(r.day), toCell(r.bookings_count ?? 0), toMoney(r.gross_revenue), toMoney(r.net_revenue), toCell(r.currency ?? "BHD")])
  };
}

export async function GET(req: Request) {
  const url = new URL(req.url);
  const from = (url.searchParams.get("from") ?? "").trim();
  const to = (url.searchParams.get("to") ?? "").trim();
  const requestedShopId = (url.searchParams.get("shopId") ?? "").trim();
  const kind = (url.searchParams.get("kind") ?? "").trim() || "revenue";
  const format = (url.searchParams.get("format") ?? "").trim() || "csv";

  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);
  const ctx = await getMyShopContext(supabase);
  const shopId = ctx.shop?.id ?? (profile?.role === "admin" ? requestedShopId || null : null);

  if (!shopId) {
    return NextResponse.json({ error: "No shop selected." }, { status: 400 });
  }

  const dataset = await getDataset({ supabase, shopId, kind, from, to });
  const baseFilename = `shop_${shopId}_${kind}_${from || "start"}_${to || "end"}`;

  if (format === "xlsx") {
    const body = buildXlsx(dataset);
    return new NextResponse(body, {
      status: 200,
      headers: {
        "content-type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "content-disposition": `attachment; filename="${baseFilename}.xlsx"`
      }
    });
  }

  if (format === "pdf") {
    const body = Buffer.from(await buildPdf(dataset, `Shop ${shopId} | ${from || "start"} -> ${to || "end"}`));
    return new NextResponse(body, {
      status: 200,
      headers: {
        "content-type": "application/pdf",
        "content-disposition": `attachment; filename="${baseFilename}.pdf"`
      }
    });
  }

  const csv = buildCsv(dataset);
  return new NextResponse(csv, {
    status: 200,
    headers: {
      "content-type": "text/csv; charset=utf-8",
      "content-disposition": `attachment; filename="${baseFilename}.csv"`
    }
  });
}

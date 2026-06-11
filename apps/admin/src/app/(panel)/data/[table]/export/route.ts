import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";

export const dynamic = "force-dynamic";

function safeInt(value: string | null, fallback: number) {
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? Math.min(Math.floor(n), 5000) : fallback;
}

function csvEscape(value: unknown) {
  if (value == null) return "";
  const s = typeof value === "string" ? value : JSON.stringify(value);
  if (/[",\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

const searchColumns: Record<string, string[]> = {
  profiles: ["full_name", "email", "phone", "role"],
  barbershops: ["name", "area", "address", "status"],
  barbers: ["display_name", "area", "specialty"],
  services: ["name_en", "name_ar", "name", "category"],
  products: ["name", "description"],
  reels: ["caption", "status", "location"],
  reviews: ["comment", "status"],
  notifications: ["title", "body", "type"],
  offers: ["title", "status"],
  awards: ["title", "status"],
  system_logs: ["page", "action", "severity", "error_message"],
  admin_audit_logs: ["action", "target_type"]
};

async function getClient() {
  try {
    return await createSupabaseAdminClient();
  } catch {
    return await createSupabaseServerClient();
  }
}

export async function GET(request: Request, ctx: { params: Promise<{ table: string }> }) {
  const { table } = await ctx.params;
  const url = new URL(request.url);
  const q = (url.searchParams.get("q") ?? "").trim();
  const sort = (url.searchParams.get("sort") ?? "").trim();
  const dir = (url.searchParams.get("dir") ?? "").trim().toLowerCase();
  const limit = safeInt(url.searchParams.get("limit"), 2000);

  try {
    const server = await createSupabaseServerClient();
    const { data: authData } = await server.auth.getUser();
    const actorId = authData.user?.id ?? null;
    await Promise.allSettled([
      server.from("admin_audit_logs").insert({
        admin_profile_id: actorId,
        action: "data_export_csv",
        target_type: table,
        target_id: null,
        meta: { q, sort, dir, limit }
      }),
      server.from("admin_activity_logs").insert({
        actor_profile_id: actorId,
        action: "data_export_csv",
        entity_type: table,
        entity_id: null,
        meta: { q, sort, dir, limit }
      })
    ]);
  } catch {}

  const supabase = await getClient();
  let query = supabase.from(table).select("*").limit(limit);

  if (sort) query = query.order(sort, { ascending: dir !== "desc" });
  else query = query.order("created_at", { ascending: false });

  if (q) {
    const cols = searchColumns[table] ?? [];
    if (cols.length) {
      const or = cols.map((c) => `${c}.ilike.%${q.replaceAll("%", "")}%`).join(",");
      query = query.or(or);
    } else {
      query = query.eq("id", q);
    }
  }

  const { data: rows, error } = await query;
  if (error) return new Response(error.message, { status: 400 });

  const list = (rows ?? []) as Array<Record<string, unknown>>;
  const keys = Array.from(new Set(list.flatMap((r) => Object.keys(r))));
  const header = keys.join(",");
  const body = list
    .map((r) => keys.map((k) => csvEscape((r as Record<string, unknown>)[k])).join(","))
    .join("\n");

  return new Response(`${header}\n${body}\n`, {
    headers: {
      "content-type": "text/csv; charset=utf-8",
      "content-disposition": `attachment; filename="${table}.csv"`
    }
  });
}

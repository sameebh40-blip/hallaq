import { createSupabaseServerClient } from "@hallaq/supabase/server";

export const dynamic = "force-dynamic";

function toText(value: unknown, max = 8000) {
  const s = typeof value === "string" ? value : value == null ? "" : String(value);
  return s.length > max ? s.slice(0, max) : s;
}

export async function POST(request: Request) {
  try {
    const payload = (await request.json().catch(() => ({}))) as Record<string, unknown>;
    const supabase = await createSupabaseServerClient();
    const ua = request.headers.get("user-agent") ?? "";

    const { data: auth } = await supabase.auth.getUser();
    const userId = auth.user?.id ?? null;

    const { data: profile } = userId
      ? await supabase.from("profiles").select("role").eq("id", userId).maybeSingle()
      : { data: null };

    const role = toText(payload.role ?? profile?.role ?? null, 64) || null;
    const page = toText(payload.page ?? null, 512) || null;
    const action = toText(payload.action ?? null, 128) || null;
    const errorMessage = toText(payload.error_message ?? payload.message ?? null, 8000) || null;
    const stackTrace = toText(payload.stack_trace ?? payload.stack ?? null, 16000) || null;
    const severityRaw = toText(payload.severity ?? "error", 16).toLowerCase();
    const severity =
      severityRaw === "info" || severityRaw === "warning" || severityRaw === "critical" || severityRaw === "error"
        ? severityRaw
        : "error";

    const meta = typeof payload.meta === "object" && payload.meta && !Array.isArray(payload.meta) ? payload.meta : {};
    const platform = toText(payload.platform ?? "web", 32) || "web";
    const device = toText(payload.device ?? ua ?? null, 512) || null;

    const { error } = await supabase.from("system_logs").insert({
      user_id: userId,
      role,
      page,
      action,
      platform,
      device,
      error_message: errorMessage,
      stack_trace: stackTrace,
      severity,
      meta
    });

    if (error) return Response.json({ ok: false, error: error.message }, { status: 500 });
    return Response.json({ ok: true });
  } catch {
    return Response.json({ ok: false }, { status: 500 });
  }
}


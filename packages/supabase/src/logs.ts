import { tryCreateSupabaseBrowserClient } from "./browser";

type Severity = "info" | "warning" | "error" | "critical";

function safeString(v: unknown) {
  return typeof v === "string" ? v : v == null ? "" : String(v);
}

function safeError(e: unknown) {
  if (e instanceof Error) return e;
  const msg = safeString(e).trim() || "Unknown error";
  return new Error(msg);
}

export async function logClientError(params: {
  page: string;
  error: unknown;
  action?: string | null;
  role?: string | null;
  severity?: Severity;
  platform?: string | null;
  device?: string | null;
  meta?: Record<string, unknown> | null;
}) {
  const supabase = tryCreateSupabaseBrowserClient();
  if (!supabase) return;

  const err = safeError(params.error);
  const page = safeString(params.page).trim() || null;
  const action = safeString(params.action).trim() || "client_error";

  let userId: string | null = null;
  try {
    const { data } = await supabase.auth.getUser();
    userId = data.user?.id ?? null;
  } catch {}

  let device = safeString(params.device).trim();
  if (!device && typeof navigator !== "undefined") device = navigator.userAgent || "";

  const platform = safeString(params.platform).trim() || (typeof window !== "undefined" ? "web" : "unknown");

  try {
    await supabase.from("system_logs").insert({
      user_id: userId,
      role: safeString(params.role).trim() || null,
      page,
      action,
      platform,
      device: device || null,
      error_message: err.message || "Unknown error",
      stack_trace: err.stack ?? null,
      severity: (params.severity ?? "error") as Severity,
      meta: params.meta ?? {}
    });
  } catch {}
}


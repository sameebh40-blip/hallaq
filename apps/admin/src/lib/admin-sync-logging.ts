import type { SupabaseClient } from "@supabase/supabase-js";

type Severity = "info" | "warning" | "error" | "critical";

export async function logAdminSyncError(
  admin: SupabaseClient,
  params: {
    actorId?: string | null;
    page: string;
    action: string;
    error: unknown;
    meta?: Record<string, unknown>;
    severity?: Severity;
  }
) {
  const message = params.error instanceof Error ? params.error.message : String(params.error ?? "unknown_error");
  await Promise.allSettled([
    admin.from("system_logs").insert({
      user_id: params.actorId ?? null,
      role: "admin",
      page: params.page,
      action: params.action,
      error_message: message,
      severity: params.severity ?? "error",
      meta: params.meta ?? {}
    }),
    admin.from("admin_activity_logs").insert({
      actor_profile_id: params.actorId ?? null,
      action: `${params.action}_failed`,
      entity_type: "system",
      entity_id: null,
      meta: { error: message, ...(params.meta ?? {}) }
    })
  ]);
}

import { createClient } from "@supabase/supabase-js";

import { getSupabaseEnv } from "./env";

export type SupabaseConnectionStatus =
  | { ok: true }
  | { ok: false; reason: "not_configured" | "unreachable" };

export async function checkSupabaseConnection(): Promise<SupabaseConnectionStatus> {
  const env = getSupabaseEnv();
  if (!env.isConfigured) return { ok: false, reason: "not_configured" };

  try {
    const supabase = createClient(env.url, env.anonKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUrl: false
      }
    });
    const { error } = await supabase.auth.getSession();
    if (error) return { ok: false, reason: "unreachable" };
    return { ok: true };
  } catch {
    return { ok: false, reason: "unreachable" };
  }
}


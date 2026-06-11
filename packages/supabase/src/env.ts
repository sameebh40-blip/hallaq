export class SupabaseNotConfiguredError extends Error {
  name = "SupabaseNotConfiguredError";

  constructor() {
    super("Supabase is not configured.");
  }
}

export function getSupabaseEnv() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "";
  const isConfigured = url.length > 0 && anonKey.length > 0;

  return { url, anonKey, isConfigured };
}

export function requireSupabaseEnv() {
  const env = getSupabaseEnv();
  if (!env.isConfigured) throw new SupabaseNotConfiguredError();
  return env;
}

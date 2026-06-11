import { createBrowserClient } from "@supabase/ssr";

import { requireSupabaseEnv } from "./env";

export function createSupabaseBrowserClient(options?: { cookieName?: string }) {
  const { url, anonKey } = requireSupabaseEnv();
  return createBrowserClient(url, anonKey, options?.cookieName ? { cookieOptions: { name: options.cookieName } } : undefined);
}

export function tryCreateSupabaseBrowserClient(options?: { cookieName?: string }) {
  try {
    return createSupabaseBrowserClient(options);
  } catch {
    return null;
  }
}

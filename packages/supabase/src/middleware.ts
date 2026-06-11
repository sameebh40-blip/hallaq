import { createServerClient } from "@supabase/ssr";
import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

import { requireSupabaseEnv } from "./env";

type CookieOptions = {
  domain?: string;
  path?: string;
  expires?: Date;
  maxAge?: number;
  httpOnly?: boolean;
  secure?: boolean;
  sameSite?: "lax" | "strict" | "none";
};

export function createSupabaseMiddlewareClient(
  request: NextRequest,
  options?: { cookieName?: string; response?: NextResponse }
) {
  const { url, anonKey } = requireSupabaseEnv();

  const response =
    options?.response ??
    NextResponse.next({
      request: {
        headers: request.headers
      }
    });

  const supabase = createServerClient(url, anonKey, {
    ...(options?.cookieName ? { cookieOptions: { name: options.cookieName } } : null),
    cookies: {
      get(name: string) {
        return request.cookies.get(name)?.value;
      },
      set(name: string, value: string, options: CookieOptions) {
        response.cookies.set({ name, value, ...options });
      },
      remove(name: string, options: CookieOptions) {
        response.cookies.set({ name, value: "", ...options, maxAge: 0 });
      }
    }
  });

  return { supabase, response };
}

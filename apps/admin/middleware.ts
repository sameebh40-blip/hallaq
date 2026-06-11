import { NextResponse, type NextRequest } from "next/server";

import { createSupabaseMiddlewareClient } from "@hallaq/supabase/middleware";
import { getRoleHomeUrl } from "@hallaq/supabase/routing";

function withNext(url: URL, next: string) {
  const result = new URL(url);
  result.searchParams.set("next", next);
  return result;
}

function serviceUnavailable() {
  return new NextResponse(
    `<!doctype html><html><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/><title>HALLAQ</title></head><body style="font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif;background:#0b0b0f;color:#e8e8ee;margin:0;display:grid;place-items:center;min-height:100vh;padding:24px;"><div style="max-width:520px;width:100%;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.12);border-radius:16px;padding:20px;"><h1 style="margin:0 0 8px;font-size:18px;">Something went wrong</h1><p style="margin:0;color:rgba(232,232,238,0.75);line-height:1.5;">Please refresh the page. If the issue persists, try again shortly.</p></div></body></html>`,
    { status: 503, headers: { "content-type": "text/html; charset=utf-8" } }
  );
}

const publicPaths = [
  "/auth",
  "/locale",
  "/health",
  "/bootstrap-admin",
  "/_next",
  "/favicon.ico",
  "/admin/auth",
  "/admin/locale",
  "/admin/health",
  "/admin/bootstrap-admin",
  "/admin/_next",
  "/admin/favicon.ico"
];

export async function middleware(request: NextRequest) {
  if (publicPaths.some((p) => request.nextUrl.pathname.startsWith(p))) {
    return NextResponse.next();
  }

  let supabase: ReturnType<typeof createSupabaseMiddlewareClient>["supabase"];
  let response: ReturnType<typeof createSupabaseMiddlewareClient>["response"];
  try {
    ({ supabase, response } = createSupabaseMiddlewareClient(request));
  } catch {
    return serviceUnavailable();
  }

  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    const next = `${request.nextUrl.pathname}${request.nextUrl.search}`;
    return NextResponse.redirect(withNext(new URL("/auth/sign-in", request.url), next));
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("role, must_change_password")
    .eq("id", user.id)
    .maybeSingle();

  const role = profile?.role;
  const mustChangePassword = Boolean(profile?.must_change_password);

  if (mustChangePassword && !request.nextUrl.pathname.startsWith("/auth/reset-password")) {
    const next = `${request.nextUrl.pathname}${request.nextUrl.search}`;
    return NextResponse.redirect(withNext(new URL("/auth/reset-password", request.url), next));
  }

  if (role !== "admin") {
    return NextResponse.redirect(getRoleHomeUrl(role, request.url));
  }

  return response;
}

export const config = {
  matcher: [
    "/((?!_next|favicon.ico|auth|locale|health|bootstrap-admin).*)",
    "/admin/((?!_next|favicon.ico|auth|locale|health|bootstrap-admin).*)"
  ]
};

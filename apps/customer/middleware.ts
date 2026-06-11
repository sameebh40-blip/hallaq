import { NextResponse, type NextRequest } from "next/server";

import { createSupabaseMiddlewareClient } from "@hallaq/supabase/middleware";
import { getHallaqAppOrigins, getRoleHomeUrl } from "@hallaq/supabase/routing";

const qaCookieName = "hallaq-qa-auth";
const qaActiveCookieName = "hallaq_qa_active";

function getSafeNextTarget(raw: string | null, requestUrl: URL) {
  if (!raw) return null;
  const trimmed = raw.trim();
  if (trimmed.startsWith("/") && !trimmed.startsWith("//")) return trimmed;

  try {
    const url = new URL(trimmed);
    const allowed = new Set(
      [
        requestUrl.origin,
        getHallaqAppOrigins().landing,
        getHallaqAppOrigins().app,
        getHallaqAppOrigins().business,
        getHallaqAppOrigins().admin
      ].filter((v): v is string => Boolean(v))
    );
    if (!allowed.has(url.origin)) return null;
    return url.toString();
  } catch {
    return null;
  }
}

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

const publicPaths = ["/_next", "/favicon.ico", "/maintenance", "/health", "/locale"];
const authRequiredPaths = [
  "/home",
  "/discover",
  "/hallaq-city",
  "/city",
  "/bookings",
  "/profile",
  "/barber-dashboard",
  "/booking",
  "/complete-profile",
  "/pending-role"
];

export async function middleware(request: NextRequest) {
  if (publicPaths.some((p) => request.nextUrl.pathname.startsWith(p))) {
    return NextResponse.next();
  }

  let supabase: ReturnType<typeof createSupabaseMiddlewareClient>["supabase"];
  let qaSupabase: ReturnType<typeof createSupabaseMiddlewareClient>["supabase"];
  let response: ReturnType<typeof createSupabaseMiddlewareClient>["response"];
  try {
    ({ supabase: qaSupabase, response } = createSupabaseMiddlewareClient(request, { cookieName: qaCookieName }));
    ({ supabase } = createSupabaseMiddlewareClient(request, { response }));
  } catch {
    return serviceUnavailable();
  }

  const qaActive = request.cookies.get(qaActiveCookieName)?.value === "1";
  const activeSupabase = qaActive ? qaSupabase : supabase;

  if (request.nextUrl.pathname !== "/maintenance") {
    try {
      const { data: maintenance } = await activeSupabase.rpc("get_setting_bool", {
        p_key: "maintenance_mode",
        p_default: false
      });
      if (maintenance) {
        return NextResponse.redirect(new URL("/maintenance", request.url));
      }
    } catch {}
  }

  const qaResult = qaActive ? await qaSupabase.auth.getUser() : null;
  const fallbackResult = qaActive ? null : await supabase.auth.getUser();
  const user = qaActive ? qaResult?.data.user ?? null : fallbackResult?.data.user ?? null;

  if (qaActive && !user) {
    response.cookies.set({ name: qaActiveCookieName, value: "", maxAge: 0, path: "/" });
  }

  const pathname = request.nextUrl.pathname;
  const isAuthRequired = authRequiredPaths.some((p) => pathname.startsWith(p));
  if (!user) {
    if (isAuthRequired) {
      const next = `${request.nextUrl.pathname}${request.nextUrl.search}`;
      return NextResponse.redirect(withNext(new URL("/auth/sign-in", request.url), next));
    }
    return response;
  }

  const { data: profile } = await activeSupabase
    .from("profiles")
    .select("role, must_change_password")
    .eq("id", user.id)
    .maybeSingle();

  const role = profile?.role ?? null;
  const roleHomeUrl = getRoleHomeUrl(role, request.url);
  const mustChangePassword = Boolean(profile?.must_change_password);

  if (!role) {
    const { data: pending } = await activeSupabase
      .from("role_requests")
      .select("id")
      .eq("profile_id", user.id)
      .eq("status", "pending")
      .limit(1);

    const target = (pending?.length ?? 0) > 0 ? "/pending-role" : "/complete-profile";
    if (pathname !== target) return NextResponse.redirect(new URL(target, request.url));
    return response;
  }

  const requestedNext = getSafeNextTarget(request.nextUrl.searchParams.get("next"), request.nextUrl);
  if (mustChangePassword) {
    if (!pathname.startsWith("/auth/reset-password")) {
      return NextResponse.redirect(withNext(new URL("/auth/reset-password", request.url), roleHomeUrl.toString()));
    }
    return response;
  }

  if (pathname.startsWith("/auth")) {
    return NextResponse.redirect(new URL(requestedNext ?? roleHomeUrl.toString(), request.url));
  }

  if (role !== "customer") {
    if (request.nextUrl.origin !== roleHomeUrl.origin || request.nextUrl.pathname !== roleHomeUrl.pathname) {
      return NextResponse.redirect(roleHomeUrl);
    }
    return response;
  }

  if (pathname.startsWith("/barber-dashboard")) {
    return NextResponse.redirect(new URL("/home", request.url));
  }

  if (pathname === "/") {
    return NextResponse.redirect(new URL("/home", request.url));
  }
  if (pathname === "/explore") {
    return NextResponse.redirect(new URL("/discover", request.url));
  }
  if (pathname === "/city") {
    return NextResponse.redirect(new URL("/hallaq-city", request.url));
  }

  return response;
}

export const config = {
  matcher: ["/((?!_next|favicon.ico|maintenance|health).*)"]
};

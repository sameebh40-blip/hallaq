import { NextResponse, type NextRequest } from "next/server";

import { createSupabaseMiddlewareClient } from "@hallaq/supabase/middleware";
import { getHallaqBasePaths, getHallaqRoutingMode, getRoleHomeUrl } from "@hallaq/supabase/routing";

const qaCookieName = "hallaq-qa-auth";
const qaActiveCookieName = "hallaq_qa_active";

const mode = getHallaqRoutingMode();
const { shopBasePath } = getHallaqBasePaths();
const basePath = mode === "path" ? shopBasePath : "";

function withBasePath(pathname: string) {
  const p = pathname.startsWith("/") ? pathname : `/${pathname}`;
  return `${basePath}${p}`;
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

const publicPaths = [
  withBasePath("/auth"),
  withBasePath("/locale"),
  withBasePath("/_next"),
  withBasePath("/favicon.ico"),
  withBasePath("/maintenance"),
  withBasePath("/health")
];

export async function middleware(request: NextRequest) {
  if (basePath && !request.nextUrl.pathname.startsWith(basePath)) {
    return NextResponse.next();
  }

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

  const qaResult = qaActive ? await qaSupabase.auth.getUser() : null;
  const fallbackResult = qaActive ? null : await supabase.auth.getUser();
  const user = qaActive ? qaResult?.data.user ?? null : fallbackResult?.data.user ?? null;

  if (qaActive && !user) {
    response.cookies.set({ name: qaActiveCookieName, value: "", maxAge: 0, path: "/" });
  }

  if (!user) {
    const next = `${request.nextUrl.pathname}${request.nextUrl.search}`;
    return NextResponse.redirect(withNext(new URL(withBasePath("/auth/sign-in"), request.url), next));
  }

  const { data: profile } = await activeSupabase
    .from("profiles")
    .select("role, must_change_password")
    .eq("id", user.id)
    .maybeSingle();

  const role = profile?.role;
  const mustChangePassword = Boolean(profile?.must_change_password);
  if (mustChangePassword && !request.nextUrl.pathname.startsWith(withBasePath("/auth/reset-password"))) {
    const next = `${request.nextUrl.pathname}${request.nextUrl.search}`;
    return NextResponse.redirect(withNext(new URL(withBasePath("/auth/reset-password"), request.url), next));
  }

  if (role !== "shop_owner" && role !== "admin" && role !== "receptionist") {
    return NextResponse.redirect(getRoleHomeUrl(role, request.url));
  }

  if (role === "shop_owner" || role === "receptionist") {
    let hasMembership = false;

    try {
      const membershipRole = role === "shop_owner" ? "owner" : "receptionist";
      const { data: memberships, error: membershipsError } = await activeSupabase
        .from("shop_memberships")
        .select("id")
        .eq("profile_id", user.id)
        .eq("membership_role", membershipRole)
        .limit(1);

      if (!membershipsError) {
        hasMembership = (memberships?.length ?? 0) > 0;
      }
    } catch {}

    if (!hasMembership) {
      const fallbackQuery =
        role === "shop_owner"
          ? activeSupabase.from("barbershops").select("id").eq("owner_profile_id", user.id).limit(1)
          : activeSupabase.from("shop_staff").select("id").eq("profile_id", user.id).eq("staff_role", "receptionist").limit(1);
      const { data: fallbackRows } = await fallbackQuery;
      hasMembership = (fallbackRows?.length ?? 0) > 0;
    }

    if (!hasMembership) {
      return NextResponse.redirect(getRoleHomeUrl("customer", request.url));
    }
  }

  if (role !== "admin" && request.nextUrl.pathname !== withBasePath("/maintenance")) {
    try {
      const { data: maintenance } = await activeSupabase.rpc("get_setting_bool", {
        p_key: "maintenance_mode",
        p_default: false
      });
      if (maintenance) {
        return NextResponse.redirect(new URL(withBasePath("/maintenance"), request.url));
      }
    } catch {}
  }

  return response;
}

export const config = {
  matcher: ["/:path*"]
};

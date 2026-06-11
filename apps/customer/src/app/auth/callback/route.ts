import { NextResponse } from "next/server";

import { createAppSupabaseServerClient } from "@/lib/supabase";

function getSafeNextPath(url: URL) {
  const raw = url.searchParams.get("next");
  if (!raw) return "/";
  if (!raw.startsWith("/")) return "/";
  if (raw.startsWith("//")) return "/";
  return raw;
}

export async function GET(request: Request) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const next = getSafeNextPath(url);

  if (code) {
    const supabase = await createAppSupabaseServerClient();
    await supabase.auth.exchangeCodeForSession(code);
  }

  return NextResponse.redirect(new URL(next, url));
}

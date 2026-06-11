import { NextResponse } from "next/server";

import { createAppSupabaseServerClient } from "@/lib/supabase";

export async function POST(request: Request) {
  const url = new URL(request.url);
  const supabase = await createAppSupabaseServerClient();
  await supabase.auth.signOut();
  return NextResponse.redirect(new URL("/", url));
}

import { NextResponse } from "next/server";
import { cookies } from "next/headers";

import { createSupabaseServerClient } from "@hallaq/supabase/server";

const qaCookieName = "hallaq-qa-auth";

export async function POST() {
  const supabase = await createSupabaseServerClient({ cookieName: qaCookieName });
  await supabase.auth.signOut();

  const cookieStore = await cookies();
  cookieStore.set({ name: "hallaq_qa_active", value: "", maxAge: 0, path: "/" });
  cookieStore.set({ name: "hallaq_qa_role", value: "", maxAge: 0, path: "/" });
  cookieStore.set({ name: "hallaq_qa_profile_id", value: "", maxAge: 0, path: "/" });

  return NextResponse.json({ ok: true });
}


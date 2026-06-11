import { cookies } from "next/headers";

import { createSupabaseServerClient } from "@hallaq/supabase/server";

const qaCookieName = "hallaq-qa-auth";
const qaActiveCookieName = "hallaq_qa_active";

export async function createAppSupabaseServerClient() {
  const cookieStore = await cookies();
  const qaActive = cookieStore.get(qaActiveCookieName)?.value === "1";
  return createSupabaseServerClient(qaActive ? { cookieName: qaCookieName } : undefined);
}


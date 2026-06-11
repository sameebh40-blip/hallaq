import { NextResponse } from "next/server";

import { createSupabaseServerClient } from "@hallaq/supabase/server";

export async function POST(request: Request) {
  const url = new URL(request.url);
  const supabase = await createSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (user) {
    await Promise.allSettled([
      supabase.from("admin_activity_logs").insert({
        actor_profile_id: user.id,
        action: "admin_logout",
        entity_type: "auth",
        entity_id: user.id,
        meta: {}
      }),
      supabase.from("admin_audit_logs").insert({
        admin_profile_id: user.id,
        action: "admin_logout",
        target_type: "auth",
        target_id: user.id,
        meta: {}
      })
    ]);
  }

  await supabase.auth.signOut();
  return NextResponse.redirect(new URL("./sign-in", url));
}

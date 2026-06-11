import { NextResponse } from "next/server";

import { createSupabaseServerClient } from "@hallaq/supabase/server";

export const dynamic = "force-dynamic";

export async function GET() {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("admin_data_integrity_scan", { p_limit: 500 });
  if (error) return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json(data ?? {});
}


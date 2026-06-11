import { NextResponse } from "next/server";

import { createSupabaseServerClient } from "@hallaq/supabase/server";

export const dynamic = "force-dynamic";

export async function GET() {
  const supabase = await createSupabaseServerClient();

  const [{ data: backups }, { count: profiles }, { count: shops }, { count: barbers }, { count: bookings }, { count: reels }] =
    await Promise.all([
      supabase.from("backup_logs").select("*").order("created_at", { ascending: false }).limit(50),
      supabase.from("profiles").select("id", { count: "exact", head: true }),
      supabase.from("barbershops").select("id", { count: "exact", head: true }),
      supabase.from("barbers").select("id", { count: "exact", head: true }),
      supabase.from("bookings").select("id", { count: "exact", head: true }),
      supabase.from("reels").select("id", { count: "exact", head: true })
    ]);

  return NextResponse.json(
    {
      generated_at: new Date().toISOString(),
      entities: {
        profiles: profiles ?? 0,
        shops: shops ?? 0,
        barbers: barbers ?? 0,
        bookings: bookings ?? 0,
        reels: reels ?? 0
      },
      backups: backups ?? []
    },
    {
      headers: {
        "content-type": "application/json; charset=utf-8"
      }
    }
  );
}


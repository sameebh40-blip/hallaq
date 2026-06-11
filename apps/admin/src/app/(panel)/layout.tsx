import type { ReactNode } from "react";
import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";

import { AdminShell } from "@/components/admin-shell";
import { RealtimeRefresh } from "@/components/realtime-refresh";

export default async function PanelLayout({ children }: { children: ReactNode }) {
  const supabase = await createSupabaseServerClient();
  const { data: auth } = await supabase.auth.getUser();
  const user = auth.user;

  if (!user) redirect("/auth/sign-in");

  const { data: profile, error } = await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle();

  if (error) redirect(`/auth/sign-in?error=${encodeURIComponent(error.message)}`);
  const isAdmin = profile?.role === "admin";

  if (!isAdmin) redirect("/not-authorized");

  return (
    <AdminShell>
      <RealtimeRefresh tables={["bookings", "notifications", "payments"]} />
      {children}
    </AdminShell>
  );
}

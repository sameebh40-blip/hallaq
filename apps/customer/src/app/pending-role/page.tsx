import { redirect } from "next/navigation";

import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

function label(role: string) {
  if (role === "shop_owner") return "Shop owner";
  if (role === "barber") return "Barber";
  return role;
}

export default async function PendingRolePage() {
  const supabase = await createAppSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) redirect("/auth/sign-in?next=/pending-role");

  const [{ data: profile }, { data: pending }] = await Promise.all([
    supabase.from("profiles").select("role").eq("id", user.id).maybeSingle(),
    supabase
      .from("role_requests")
      .select("id, requested_role, status, created_at")
      .eq("profile_id", user.id)
      .eq("status", "pending")
      .order("created_at", { ascending: false })
      .limit(5)
  ]);

  if (profile?.role) redirect("/home");
  if (!pending?.length) redirect("/complete-profile");

  async function continueAsCustomer() {
    "use server";
    redirect("/home");
  }

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 px-4 py-10">
      <div className="text-lg font-semibold text-[#111111]">Role request pending</div>
      <div className="text-sm text-muted-foreground">An admin must approve your access before dashboards unlock.</div>

      <LuxuryCard className="bg-white p-5">
        <div className="text-sm font-semibold text-[#111111]">Your requests</div>
        <div className="pt-3 flex flex-col gap-2">
          {pending.map((r) => (
            <div key={r.id} className="rounded-xl border bg-white p-3 text-sm">
              <div className="font-semibold text-[#111111]">{label(String(r.requested_role))}</div>
              <div className="text-xs text-muted-foreground">Status: {String(r.status)}</div>
            </div>
          ))}
        </div>
      </LuxuryCard>

      <LuxuryCard className="bg-white p-5">
        <div className="text-sm font-semibold text-[#111111]">Need to continue now?</div>
        <div className="pt-1 text-sm text-muted-foreground">You can continue as a customer while you wait.</div>
        <div className="pt-4 flex flex-col gap-2">
          <form action={continueAsCustomer}>
            <Button type="submit" className="w-full rounded-2xl">
              Continue as customer
            </Button>
          </form>
          <form action="/auth/sign-out" method="post">
            <Button type="submit" variant="ghost" className="w-full rounded-2xl">
              Logout
            </Button>
          </form>
        </div>
      </LuxuryCard>
    </main>
  );
}

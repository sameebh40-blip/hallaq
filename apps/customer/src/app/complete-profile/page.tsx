import { redirect } from "next/navigation";

import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

function safeNext(raw: string | null) {
  const v = (raw ?? "").trim();
  if (!v) return null;
  if (!v.startsWith("/")) return null;
  if (v.startsWith("//")) return null;
  return v;
}

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong.";
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Please sign in again.";
  }
  if (m.toLowerCase().includes("duplicate key") || m.toLowerCase().includes("unique")) {
    return "You already submitted this request.";
  }
  return m;
}

export default async function CompleteProfilePage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string; next?: string }>;
}) {
  const supabase = await createAppSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) redirect("/auth/sign-in?next=/complete-profile");

  const params = searchParams ? await searchParams : undefined;
  const error = params?.error ? userFacingDbError(params.error) : null;
  const next = safeNext(params?.next ?? null);

  const [{ data: profile }, { data: pending }] = await Promise.all([
    supabase.from("profiles").select("role, full_name").eq("id", user.id).maybeSingle(),
    supabase.from("role_requests").select("id, requested_role, status").eq("profile_id", user.id).eq("status", "pending").limit(1)
  ]);

  if (profile?.role) redirect(next ?? "/home");
  if ((pending?.length ?? 0) > 0) redirect("/pending-role");

  async function setCustomerRole() {
    "use server";
    redirect(next ?? "/home");
  }

  async function requestRole(formData: FormData) {
    "use server";
    const supabase = await createAppSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    if (!user) redirect("/auth/sign-in?next=/complete-profile");

    const requestedRole = String(formData.get("requested_role") ?? "");
    if (requestedRole !== "barber" && requestedRole !== "shop_owner") redirect("/complete-profile");

    const shopName = String(formData.get("shop_name") ?? "").trim() || null;
    const phone = String(formData.get("phone") ?? "").trim() || null;
    const notes = String(formData.get("notes") ?? "").trim() || null;

    const { error } = await supabase.from("role_requests").insert({
      profile_id: user.id,
      requested_role: requestedRole,
      shop_name: shopName,
      phone,
      notes
    });

    if (error) redirect(`/complete-profile?error=${encodeURIComponent(error.message)}`);
    redirect("/pending-role");
  }

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 py-10 text-white">
      <div className="text-lg font-extrabold">Complete your profile</div>
      <div className="text-sm font-semibold text-[#9E9E9E]">Select your role to continue.</div>

      {error ? (
        <div className="rounded-xl border border-rose-500/25 bg-rose-500/10 px-4 py-3 text-sm text-rose-300">{error}</div>
      ) : null}

      <LuxuryCard className="bg-[#111111] p-5 text-white">
        <div className="text-sm font-extrabold">Customer</div>
        <div className="pt-1 text-sm font-semibold text-[#9E9E9E]">Browse shops, discover reels, and book appointments.</div>
        <div className="pt-4">
          <form action={setCustomerRole}>
            <Button type="submit" className="w-full rounded-2xl">
              Continue as customer
            </Button>
          </form>
        </div>
      </LuxuryCard>

      <LuxuryCard className="bg-[#111111] p-5 text-white">
        <div className="text-sm font-extrabold">Barber / Shop owner</div>
        <div className="pt-1 text-sm font-semibold text-[#9E9E9E]">Request access and an admin will approve your role.</div>

        <form action={requestRole} className="grid gap-3 pt-4">
          <div className="grid gap-2">
            <Label htmlFor="requested_role">Requested role</Label>
            <select
              id="requested_role"
              name="requested_role"
              className="h-11 rounded-2xl border border-[#2A2A2A] bg-black/30 px-4 text-sm text-white outline-none"
              defaultValue="barber"
            >
              <option value="barber">Barber</option>
              <option value="shop_owner">Shop owner</option>
            </select>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="shop_name">Shop name (optional)</Label>
            <Input id="shop_name" name="shop_name" placeholder="Example: Hallaq Salon" />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="phone">Phone (optional)</Label>
            <Input id="phone" name="phone" placeholder="+973 ..." />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="notes">Notes (optional)</Label>
            <Input id="notes" name="notes" placeholder="Anything the admin should know…" />
          </div>
          <Button type="submit" variant="secondary" className="w-full rounded-2xl">
            Submit request
          </Button>
        </form>
      </LuxuryCard>
    </main>
  );
}

import Link from "next/link";
import { redirect } from "next/navigation";

import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";
import { getMyShopContext } from "@/lib/my-shop-context";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong.";
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as a shop owner.";
  }
  return m;
}

export default async function BarberRequestsPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((params?.error ?? "").trim());

  const supabase = await createAppSupabaseServerClient();
  const ctx = await getMyShopContext(supabase);

  if (!ctx.shop) {
    return (
      <PageFrame title="Barber requests" subtitle="Request a new barber account for your shop.">
        <div className="text-sm text-muted-foreground">No shop assigned to this account.</div>
      </PageFrame>
    );
  }

  const { data: requests } = await supabase
    .from("barber_account_requests")
    .select("id, full_name, email, phone, notes, status, created_at, decided_at")
    .eq("shop_id", ctx.shop.id)
    .order("created_at", { ascending: false })
    .limit(200);

  async function createRequest(formData: FormData) {
    "use server";

    const fullName = String(formData.get("full_name") ?? "").trim();
    const email = String(formData.get("email") ?? "").trim().toLowerCase();
    const phone = String(formData.get("phone") ?? "").trim();
    const notes = String(formData.get("notes") ?? "").trim();

    if (!fullName || (!email && !phone)) {
      redirect(`/barber-requests?error=${encodeURIComponent("Full name and at least one contact (email or phone) are required.")}`);
    }

    const supabase = await createAppSupabaseServerClient();
    const { data: userData } = await supabase.auth.getUser();
    if (!userData.user) redirect("/shop/auth/sign-in");

    const ctx = await getMyShopContext(supabase);
    if (!ctx.shop) redirect(`/barber-requests?error=${encodeURIComponent("No shop assigned.")}`);

    const { error } = await supabase.from("barber_account_requests").insert({
      shop_id: ctx.shop.id,
      requested_by_profile_id: userData.user.id,
      full_name: fullName,
      email: email || null,
      phone: phone || null,
      notes: notes || null,
      status: "pending"
    });
    if (error) redirect(`/barber-requests?error=${encodeURIComponent(userFacingDbError(error.message))}`);

    redirect("/barber-requests");
  }

  async function cancelRequest(formData: FormData) {
    "use server";

    const requestId = String(formData.get("request_id") ?? "").trim();
    if (!requestId) redirect("/barber-requests");

    const supabase = await createAppSupabaseServerClient();
    const { data: userData } = await supabase.auth.getUser();
    if (!userData.user) redirect("/shop/auth/sign-in");

    const { error } = await supabase.from("barber_account_requests").update({ status: "cancelled" }).eq("id", requestId);
    if (error) redirect(`/barber-requests?error=${encodeURIComponent(userFacingDbError(error.message))}`);

    redirect("/barber-requests");
  }

  return (
    <PageFrame
      title="Barber requests"
      subtitle="Request a new barber account. Admin will review and create the login."
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/barbers">Back</Link>
        </Button>
      }
    >
      {params?.error ? <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard> : null}

      <div className="grid gap-4 lg:grid-cols-2">
        <LuxuryCard className="border border-white/10 bg-white/5 p-5">
          <div className="text-sm font-semibold">Request new barber account</div>
          <form action={createRequest} className="pt-4 grid gap-3">
            <div className="grid gap-2">
              <Label htmlFor="full_name">Full name</Label>
              <Input id="full_name" name="full_name" required />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="email">Email (optional)</Label>
              <Input id="email" name="email" type="email" />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="phone">Phone (optional)</Label>
              <Input id="phone" name="phone" />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="notes">Notes (optional)</Label>
              <textarea
                id="notes"
                name="notes"
                className="min-h-20 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
              />
            </div>
            <div className="flex justify-end pt-1">
              <Button type="submit">Submit request</Button>
            </div>
          </form>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-5">
          <div className="text-sm font-semibold">Your requests</div>
          <div className="pt-4 grid gap-2">
            {(requests ?? []).map((r) => (
              <div key={r.id} className="rounded-lg border border-white/10 bg-black/20 p-4">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <div className="text-sm font-semibold">{(r.full_name ?? "Barber").trim() || "Barber"}</div>
                    <div className="pt-0.5 text-xs text-muted-foreground">
                      {(r.email ?? "").trim() || "—"} • {(r.phone ?? "").trim() || "—"}
                    </div>
                    <div className="pt-1 text-xs text-muted-foreground">
                      Status: {(r.status ?? "").trim() || "pending"}
                      {r.decided_at ? ` • decided ${new Date(r.decided_at).toLocaleString()}` : ""}
                    </div>
                    {r.notes ? <div className="pt-2 text-xs text-muted-foreground">{r.notes}</div> : null}
                  </div>
                  {r.status === "pending" ? (
                    <form action={cancelRequest}>
                      <input type="hidden" name="request_id" value={r.id} />
                      <Button type="submit" size="sm" variant="secondary">
                        Cancel
                      </Button>
                    </form>
                  ) : null}
                </div>
              </div>
            ))}
            {(requests?.length ?? 0) === 0 ? <div className="text-sm text-muted-foreground">No requests yet.</div> : null}
          </div>
        </LuxuryCard>
      </div>
    </PageFrame>
  );
}


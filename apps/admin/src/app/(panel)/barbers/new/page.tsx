import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";

import { PageFrame } from "@/components/page-frame";
import { getOrCreatePrimaryBranchId } from "@/lib/shop-memberships";

export const dynamic = "force-dynamic";

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong.";
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as an admin user.";
  }
  return m;
}

export default async function NewBarberPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((params?.error ?? "").trim());
  const supabase = await createSupabaseServerClient();

  const { data: barberProfiles } = await supabase
    .from("profiles")
    .select("id, full_name, email, phone, created_at")
    .eq("role", "barber")
    .eq("status", "active")
    .order("created_at", { ascending: false })
    .limit(250);

  const { data: shops } = await supabase
    .from("barbershops")
    .select("id, name")
    .order("created_at", { ascending: false })
    .limit(250);

  async function createBarber(formData: FormData) {
    "use server";

    const profileIdSelect = String(formData.get("profile_id_select") ?? "").trim();
    const profileIdManual = String(formData.get("profile_id") ?? "").trim();
    const profileId = profileIdSelect || profileIdManual;
    const displayName = String(formData.get("display_name") ?? "").trim();
    const area = String(formData.get("area") ?? "").trim();
    const specialty = String(formData.get("specialty") ?? "").trim();
    const shopId = String(formData.get("shop_id") ?? "").trim();

    if (!profileId || !displayName) redirect("/barbers/new");

    const supabase = await createSupabaseServerClient();
    const branchId = shopId ? await getOrCreatePrimaryBranchId(supabase, shopId) : null;
    if (shopId && !branchId) redirect(`/barbers/new?error=${encodeURIComponent("Failed to resolve a branch for the selected shop.")}`);
    const { error } = await supabase
      .from("barbers")
      .upsert(
        {
          profile_id: profileId,
          display_name: displayName,
          area: area || null,
          specialty: specialty || null,
          shop_id: shopId || null,
          branch_id: branchId,
          is_independent: !shopId,
          status: "approved",
          is_verified: true,
          is_active: true,
          deleted_at: null,
        },
        { onConflict: "profile_id" }
      );
    if (error) redirect(`/barbers/new?error=${encodeURIComponent(userFacingDbError(error.message))}`);

    redirect("/barbers");
  }

  return (
    <PageFrame
      title="Create Barber"
      subtitle="Creates a barber profile and makes it visible in the customer app."
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/barbers">Back</Link>
        </Button>
      }
    >
      {params?.error ? (
        <div className="mb-4 rounded-xl border border-rose-500/20 bg-rose-500/10 px-4 py-3 text-sm text-rose-100">
          {error}
        </div>
      ) : null}
      <form action={createBarber} className="grid gap-4">
        <div className="grid gap-2">
          <Label>Barber account</Label>
          {barberProfiles?.length ? (
            <select
              id="profile_id_select"
              name="profile_id_select"
              defaultValue=""
              className="flex h-10 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
            >
              <option value="">Select a barber user…</option>
              {barberProfiles.map((p) => (
                <option key={p.id} value={p.id}>
                  {(p.full_name ?? "Barber").trim() || "Barber"} • {(p.email ?? "").trim() || p.id}
                </option>
              ))}
            </select>
          ) : (
            <div className="text-sm text-muted-foreground">No barber users found yet. Create one from Users → Create user.</div>
          )}

          <Label htmlFor="profile_id">Or paste barber profile id</Label>
          <Input id="profile_id" name="profile_id" placeholder="UUID from profiles.id" />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="display_name">Display name</Label>
          <Input id="display_name" name="display_name" placeholder="Barber name" required />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="area">Area</Label>
          <Input id="area" name="area" placeholder="Manama / Seef / ..." />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="specialty">Specialty</Label>
          <Input id="specialty" name="specialty" placeholder="Fade / Beard / ..." />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="shop_id">Shop (optional)</Label>
          {shops?.length ? (
            <select
              id="shop_id"
              name="shop_id"
              defaultValue=""
              className="flex h-10 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
            >
              <option value="">Independent</option>
              {shops.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
          ) : (
            <div className="text-sm text-muted-foreground">No shops found yet.</div>
          )}
        </div>
        <div className="flex items-center justify-end gap-2 pt-2">
          <Button asChild variant="ghost">
            <Link href="/barbers">Cancel</Link>
          </Button>
          <Button type="submit">Create</Button>
        </div>
      </form>
    </PageFrame>
  );
}

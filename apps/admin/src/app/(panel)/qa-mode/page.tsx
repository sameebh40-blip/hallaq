import { cookies } from "next/headers";
import { redirect } from "next/navigation";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { Label } from "@hallaq/ui/label";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

const qaCookieName = "hallaq-qa-auth";

type ProfileRow = { id: string; full_name: string | null; email: string | null };
type BarberRow = { id: string; display_name: string | null; profile_id: string };
type ShopRow = { id: string; name: string | null; owner_profile_id: string };

function labelForProfile(p: ProfileRow) {
  const name = (p.full_name ?? "").trim();
  const email = (p.email ?? "").trim();
  return (name || email || p.id).slice(0, 80);
}

export default async function QaModePage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) redirect("/auth/sign-in?next=/qa-mode");

  const cookieStore = await cookies();
  const qaActive = cookieStore.get("hallaq_qa_active")?.value === "1";
  const qaRole = cookieStore.get("hallaq_qa_role")?.value ?? "";
  const qaProfileId = cookieStore.get("hallaq_qa_profile_id")?.value ?? "";

  const [{ data: customers }, { data: shopOwners }, { data: barbers }, { data: shops }] = await Promise.all([
    supabase
      .from("profiles")
      .select("id, full_name, email")
      .eq("role", "customer")
      .order("updated_at", { ascending: false })
      .limit(100),
    supabase
      .from("profiles")
      .select("id, full_name, email")
      .eq("role", "shop_owner")
      .order("updated_at", { ascending: false })
      .limit(100),
    supabase
      .from("barbers")
      .select("id, display_name, profile_id")
      .order("updated_at", { ascending: false })
      .limit(100),
    supabase
      .from("barbershops")
      .select("id, name, owner_profile_id")
      .order("updated_at", { ascending: false })
      .limit(100)
  ]);

  async function enterQaMode(formData: FormData) {
    "use server";

    const mode = String(formData.get("mode") ?? "").trim();
    const customerProfileId = String(formData.get("customer_profile_id") ?? "").trim();
    const barberProfileId = String(formData.get("barber_profile_id") ?? "").trim();
    const shopOwnerProfileId = String(formData.get("shop_owner_profile_id") ?? "").trim();
    const shopOwnerFromShop = String(formData.get("shop_owner_from_shop") ?? "").trim();

    const targetProfileId =
      mode === "customer"
        ? customerProfileId
        : mode === "barber"
          ? barberProfileId
          : mode === "shop_owner"
            ? shopOwnerProfileId || shopOwnerFromShop
            : "";

    if (!targetProfileId) redirect("/qa-mode");

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const actorId = user?.id ?? null;
    if (!user) redirect("/auth/sign-in?next=/qa-mode");

    const admin = await createSupabaseAdminClient();
    const { data: targetUser, error: userError } = await admin.auth.admin.getUserById(targetProfileId);
    if (userError || !targetUser.user?.email) redirect("/qa-mode");

    const { data: link, error: linkError } = await admin.auth.admin.generateLink({
      type: "magiclink",
      email: targetUser.user.email,
      options: { redirectTo: process.env.NEXT_PUBLIC_APP_URL ?? "https://app.hallaq.com" }
    });
    if (linkError) redirect("/qa-mode");

    const qaSupabase = await createSupabaseServerClient({ cookieName: qaCookieName });
    const { error: verifyError } = await qaSupabase.auth.verifyOtp({
      type: "magiclink",
      email: targetUser.user.email,
      token: link.properties.email_otp
    });
    if (verifyError) redirect("/qa-mode");

    const cookieStore = await cookies();
    cookieStore.set({ name: "hallaq_qa_active", value: "1", path: "/" });
    cookieStore.set({ name: "hallaq_qa_role", value: mode, path: "/" });
    cookieStore.set({ name: "hallaq_qa_profile_id", value: targetProfileId, path: "/" });

    await Promise.allSettled([
      supabase.from("admin_activity_logs").insert({
        actor_profile_id: actorId,
        action: "qa_mode_entered",
        entity_type: "qa_mode",
        entity_id: null,
        meta: { mode, targetProfileId }
      }),
      supabase.from("admin_audit_logs").insert({
        admin_profile_id: actorId,
        action: "qa_mode_entered",
        target_type: "qa_mode",
        target_id: null,
        meta: { mode, targetProfileId }
      })
    ]);

    const target =
      mode === "customer"
        ? "/home"
        : mode === "barber"
          ? "/barber-dashboard"
          : mode === "shop_owner"
            ? "/shop/dashboard"
            : "/dashboard";

    redirect(target);
  }

  async function exitQaMode() {
    "use server";

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const actorId = user?.id ?? null;

    const qaSupabase = await createSupabaseServerClient({ cookieName: qaCookieName });
    await qaSupabase.auth.signOut();

    const cookieStore = await cookies();
    cookieStore.set({ name: "hallaq_qa_active", value: "", maxAge: 0, path: "/" });
    cookieStore.set({ name: "hallaq_qa_role", value: "", maxAge: 0, path: "/" });
    cookieStore.set({ name: "hallaq_qa_profile_id", value: "", maxAge: 0, path: "/" });

    await Promise.allSettled([
      supabase.from("admin_activity_logs").insert({
        actor_profile_id: actorId,
        action: "qa_mode_exited",
        entity_type: "qa_mode",
        entity_id: null,
        meta: {}
      }),
      supabase.from("admin_audit_logs").insert({
        admin_profile_id: actorId,
        action: "qa_mode_exited",
        target_type: "qa_mode",
        target_id: null,
        meta: {}
      })
    ]);

    redirect("/qa-mode");
  }

  return (
    <PageFrame
      title="QA Mode"
      subtitle="Preview the app as different roles without logging out."
      actions={
        qaActive ? (
          <form action={exitQaMode}>
            <Button type="submit" variant="secondary">
              Exit QA Mode
            </Button>
          </form>
        ) : null
      }
    >
      {qaActive ? (
        <LuxuryCard className="mb-4 border border-white/10 bg-white/5 p-4 text-sm">
          <div className="font-semibold">QA MODE ACTIVE</div>
          <div className="pt-1 text-xs text-muted-foreground">
            Role: {qaRole || "unknown"} • Profile: {qaProfileId || "unknown"}
          </div>
        </LuxuryCard>
      ) : null}

      <form action={enterQaMode} className="grid grid-cols-1 gap-5">
        <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
          <div className="flex flex-col gap-2">
            <Label htmlFor="customer_profile_id">Test customer</Label>
            <select
              id="customer_profile_id"
              name="customer_profile_id"
              className="h-11 rounded-md border border-white/10 bg-white/5 px-3 text-sm"
              defaultValue={customers?.[0]?.id ?? ""}
            >
              {(customers ?? []).map((p) => (
                <option key={p.id} value={p.id}>
                  {labelForProfile(p as ProfileRow)}
                </option>
              ))}
            </select>
          </div>

          <div className="flex flex-col gap-2">
            <Label htmlFor="barber_profile_id">Test barber</Label>
            <select
              id="barber_profile_id"
              name="barber_profile_id"
              className="h-11 rounded-md border border-white/10 bg-white/5 px-3 text-sm"
              defaultValue={(barbers?.[0] as BarberRow | undefined)?.profile_id ?? ""}
            >
              {(barbers ?? []).map((b) => (
                <option key={b.id} value={(b as BarberRow).profile_id}>
                  {String((b as BarberRow).display_name ?? "").trim() || (b as BarberRow).id}
                </option>
              ))}
            </select>
          </div>

          <div className="flex flex-col gap-2">
            <Label htmlFor="shop_owner_profile_id">Test shop owner</Label>
            <select
              id="shop_owner_profile_id"
              name="shop_owner_profile_id"
              className="h-11 rounded-md border border-white/10 bg-white/5 px-3 text-sm"
              defaultValue={shopOwners?.[0]?.id ?? ""}
            >
              {(shopOwners ?? []).map((p) => (
                <option key={p.id} value={p.id}>
                  {labelForProfile(p as ProfileRow)}
                </option>
              ))}
            </select>
          </div>

          <div className="flex flex-col gap-2">
            <Label htmlFor="shop_owner_from_shop">Test shop</Label>
            <select
              id="shop_owner_from_shop"
              name="shop_owner_from_shop"
              className="h-11 rounded-md border border-white/10 bg-white/5 px-3 text-sm"
              defaultValue={(shops?.[0] as ShopRow | undefined)?.owner_profile_id ?? ""}
            >
              {(shops ?? []).map((s) => (
                <option key={s.id} value={(s as ShopRow).owner_profile_id}>
                  {String((s as ShopRow).name ?? "").trim() || (s as ShopRow).id}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div className="grid grid-cols-1 gap-2 md:grid-cols-3">
          <Button type="submit" name="mode" value="customer" className="h-11">
            View as Customer
          </Button>
          <Button type="submit" name="mode" value="barber" className="h-11" variant="secondary">
            View as Barber
          </Button>
          <Button type="submit" name="mode" value="shop_owner" className="h-11" variant="secondary">
            View as Shop Owner
          </Button>
        </div>
      </form>
    </PageFrame>
  );
}

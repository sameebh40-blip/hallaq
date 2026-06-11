import { redirect } from "next/navigation";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getT } from "@hallaq/ui/translations-server";

import { PageFrame } from "@/components/page-frame";
import { logAdminSyncError } from "@/lib/admin-sync-logging";
import { promoteProfileToShopOwner } from "@/lib/profile-role-sync";
import { barberHasBookings, deleteShopMemberships, upsertShopMembership } from "@/lib/shop-memberships";

export const dynamic = "force-dynamic";

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return null;
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as an admin account.";
  }
  if (m === "user_is_shop_owner") return "This user already owns a shop. This request can’t be approved as a barber.";
  if (m === "owner_cannot_be_barber") return "This user cannot be both a shop owner and a barber.";
  if (m === "role_conflict_shop_owner") return "This user cannot become a barber while they are linked as a shop owner.";
  if (m === "role_conflict_barber") return "This user cannot become a shop owner while they are linked as a barber.";
  if (m === "barber_has_bookings" || m === "BOOKING_BARBER_IMMUTABLE") {
    return "This barber already has bookings or booking history, so the barber link cannot be removed or converted to owner/customer.";
  }
  return m;
}

export default async function VerificationPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const t = await getT();
  const params = searchParams ? await searchParams : undefined;
  const pageError = userFacingDbError((params?.error ?? "").trim());

  const supabase = await createSupabaseServerClient();

  const { data: requests, error } = await supabase
    .from("role_requests")
    .select("id, profile_id, requested_role, shop_name, phone, notes, status, created_at")
    .eq("status", "pending")
    .order("created_at", { ascending: false })
    .limit(40);

  async function approve(formData: FormData) {
    "use server";

    const requestId = String(formData.get("requestId") ?? "");
    const profileId = String(formData.get("profileId") ?? "");
    const requestedRole = String(formData.get("requestedRole") ?? "");
    const requestedShopName = String(formData.get("requestedShopName") ?? "").trim();
    if (!requestId || !profileId) redirect("/verification");
    if (!["barber", "shop_owner"].includes(requestedRole)) {
      redirect(`/verification?error=${encodeURIComponent("Invalid requested role.")}`);
    }

    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const admin = await createSupabaseAdminClient();

    if (requestedRole === "barber") {
      const { data: ownedShop } = await admin.from("barbershops").select("id").eq("owner_profile_id", profileId).limit(1).maybeSingle();
      if (ownedShop?.id) redirect(`/verification?error=${encodeURIComponent("user_is_shop_owner")}`);

      const { data: profile } = await supabase.from("profiles").select("full_name, area").eq("id", profileId).maybeSingle();
      const { error: roleError } = await admin.from("profiles").update({ role: "barber" }).eq("id", profileId);
      if (roleError) redirect(`/verification?error=${encodeURIComponent(roleError.message)}`);

      const { error: barberError } = await admin.from("barbers").upsert(
        {
          profile_id: profileId,
          display_name: profile?.full_name ?? "",
          area: profile?.area ?? null,
          is_independent: true
        },
        { onConflict: "profile_id" }
      );
      if (barberError) redirect(`/verification?error=${encodeURIComponent(barberError.message)}`);
      await deleteShopMemberships(admin, { profileId, membershipRole: "barber" });
    }

    if (requestedRole === "shop_owner") {
      if (await barberHasBookings(admin, profileId)) {
        redirect(`/verification?error=${encodeURIComponent("barber_has_bookings")}`);
      }
      await deleteShopMemberships(admin, { profileId, membershipRole: "barber" });
      const { error: barberDeleteError } = await admin.from("barbers").delete().eq("profile_id", profileId);
      if (barberDeleteError) redirect(`/verification?error=${encodeURIComponent(barberDeleteError.message)}`);

      const { data: existing, error: existingError } = await admin
        .from("barbershops")
        .select("id")
        .eq("owner_profile_id", profileId)
        .maybeSingle();
      if (existingError) redirect(`/verification?error=${encodeURIComponent(existingError.message)}`);
      if (!existing?.id) {
        const { data: profile } = await supabase.from("profiles").select("full_name").eq("id", profileId).maybeSingle();
        const shopName = requestedShopName || profile?.full_name || "New shop";
        const { data: createdShop, error: shopError } = await admin
          .from("barbershops")
          .insert({
          owner_profile_id: profileId,
          name: shopName
          })
          .select("id")
          .single();
        if (shopError) redirect(`/verification?error=${encodeURIComponent(shopError.message)}`);
        void createdShop;
      }

      const { data: targetShop } = await admin
        .from("barbershops")
        .select("id")
        .eq("owner_profile_id", profileId)
        .order("created_at", { ascending: false })
        .maybeSingle();
      const finalShopId = String((targetShop as { id?: unknown } | null)?.id ?? "").trim();
      if (finalShopId) {
        try {
          await promoteProfileToShopOwner(admin, profileId);
          await upsertShopMembership(admin, { profileId, shopId: finalShopId, membershipRole: "owner" });
        } catch (e) {
          const message = e instanceof Error ? e.message : "owner_sync_failed";
          await logAdminSyncError(admin, {
            actorId,
            page: "/verification",
            action: "approve_shop_owner_sync",
            error: message,
            meta: { profile_id: profileId, request_id: requestId, shop_id: finalShopId }
          });
          redirect(`/verification?error=${encodeURIComponent(message)}`);
        }
      }
    }

    const { error: reqError } = await supabase
      .from("role_requests")
      .update({ status: "approved", reviewed_at: new Date().toISOString(), reviewed_by: actorId })
      .eq("id", requestId);

    if (reqError) redirect(`/verification?error=${encodeURIComponent(reqError.message)}`);
    redirect("/verification");
  }

  async function reject(formData: FormData) {
    "use server";

    const requestId = String(formData.get("requestId") ?? "");
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const { error: reqError } = await supabase
      .from("role_requests")
      .update({ status: "rejected", reviewed_at: new Date().toISOString(), reviewed_by: actorId })
      .eq("id", requestId);

    if (reqError) redirect(`/verification?error=${encodeURIComponent(reqError.message)}`);
    redirect("/verification");
  }

  return (
    <PageFrame
      title={t("admin.nav.verification")}
      subtitle="Approve role requests, manage badges, and keep the marketplace trusted."
    >
      <div className="flex flex-col gap-4">
        {pageError || error ? (
          <LuxuryCard className="p-4">
            <div className="text-sm text-destructive">{pageError ?? error?.message}</div>
          </LuxuryCard>
        ) : null}

        <LuxuryCard className="overflow-hidden">
          <div className="flex items-center justify-between gap-4 border-b border-white/10 px-4 py-3">
            <div className="text-sm font-medium">Pending role requests</div>
            <div className="text-xs text-muted-foreground">{requests?.length ?? 0} pending</div>
          </div>

          <div className="divide-y divide-white/10">
            {requests?.length ? (
              requests.map((r) => (
                <div key={r.id} className="grid grid-cols-12 items-center gap-0 px-4 py-3 text-sm">
                  <div className="col-span-12 md:col-span-3">
                    <div className="font-medium">{r.shop_name ?? "Role request"}</div>
                    <div className="font-mono text-xs text-muted-foreground">{r.profile_id}</div>
                  </div>
                  <div className="col-span-6 mt-2 text-muted-foreground md:col-span-2 md:mt-0">
                    {r.requested_role}
                  </div>
                  <div className="col-span-6 mt-2 text-muted-foreground md:col-span-3 md:mt-0">
                    {r.phone ?? "-"}
                  </div>
                  <div className="col-span-12 mt-2 text-xs text-muted-foreground md:col-span-2 md:mt-0">
                    {r.notes ?? "—"}
                  </div>
                  <div className="col-span-12 mt-3 flex justify-end gap-2 md:col-span-2 md:mt-0">
                    <form action={approve}>
                      <input type="hidden" name="requestId" value={r.id} />
                      <input type="hidden" name="profileId" value={r.profile_id} />
                      <input type="hidden" name="requestedRole" value={r.requested_role} />
                      <input type="hidden" name="requestedShopName" value={r.shop_name ?? ""} />
                      <Button type="submit" size="sm">
                        Approve
                      </Button>
                    </form>
                    <form action={reject}>
                      <input type="hidden" name="requestId" value={r.id} />
                      <Button type="submit" size="sm" variant="secondary">
                        Reject
                      </Button>
                    </form>
                  </div>
                </div>
              ))
            ) : (
              <div className="px-4 py-10 text-center text-sm text-muted-foreground">
                No pending requests.
              </div>
            )}
          </div>
        </LuxuryCard>
      </div>
    </PageFrame>
  );
}

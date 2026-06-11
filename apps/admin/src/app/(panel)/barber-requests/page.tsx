import { redirect } from "next/navigation";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";

import { PageFrame } from "@/components/page-frame";
import { logAdminSyncError } from "@/lib/admin-sync-logging";
import { getOrCreatePrimaryBranchId, upsertShopMembership } from "@/lib/shop-memberships";

export const dynamic = "force-dynamic";

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong.";
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as an admin user.";
  }
  return m;
}

type RequestRow = {
  id: string;
  shop_id: string;
  full_name: string | null;
  email: string | null;
  phone: string | null;
  notes: string | null;
  status: string | null;
  created_at: string;
  decided_at: string | null;
  barbershops?: { id: string; name: string | null; area: string | null } | null;
};

export default async function BarberRequestsAdminPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((params?.error ?? "").trim());

  const supabase = await createSupabaseServerClient();
  const { data: requests, error: requestsError } = await supabase
    .from("barber_account_requests")
    .select("id, shop_id, full_name, email, phone, notes, status, created_at, decided_at, barbershops(id, name, area)")
    .order("created_at", { ascending: false })
    .limit(500);

  async function approveRequest(formData: FormData) {
    "use server";

    const requestId = String(formData.get("request_id") ?? "").trim();
    const shopId = String(formData.get("shop_id") ?? "").trim();
    const fullName = String(formData.get("full_name") ?? "").trim();
    const email = String(formData.get("email") ?? "").trim().toLowerCase();
    const phone = String(formData.get("phone") ?? "").trim();
    const password = String(formData.get("password") ?? "");

    if (!requestId || !shopId || !fullName || !email || !password) {
      redirect(`/barber-requests?error=${encodeURIComponent("Missing required fields.")}`);
    }

    const adminSession = await createSupabaseServerClient();
    const { data: actorData } = await adminSession.auth.getUser();
    const actorId = actorData.user?.id ?? null;

    const admin = await createSupabaseAdminClient();
    const branchId = await getOrCreatePrimaryBranchId(admin, shopId);
    if (!branchId) redirect(`/barber-requests?error=${encodeURIComponent("Failed to resolve a branch for the selected shop.")}`);

    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName }
    });
    if (createError) redirect(`/barber-requests?error=${encodeURIComponent(userFacingDbError(createError.message))}`);

    const profileId = created.user?.id ?? "";
    if (!profileId) redirect(`/barber-requests?error=${encodeURIComponent("Failed to create auth user.")}`);

    const { error: profileError } = await admin.from("profiles").upsert({
      id: profileId,
      email,
      full_name: fullName,
      phone: phone || null,
      role: "barber",
      status: "active",
      must_change_password: true
    });
    if (profileError) redirect(`/barber-requests?error=${encodeURIComponent(userFacingDbError(profileError.message))}`);

    const { data: createdBarber, error: barberError } = await admin
      .from("barbers")
      .insert({
        profile_id: profileId,
        display_name: fullName,
        shop_id: shopId,
        branch_id: branchId,
        is_independent: false,
        status: "approved",
        is_active: true,
        is_verified: true,
        deleted_at: null
      })
      .select("id")
      .single();
    if (barberError) redirect(`/barber-requests?error=${encodeURIComponent(userFacingDbError(barberError.message))}`);

    const barberId = createdBarber?.id ?? "";
    if (!barberId) redirect(`/barber-requests?error=${encodeURIComponent("Failed to create barber record.")}`);

    try {
      await upsertShopMembership(admin, { profileId, shopId, branchId, membershipRole: "barber" });
    } catch (e) {
      const message = e instanceof Error ? e.message : "membership_sync_failed";
      await logAdminSyncError(admin, {
        actorId,
        page: "/barber-requests",
        action: "approve_barber_request_membership_sync",
        error: message,
        meta: { profile_id: profileId, shop_id: shopId, branch_id: branchId, request_id: requestId }
      });
      redirect(`/barber-requests?error=${encodeURIComponent(userFacingDbError(message))}`);
    }

    const { data: existingHours } = await admin.from("barber_working_hours").select("id").eq("barber_id", barberId).limit(1);
    if ((existingHours?.length ?? 0) === 0) {
      const rows = Array.from({ length: 7 }).map((_, weekday) => ({
        barber_id: barberId,
        weekday,
        start_time: "09:00",
        end_time: "21:00",
        enabled: true
      }));
      await admin.from("barber_working_hours").insert(rows);
    }

    const { error: requestUpdateError } = await admin
      .from("barber_account_requests")
      .update({
        status: "approved",
        decided_by_profile_id: actorId,
        decided_at: new Date().toISOString()
      })
      .eq("id", requestId);
    if (requestUpdateError) redirect(`/barber-requests?error=${encodeURIComponent(userFacingDbError(requestUpdateError.message))}`);

    await admin.from("notifications").insert({
      profile_id: profileId,
      type: "system",
      title: "Your barber account has been created.",
      body: "Please change your password on first login."
    });

    if (actorId) {
      await adminSession.from("audit_events").insert({
        actor_profile_id: actorId,
        action: "admin_approve_barber_request",
        entity_type: "barber",
        entity_id: barberId,
        meta: { request_id: requestId, shop_id: shopId, profile_id: profileId }
      });
    }

    redirect("/barber-requests");
  }

  async function rejectRequest(formData: FormData) {
    "use server";

    const requestId = String(formData.get("request_id") ?? "").trim();
    if (!requestId) redirect("/barber-requests");

    const supabase = await createSupabaseServerClient();
    const { data: actorData } = await supabase.auth.getUser();
    const actorId = actorData.user?.id ?? null;

    const { error } = await supabase
      .from("barber_account_requests")
      .update({ status: "rejected", decided_by_profile_id: actorId, decided_at: new Date().toISOString() })
      .eq("id", requestId);
    if (error) redirect(`/barber-requests?error=${encodeURIComponent(userFacingDbError(error.message))}`);

    redirect("/barber-requests");
  }

  return (
    <PageFrame title="Barber requests" subtitle="Approve shop-submitted barber account requests.">
      {params?.error ? (
        <div className="mb-4 rounded-xl border border-rose-500/20 bg-rose-500/10 px-4 py-3 text-sm text-rose-100">
          {error}
        </div>
      ) : null}

      {requestsError ? <div className="text-sm text-muted-foreground">{requestsError.message}</div> : null}

      <div className="grid gap-4">
        {(requests as RequestRow[] | null)?.map((r) => {
          const shopName = r.barbershops?.name ?? "Shop";
          const shopArea = r.barbershops?.area ?? null;
          return (
            <div key={r.id} className="rounded-xl border border-border bg-card p-4">
              <div className="flex flex-col gap-1">
                <div className="text-sm font-semibold">{(r.full_name ?? "Barber").trim() || "Barber"}</div>
                <div className="text-xs text-muted-foreground">
                  {(r.email ?? "").trim() || "—"} • {(r.phone ?? "").trim() || "—"}
                </div>
                <div className="text-xs text-muted-foreground">
                  Shop: {shopName}
                  {shopArea ? ` • ${shopArea}` : ""} • Status: {(r.status ?? "").trim() || "pending"}
                </div>
                {r.notes ? <div className="pt-2 text-xs text-muted-foreground">{r.notes}</div> : null}
              </div>

              {r.status === "pending" ? (
                <div className="pt-4 grid gap-3">
                  <form action={approveRequest} className="grid gap-3 rounded-lg border border-border bg-black/20 p-4">
                    <input type="hidden" name="request_id" value={r.id} />
                    <input type="hidden" name="shop_id" value={r.shop_id} />

                    <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
                      <div className="grid gap-2">
                        <Label htmlFor={`full_name_${r.id}`}>Full name</Label>
                        <Input id={`full_name_${r.id}`} name="full_name" defaultValue={r.full_name ?? ""} required />
                      </div>
                      <div className="grid gap-2">
                        <Label htmlFor={`phone_${r.id}`}>Phone</Label>
                        <Input id={`phone_${r.id}`} name="phone" defaultValue={r.phone ?? ""} />
                      </div>
                    </div>
                    <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
                      <div className="grid gap-2">
                        <Label htmlFor={`email_${r.id}`}>Email</Label>
                        <Input id={`email_${r.id}`} name="email" type="email" defaultValue={r.email ?? ""} required />
                      </div>
                      <div className="grid gap-2">
                        <Label htmlFor={`password_${r.id}`}>Temporary password</Label>
                        <Input id={`password_${r.id}`} name="password" type="password" required />
                      </div>
                    </div>

                    <div className="flex items-center justify-end gap-2">
                      <Button type="submit" size="sm">
                        Approve & create account
                      </Button>
                    </div>
                  </form>

                  <form action={rejectRequest} className="flex justify-end">
                    <input type="hidden" name="request_id" value={r.id} />
                    <Button type="submit" size="sm" variant="secondary">
                      Reject
                    </Button>
                  </form>
                </div>
              ) : null}
            </div>
          );
        })}

        {(requests?.length ?? 0) === 0 ? <div className="text-sm text-muted-foreground">No requests yet.</div> : null}
      </div>
    </PageFrame>
  );
}

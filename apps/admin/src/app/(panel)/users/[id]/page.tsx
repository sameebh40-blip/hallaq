import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getT } from "@hallaq/ui/translations-server";

import { PageFrame } from "@/components/page-frame";
import { logAdminSyncError } from "@/lib/admin-sync-logging";
import { normalizeManagedProfileRole, promoteProfileToShopOwner } from "@/lib/profile-role-sync";
import { barberHasBookings, deleteShopMemberships, upsertShopMembership } from "@/lib/shop-memberships";

export const dynamic = "force-dynamic";

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong.";
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as an admin account.";
  }
  if (m === "use_assign_owner") return "To make this user a shop owner, assign them to a shop (or create a new shop) using the assignment form.";
  if (m === "use_assign_barber") return "To make this user a barber, assign them to a shop/branch or mark them independent using the assignment form.";
  if (m === "shop_required") return "Please select a shop (or choose “Create new shop”).";
  if (m === "new_shop_name_required") return "Please enter a name for the new shop.";
  if (m === "branch_required") return "Please select a branch (or choose Independent).";
  if (m === "user_is_shop_owner") return "This user is already a shop owner. Reassign their shop ownership before assigning them as a barber.";
  if (m === "shop_owner_has_shop") return "This user owns a shop. Transfer shop ownership before changing their role away from shop_owner.";
  if (m === "owner_cannot_be_barber") return "This user cannot be both a shop owner and a barber.";
  if (m === "role_conflict_barber") return "This user cannot become a shop owner while they are linked as a barber.";
  if (m === "role_conflict_shop_owner") return "This user cannot become a barber while they are linked as a shop owner.";
  if (m === "barber_has_bookings" || m === "BOOKING_BARBER_IMMUTABLE") {
    return "This barber already has bookings or booking history, so the barber link cannot be removed or converted to owner/customer.";
  }
  return m;
}

export default async function UserDetailPage({
  params,
  searchParams
}: {
  params: Promise<{ id: string }>;
  searchParams?: Promise<{ error?: string }>;
}) {
  const { id: userId } = await params;
  const sp = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((sp?.error ?? "").trim());
  const t = await getT();
  const supabase = await createSupabaseServerClient();

  const { data: profile } = await supabase.from("profiles").select("*").eq("id", userId).maybeSingle();

  if (!profile) redirect("/users");

  type AuthUserShape = {
    last_sign_in_at: string | null;
    created_at: string | null;
    email: string | null;
    phone: string | null;
    email_confirmed_at: string | null;
    phone_confirmed_at: string | null;
    app_metadata: { provider?: string; providers?: string[] } | null;
  };

  let authUser: AuthUserShape | null = null;
  try {
    const admin = await createSupabaseAdminClient();
    const { data } = await admin.auth.admin.getUserById(userId);
    const u = (data.user ?? null) as unknown as Record<string, unknown> | null;
    authUser = u
      ? {
          last_sign_in_at: typeof u.last_sign_in_at === "string" ? u.last_sign_in_at : null,
          created_at: typeof u.created_at === "string" ? u.created_at : null,
          email: typeof u.email === "string" ? u.email : null,
          phone: typeof u.phone === "string" ? u.phone : null,
          email_confirmed_at: typeof u.email_confirmed_at === "string" ? u.email_confirmed_at : null,
          phone_confirmed_at: typeof u.phone_confirmed_at === "string" ? u.phone_confirmed_at : null,
          app_metadata:
            typeof u.app_metadata === "object" && u.app_metadata && !Array.isArray(u.app_metadata)
              ? (u.app_metadata as { provider?: string; providers?: string[] })
              : null
        }
      : null;
  } catch {
    authUser = null;
  }

  let barberLink: { id: string; shop_id: string | null; branch_id: string | null } | null = null;
  let shopOwnerLink: { id: string; name: string | null } | null = null;
  try {
    const admin = await createSupabaseAdminClient();
    const [{ data: barber }, { data: shop }] = await Promise.all([
      admin.from("barbers").select("id, shop_id, branch_id").eq("profile_id", userId).maybeSingle(),
      admin.from("barbershops").select("id, name").eq("owner_profile_id", userId).maybeSingle()
    ]);
    barberLink = barber
      ? {
          id: barber.id as string,
          shop_id: (barber.shop_id as string | null) ?? null,
          branch_id: (barber.branch_id as string | null) ?? null
        }
      : null;
    shopOwnerLink = shop ? { id: shop.id as string, name: (shop.name as string | null) ?? null } : null;
  } catch {
    barberLink = null;
    shopOwnerLink = null;
  }

  const hasEmail = "email" in profile;
  const hasStatus = "status" in profile;

  const { data: shops } = await supabase
    .from("barbershops")
    .select("id, name")
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(300);

  const { data: branches } = await supabase
    .from("shop_branches")
    .select("id, name, shop_id")
    .order("created_at", { ascending: true })
    .limit(1200);

  const barberShopName =
    barberLink?.shop_id ? String((shops ?? []).find((s) => s.id === barberLink.shop_id)?.name ?? barberLink.shop_id) : null;
  const barberBranchName =
    barberLink?.branch_id ? String((branches ?? []).find((b) => b.id === barberLink.branch_id)?.name ?? barberLink.branch_id) : null;

  async function save(formData: FormData) {
    "use server";

    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const fullName = String(formData.get("fullName") ?? "").trim();
    const phone = String(formData.get("phone") ?? "").trim();
    const role = String(formData.get("role") ?? "").trim();
    const status = String(formData.get("status") ?? "").trim();
    const area = String(formData.get("area") ?? "").trim();

    if (!["customer", "barber", "shop_owner", "admin"].includes(role)) redirect(`/users/${userId}`);
    if (status && !["active", "suspended"].includes(status)) redirect(`/users/${userId}`);

    const { data: current } = await supabase.from("profiles").select("*").eq("id", userId).maybeSingle();
    const includeStatus = !!current && "status" in current;
    const currentRole = String((current as { role?: unknown })?.role ?? "").trim();

    if (role !== currentRole) {
      if (role === "shop_owner") redirect(`/users/${userId}?error=${encodeURIComponent("use_assign_owner")}`);
      if (role === "barber") redirect(`/users/${userId}?error=${encodeURIComponent("use_assign_barber")}`);
    }

    const updatePayload: Record<string, unknown> = {
      full_name: fullName || null,
      phone: phone || null,
      area: area || null
    };

    if (includeStatus) updatePayload.status = status || "active";

    const { error: updateError } = await supabase
      .from("profiles")
      .update(updatePayload)
      .eq("id", userId);
    if (updateError) redirect(`/users/${userId}?error=${encodeURIComponent(updateError.message)}`);

    if (role !== currentRole) {
      const admin = await createSupabaseAdminClient();

      if (currentRole === "barber" && role !== "barber") {
        if (await barberHasBookings(admin, userId)) {
          redirect(`/users/${userId}?error=${encodeURIComponent("barber_has_bookings")}`);
        }
        await deleteShopMemberships(admin, { profileId: userId, membershipRole: "barber" });
        const { error: barberDeleteError } = await admin.from("barbers").delete().eq("profile_id", userId);
        if (barberDeleteError) redirect(`/users/${userId}?error=${encodeURIComponent(barberDeleteError.message)}`);
      }

      if (currentRole === "shop_owner" && role !== "shop_owner") {
        const { data: ownedShop } = await admin.from("barbershops").select("id").eq("owner_profile_id", userId).limit(1).maybeSingle();
        if (ownedShop?.id) redirect(`/users/${userId}?error=${encodeURIComponent("shop_owner_has_shop")}`);
      }

      if (role === "customer") {
        try {
          await normalizeManagedProfileRole(admin, userId);
        } catch (e) {
          const message = e instanceof Error ? e.message : "role_sync_failed";
          await logAdminSyncError(admin, {
            actorId,
            page: `/users/${userId}`,
            action: "update_user_role_sync",
            error: message,
            meta: { user_id: userId, requested_role: role, current_role: currentRole }
          });
          redirect(`/users/${userId}?error=${encodeURIComponent(message)}`);
        }
      } else {
        const { error: roleError } = await admin.from("profiles").update({ role }).eq("id", userId);
        if (roleError) redirect(`/users/${userId}?error=${encodeURIComponent(roleError.message)}`);
      }
    }

    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "user_updated",
      entity_type: "profile",
      entity_id: userId,
      meta: { fullName, phone, role, status: includeStatus ? status : null, area }
    });
    if (logError) redirect(`/users/${userId}?error=${encodeURIComponent(logError.message)}`);

    redirect(`/users/${userId}`);
  }

  async function assignOwner(formData: FormData) {
    "use server";

    const shopId = String(formData.get("shopId") ?? "").trim();
    const shopName = String(formData.get("shopName") ?? "").trim();

    const admin = await createSupabaseAdminClient();

    if (await barberHasBookings(admin, userId)) {
      redirect(`/users/${userId}?error=${encodeURIComponent("barber_has_bookings")}`);
    }
    await deleteShopMemberships(admin, { profileId: userId, membershipRole: "barber" });
    const { error: barberDeleteError } = await admin.from("barbers").delete().eq("profile_id", userId);
    if (barberDeleteError) redirect(`/users/${userId}?error=${encodeURIComponent(barberDeleteError.message)}`);

    if (!shopId) redirect(`/users/${userId}?error=${encodeURIComponent("shop_required")}`);

    let finalShopId: string | null = null;

    if (shopId === "__new__") {
      const { data: current } = await admin.from("profiles").select("full_name, email").eq("id", userId).maybeSingle();
      const fullName = String((current as { full_name?: unknown })?.full_name ?? "").trim();
      const email = String((current as { email?: unknown })?.email ?? "").trim();
      const resolvedShopName = shopName || fullName || email || userId;
      if (!resolvedShopName) redirect(`/users/${userId}?error=${encodeURIComponent("new_shop_name_required")}`);

      const { data: shop, error: shopError } = await admin
        .from("barbershops")
        .insert({ owner_profile_id: userId, name: resolvedShopName })
        .select("id")
        .single();
      if (shopError) redirect(`/users/${userId}?error=${encodeURIComponent(shopError.message)}`);
      finalShopId = String((shop as { id?: unknown })?.id ?? "").trim() || null;
      if (!finalShopId) redirect(`/users/${userId}?error=${encodeURIComponent("shop_insert_failed")}`);

    } else {
      finalShopId = shopId;
      const { error: assignError } = await admin.from("barbershops").update({ owner_profile_id: userId }).eq("id", finalShopId);
      if (assignError) redirect(`/users/${userId}?error=${encodeURIComponent(assignError.message)}`);
    }

    if (finalShopId) {
      try {
        await promoteProfileToShopOwner(admin, userId);
        await upsertShopMembership(admin, { profileId: userId, shopId: finalShopId, membershipRole: "owner" });
      } catch (e) {
        const message = e instanceof Error ? e.message : "membership_sync_failed";
        await logAdminSyncError(admin, {
          page: `/users/${userId}`,
          action: "assign_owner_sync",
          error: message,
          meta: { user_id: userId, shop_id: finalShopId }
        });
        redirect(`/users/${userId}?error=${encodeURIComponent(message)}`);
      }
    }

    redirect(`/users/${userId}`);
  }

  async function assignBarber(formData: FormData) {
    "use server";

    const shopBranch = String(formData.get("shopBranch") ?? "").trim();

    const admin = await createSupabaseAdminClient();

    const { data: ownedShop } = await admin.from("barbershops").select("id").eq("owner_profile_id", userId).limit(1).maybeSingle();
    if (ownedShop?.id) redirect(`/users/${userId}?error=${encodeURIComponent("user_is_shop_owner")}`);

    const { error: roleError } = await admin.from("profiles").update({ role: "barber" }).eq("id", userId);
    if (roleError) redirect(`/users/${userId}?error=${encodeURIComponent(roleError.message)}`);

    const [shopId, branchId] = shopBranch ? shopBranch.split(":") : ["", ""];
    const resolvedShopId = (shopId ?? "").trim();
    const resolvedBranchId = (branchId ?? "").trim();

    let finalBranchId = resolvedBranchId;

    if (resolvedShopId && !finalBranchId) redirect(`/users/${userId}?error=${encodeURIComponent("branch_required")}`);
    if (resolvedShopId && finalBranchId === "__create__") {
      const { data: createdBranch, error: branchError } = await admin
        .from("shop_branches")
        .insert({ shop_id: resolvedShopId, name: "Main Branch" })
        .select("id")
        .single();
      if (branchError) redirect(`/users/${userId}?error=${encodeURIComponent(branchError.message)}`);
      finalBranchId = String((createdBranch as { id?: unknown })?.id ?? "").trim();
      if (!finalBranchId) redirect(`/users/${userId}?error=${encodeURIComponent("branch_insert_failed")}`);
    }

    const { data: current } = await admin.from("profiles").select("full_name, email, area").eq("id", userId).maybeSingle();
    const resolvedName =
      String((current as { full_name?: unknown })?.full_name ?? "").trim() ||
      String((current as { email?: unknown })?.email ?? "").trim() ||
      userId;
    const resolvedArea = String((current as { area?: unknown })?.area ?? "").trim() || null;
    const { error: barberUpsertError } = await admin.from("barbers").upsert(
      {
        profile_id: userId,
        display_name: resolvedName,
        area: resolvedArea,
        is_independent: !resolvedShopId,
        shop_id: resolvedShopId || null,
        branch_id: resolvedShopId ? finalBranchId : null
      },
      { onConflict: "profile_id" }
    );
    if (barberUpsertError) redirect(`/users/${userId}?error=${encodeURIComponent(barberUpsertError.message)}`);

    try {
      if (resolvedShopId && finalBranchId) {
        await upsertShopMembership(admin, {
          profileId: userId,
          shopId: resolvedShopId,
          branchId: finalBranchId,
          membershipRole: "barber"
        });
      } else {
        await deleteShopMemberships(admin, { profileId: userId, membershipRole: "barber" });
      }
    } catch (e) {
      const message = e instanceof Error ? e.message : "membership_sync_failed";
      await logAdminSyncError(admin, {
        page: `/users/${userId}`,
        action: "assign_barber_sync",
        error: message,
        meta: { user_id: userId, shop_id: resolvedShopId || null, branch_id: finalBranchId || null }
      });
      redirect(`/users/${userId}?error=${encodeURIComponent(message)}`);
    }

    redirect(`/users/${userId}`);
  }

  async function fixRoleConnections(formData: FormData) {
    "use server";

    if (String(formData.get("confirm") ?? "").trim() !== "CONFIRM") redirect(`/users/${userId}?error=${encodeURIComponent("confirmation_required")}`);

    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;
    if (!u.user) redirect("/auth/sign-in?next=/users");

    const admin = await createSupabaseAdminClient();
    const { data: current } = await admin.from("profiles").select("id, full_name, role, area").eq("id", userId).maybeSingle();
    const role = typeof current?.role === "string" ? current.role : null;
    if (!role) redirect(`/users/${userId}?error=${encodeURIComponent("missing_role")}`);

    if (role === "barber") {
      const displayName = (typeof current?.full_name === "string" ? current.full_name : "").trim();
      const area = typeof current?.area === "string" ? current.area : null;
      const { error: barberError } = await admin.from("barbers").upsert(
        { profile_id: userId, display_name: displayName, area, is_independent: true },
        { onConflict: "profile_id" }
      );
      if (barberError) redirect(`/users/${userId}?error=${encodeURIComponent(barberError.message)}`);
    }

    if (role === "shop_owner") {
      const { data: existing } = await admin.from("barbershops").select("id").eq("owner_profile_id", userId).maybeSingle();
      if (!existing?.id) {
        const name = (typeof current?.full_name === "string" ? current.full_name : "").trim();
        const { error: shopError } = await admin.from("barbershops").insert({ owner_profile_id: userId, name });
        if (shopError) redirect(`/users/${userId}?error=${encodeURIComponent(shopError.message)}`);
      }
    }

    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "user_role_connections_fixed",
      entity_type: "profile",
      entity_id: userId,
      meta: { role }
    });
    if (logError) redirect(`/users/${userId}?error=${encodeURIComponent(logError.message)}`);

    redirect(`/users/${userId}`);
  }

  async function sendPasswordReset(formData: FormData) {
    "use server";

    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const email = String(formData.get("email") ?? "").trim();
    if (!email) redirect(`/users/${userId}`);

    const { error: resetError } = await supabase.auth.resetPasswordForEmail(email);
    if (resetError) redirect(`/users/${userId}?error=${encodeURIComponent(resetError.message)}`);

    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "user_password_reset_sent",
      entity_type: "profile",
      entity_id: userId,
      meta: { email }
    });
    if (logError) redirect(`/users/${userId}?error=${encodeURIComponent(logError.message)}`);

    redirect(`/users/${userId}`);
  }

  return (
    <PageFrame
      title={t("admin.nav.users")}
      subtitle="User profile, role, and contact details."
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/users">{t("admin.common.refresh")}</Link>
        </Button>
      }
    >
      {sp?.error ? (
        <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard>
      ) : null}
      <div className="grid grid-cols-1 gap-4 xl:grid-cols-2">
        <LuxuryCard className="p-5">
          <form action={save} className="flex flex-col gap-4">
            <div className="flex flex-col gap-2">
              <Label>User ID</Label>
              <div className="rounded-lg border border-white/10 bg-white/5 px-3 py-3 font-mono text-xs text-muted-foreground">
                {profile.id}
              </div>
            </div>

            <div className="flex flex-col gap-2">
              <Label>Email</Label>
              <div className="rounded-lg border border-white/10 bg-white/5 px-3 py-3 text-sm text-muted-foreground">
                {hasEmail ? (profile.email ?? "—") : "—"}
              </div>
            </div>

            <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
              <div className="flex flex-col gap-2">
                <Label htmlFor="fullName">Full name</Label>
                <Input
                  id="fullName"
                  name="fullName"
                  defaultValue={profile.full_name ?? ""}
                  className="h-11 bg-white/5"
                />
              </div>
              <div className="flex flex-col gap-2">
                <Label htmlFor="phone">Phone</Label>
                <Input id="phone" name="phone" defaultValue={profile.phone ?? ""} className="h-11 bg-white/5" />
              </div>
            </div>

            <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
              <div className="flex flex-col gap-2">
                <Label htmlFor="role">Role</Label>
                <select
                  id="role"
                  name="role"
                  defaultValue={profile.role ?? "customer"}
                  className="flex h-11 w-full rounded-md border border-input bg-white/5 px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
                >
                  <option value="customer">customer</option>
                  <option value="shop_owner" disabled>
                    shop_owner
                  </option>
                  <option value="barber" disabled>
                    barber
                  </option>
                  <option value="admin">admin</option>
                </select>
              </div>
              <div className="flex flex-col gap-2">
                <Label htmlFor="status">Status</Label>
                <select
                  id="status"
                  name="status"
                  defaultValue={hasStatus ? profile.status ?? "active" : "active"}
                  className="flex h-11 w-full rounded-md border border-input bg-white/5 px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
                  disabled={!hasStatus}
                >
                  <option value="active">active</option>
                  <option value="suspended">suspended</option>
                </select>
              </div>
            </div>

            <div className="flex flex-col gap-2">
              <Label htmlFor="area">Area</Label>
              <Input id="area" name="area" defaultValue={profile.area ?? ""} className="h-11 bg-white/5" />
            </div>

            <Button type="submit" className="h-11">
              {t("admin.common.save")}
            </Button>
          </form>
        </LuxuryCard>

        <LuxuryCard className="p-5">
          <div className="flex flex-col gap-3">
            <div className="text-sm font-semibold">Meta</div>
            <div className="rounded-lg border border-white/10 bg-white/5 p-4 text-sm text-muted-foreground">
              Created:{" "}
              {profile.created_at
                ? Intl.DateTimeFormat("en", { dateStyle: "medium" }).format(new Date(profile.created_at))
                : "—"}
            </div>
            {authUser ? (
              <div className="rounded-lg border border-white/10 bg-white/5 p-4 text-sm text-muted-foreground">
                <div>Email confirmed: {authUser.email_confirmed_at ? "Yes" : "No"}</div>
                <div>Phone confirmed: {authUser.phone_confirmed_at ? "Yes" : "No"}</div>
                <div>
                  Last sign-in:{" "}
                  {authUser.last_sign_in_at
                    ? Intl.DateTimeFormat("en", { dateStyle: "medium", timeStyle: "short" }).format(
                        new Date(authUser.last_sign_in_at)
                      )
                    : "—"}
                </div>
                <div>Provider: {authUser.app_metadata?.provider ?? authUser.app_metadata?.providers?.[0] ?? "—"}</div>
              </div>
            ) : null}
            <form action={sendPasswordReset}>
              <input type="hidden" name="email" value={hasEmail ? profile.email ?? "" : ""} />
              <Button type="submit" variant="secondary" disabled={!hasEmail || !profile.email}>
                Send password reset email
              </Button>
            </form>
          </div>
        </LuxuryCard>

        <LuxuryCard className="p-5">
          <div className="flex flex-col gap-4">
            <div className="text-sm font-semibold">Assignments</div>
            <div className="rounded-lg border border-white/10 bg-white/5 p-4 text-sm text-muted-foreground">
              {shopOwnerLink ? <div>Owner of: {shopOwnerLink.name ?? shopOwnerLink.id}</div> : null}
              {barberLink ? (
                <div>
                  Barber at: {barberShopName ?? "Independent"}
                  {barberBranchName ? ` / ${barberBranchName}` : barberLink.shop_id ? "" : ""}
                </div>
              ) : null}
              {!shopOwnerLink && !barberLink ? <div>No shop or barber assignment yet.</div> : null}
            </div>

            <form action={assignOwner} className="flex flex-col gap-3">
              <div className="text-xs text-muted-foreground">Assign as shop owner (requires choosing a shop)</div>
              <div className="flex flex-col gap-2 md:flex-row md:items-center">
                <select
                  name="shopId"
                  defaultValue=""
                  className="flex h-11 w-full rounded-md border border-input bg-white/5 px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring md:max-w-[320px]"
                >
                  <option value="">Select shop…</option>
                  <option value="__new__">Create new shop…</option>
                  {(shops ?? []).map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.name ?? s.id}
                    </option>
                  ))}
                </select>
                <Input
                  name="shopName"
                  placeholder="New shop name (if creating)"
                  className="h-11 w-full bg-white/5 md:max-w-[360px]"
                />
                <Button type="submit" variant="secondary" className="h-11">
                  Assign owner
                </Button>
              </div>
            </form>

            <form action={assignBarber} className="flex flex-col gap-3">
              <div className="text-xs text-muted-foreground">Assign as barber (choose a branch or mark independent)</div>
              <div className="flex flex-col gap-2 md:flex-row md:items-center">
                <select
                  name="shopBranch"
                  defaultValue=""
                  className="flex h-11 w-full rounded-md border border-input bg-white/5 px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring md:max-w-[420px]"
                >
                  <option value="">Independent</option>
                  {(shops ?? []).flatMap((s) => {
                    const shopId = String(s.id ?? "").trim();
                    if (!shopId) return [];
                    const hasBranches = (branches ?? []).some((b) => String(b.shop_id ?? "") === shopId);
                    if (hasBranches) return [];
                    const shopName = String(s.name ?? s.id);
                    return (
                      <option key={`${shopId}:__create__`} value={`${shopId}:__create__`}>
                        {shopName} — Create branch
                      </option>
                    );
                  })}
                  {(branches ?? [])
                    .filter((b) => b.shop_id)
                    .map((b) => {
                      const shopName = String((shops ?? []).find((s) => s.id === b.shop_id)?.name ?? b.shop_id);
                      const branchName = String(b.name ?? "").trim() || String(b.id);
                      return (
                        <option key={b.id} value={`${b.shop_id}:${b.id}`}>
                          {shopName} — {branchName}
                        </option>
                      );
                    })}
                </select>
                <Button type="submit" variant="secondary" className="h-11">
                  Assign barber
                </Button>
              </div>
            </form>
          </div>
        </LuxuryCard>

        <LuxuryCard className="p-5">
          <div className="flex flex-col gap-3">
            <div className="text-sm font-semibold">Role connection diagnostic</div>
            <div className="rounded-lg border border-white/10 bg-white/5 p-4 text-sm text-muted-foreground">
              <div>Auth User ID: {userId}</div>
              <div>Profile ID: {profile.id}</div>
              <div>Profile Role: {profile.role ?? "—"}</div>
              <div>Profile Status: {hasStatus ? (profile.status ?? "—") : "—"}</div>
              <div>Barber Profile Exists: {barberLink?.id ? "Yes" : "No"}</div>
              <div>Shop Owner Link Exists: {shopOwnerLink?.id ? "Yes" : "No"}</div>
              <div>
                Expected Route:{" "}
                {profile.role === "admin"
                  ? "/admin"
                  : profile.role === "shop_owner"
                    ? "/shop-dashboard"
                    : profile.role === "barber"
                      ? "/barber-dashboard"
                      : "/home"}
              </div>
            </div>
            <form action={fixRoleConnections} className="flex flex-col gap-3">
              <div className="grid gap-2">
                <Label>Type CONFIRM</Label>
                <Input name="confirm" placeholder="CONFIRM" className="h-11 bg-white/5" />
              </div>
              <Button type="submit" variant="secondary">
                Fix Role Connections
              </Button>
            </form>
          </div>
        </LuxuryCard>
      </div>
    </PageFrame>
  );
}

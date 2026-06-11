import { redirect } from "next/navigation";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

function normalizeRole(value: unknown) {
  const r = typeof value === "string" ? value : "";
  return r === "admin" || r === "customer" || r === "barber" || r === "shop_owner" ? r : null;
}

async function logAdminAction(params: {
  actorId: string | null;
  action: string;
  targetType?: string | null;
  targetId?: string | null;
  meta?: Record<string, unknown>;
}) {
  const supabase = await createSupabaseServerClient();
  await Promise.allSettled([
    supabase.from("admin_audit_logs").insert({
      admin_profile_id: params.actorId,
      action: params.action,
      target_type: params.targetType ?? null,
      target_id: params.targetId ?? null,
      meta: params.meta ?? {}
    }),
    supabase.from("admin_activity_logs").insert({
      actor_profile_id: params.actorId,
      action: params.action,
      entity_type: params.targetType ?? null,
      entity_id: params.targetId ?? null,
      meta: params.meta ?? {}
    })
  ]);
}

async function logRepairAction(params: {
  adminId: string | null;
  repairType: string;
  targetTable: string;
  targetId?: string | null;
  beforeData?: Record<string, unknown> | null;
  afterData?: Record<string, unknown> | null;
  status: "success" | "failed" | "dry_run";
  errorMessage?: string | null;
}) {
  const supabase = await createSupabaseServerClient();
  await supabase.from("repair_logs").insert({
    admin_id: params.adminId,
    repair_type: params.repairType,
    target_table: params.targetTable,
    target_id: params.targetId ?? null,
    before_data: params.beforeData ?? null,
    after_data: params.afterData ?? null,
    status: params.status,
    error_message: params.errorMessage ?? null
  });
}

function requireConfirm(formData: FormData, expected: string) {
  const v = String(formData.get("confirm") ?? "").trim();
  return v === expected;
}

function formBool(formData: FormData, key: string) {
  const v = formData.get(key);
  if (v === null) return false;
  if (typeof v === "string") return v === "1" || v.toLowerCase() === "true" || v.toLowerCase() === "on";
  return false;
}

export default async function DataRepairPage({ searchParams }: { searchParams?: Promise<{ error?: string }> }) {
  const params = searchParams ? await searchParams : undefined;
  const error = (params?.error ?? "").trim() || null;

  const supabase = await createSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();
  if (!user) redirect("/auth/sign-in?next=/data-repair");

  const { data: myProfile } = await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle();
  if (myProfile?.role !== "admin") redirect("/");

  const admin = await createSupabaseAdminClient();

  const [
    { data: barberRoleProfiles },
    { data: shopOwnerRoleProfiles },
    { data: barbers },
    { data: shops },
    { data: branches },
    { data: services },
    { data: authUsers, error: authUsersError }
  ] = await Promise.all([
    admin.from("profiles").select("id, full_name, area").eq("role", "barber").limit(500),
    admin.from("profiles").select("id, full_name").eq("role", "shop_owner").limit(500),
    admin.from("barbers").select("id, profile_id, shop_id, branch_id").limit(2000),
    admin.from("barbershops").select("id, owner_profile_id").limit(2000),
    admin.from("shop_branches").select("id, shop_id, name").limit(5000),
    admin.from("services").select("id, shop_id, barber_id, status, is_active, deleted_at").limit(5000),
    admin.auth.admin.listUsers({ perPage: 1000, page: 1 })
  ]);

  const barberProfileIds = new Set((barbers ?? []).map((b) => String((b as { profile_id?: unknown }).profile_id ?? "")));
  const shopOwnerProfileIds = new Set((shops ?? []).map((s) => String((s as { owner_profile_id?: unknown }).owner_profile_id ?? "")));
  const shopIdsWithBranches = new Set((branches ?? []).map((b) => String((b as { shop_id?: unknown }).shop_id ?? "")));
  const shopsMissingBranches = (shops ?? []).filter((s) => !shopIdsWithBranches.has(String((s as { id?: unknown }).id ?? "")));
  const barbersMissingBranch = (barbers ?? []).filter((b) => {
    const row = b as { shop_id?: unknown; branch_id?: unknown };
    const shopId = String(row.shop_id ?? "").trim();
    const branchId = String(row.branch_id ?? "").trim();
    return !!shopId && !branchId;
  });
  const servicesMissingVisibilityStatus = (services ?? []).filter((s) => {
    const row = s as { shop_id?: unknown; barber_id?: unknown; status?: unknown; is_active?: unknown; deleted_at?: unknown };
    const owned = !!String(row.shop_id ?? "").trim() || !!String(row.barber_id ?? "").trim();
    const status = String(row.status ?? "").trim();
    return owned && row.deleted_at == null && Boolean(row.is_active ?? true) && !status;
  });

  const missingBarberRows = (barberRoleProfiles ?? []).filter((p) => !barberProfileIds.has(String((p as { id?: unknown }).id ?? "")));
  const missingShopRows = (shopOwnerRoleProfiles ?? []).filter((p) => !shopOwnerProfileIds.has(String((p as { id?: unknown }).id ?? "")));

  const authUserIds = authUsersError ? [] : (authUsers?.users ?? []).map((u) => u.id);
  const { data: authUserProfiles } = authUserIds.length
    ? await admin.from("profiles").select("id").in("id", authUserIds)
    : { data: [] as { id: string }[] };
  const profileSet = new Set((authUserProfiles ?? []).map((p) => p.id));
  const missingProfileIds = authUserIds.filter((id) => !profileSet.has(id));

  const { data: invalidRoleProfiles, error: invalidRoleError } = await admin
    .from("profiles")
    .select("id, role")
    .not("role", "in", '("customer","barber","shop_owner","admin")')
    .limit(200);

  async function fixRoleConnectionsAll(formData: FormData) {
    "use server";

    if (!requireConfirm(formData, "CONFIRM")) redirect("/data-repair?error=confirmation_required");
    const dryRun = formBool(formData, "dry_run");

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const actorId = user?.id ?? null;
    if (!user) redirect("/auth/sign-in?next=/data-repair");

    const { data: roleProfile } = await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle();
    if (roleProfile?.role !== "admin") redirect("/");

    const admin = await createSupabaseAdminClient();

    const [{ data: barberRoleProfiles }, { data: shopOwnerRoleProfiles }, { data: barbers }, { data: shops }] = await Promise.all([
      admin.from("profiles").select("id, full_name, area").eq("role", "barber").limit(2000),
      admin.from("profiles").select("id, full_name").eq("role", "shop_owner").limit(2000),
      admin.from("barbers").select("profile_id").limit(5000),
      admin.from("barbershops").select("owner_profile_id").limit(5000)
    ]);

    const barberProfileIds = new Set((barbers ?? []).map((b) => String((b as { profile_id?: unknown }).profile_id ?? "")));
    const shopOwnerProfileIds = new Set((shops ?? []).map((s) => String((s as { owner_profile_id?: unknown }).owner_profile_id ?? "")));

    const missingBarberRows = (barberRoleProfiles ?? []).filter((p) => !barberProfileIds.has(String((p as { id?: unknown }).id ?? "")));
    const missingShopRows = (shopOwnerRoleProfiles ?? []).filter((p) => !shopOwnerProfileIds.has(String((p as { id?: unknown }).id ?? "")));

    const beforeData = {
      missing_barbers_count: missingBarberRows.length,
      missing_shops_count: missingShopRows.length
    };

    if (dryRun) {
      await logAdminAction({
        actorId,
        action: "repair_fix_role_connections_all",
        targetType: "system",
        targetId: null,
        meta: { dryRun: true, ...beforeData }
      });
      await logRepairAction({
        adminId: actorId,
        repairType: "fix_role_connections_all",
        targetTable: "profiles",
        targetId: null,
        beforeData,
        afterData: beforeData,
        status: "dry_run",
        errorMessage: null
      });
      redirect("/data-repair");
    }

    const { error: barberUpsertError } = missingBarberRows.length
      ? await admin.from("barbers").upsert(
          missingBarberRows.map((p) => {
            const row = p as { id?: unknown; full_name?: unknown; area?: unknown };
            return {
              profile_id: String(row.id ?? ""),
              display_name: typeof row.full_name === "string" ? row.full_name : "",
              area: typeof row.area === "string" ? row.area : null,
              is_independent: true
            };
          }),
          { onConflict: "profile_id" }
        )
      : { error: null };

    const { error: shopInsertError } = missingShopRows.length
      ? await admin.from("barbershops").insert(
          missingShopRows.map((p) => {
            const row = p as { id?: unknown; full_name?: unknown };
            return {
              owner_profile_id: String(row.id ?? ""),
              name: typeof row.full_name === "string" ? row.full_name : ""
            };
          })
        )
      : { error: null };

    const errorMessage = barberUpsertError?.message || shopInsertError?.message || null;

    const afterData = {
      created_barbers_count: missingBarberRows.length,
      created_shops_count: missingShopRows.length
    };

    await logAdminAction({
      actorId,
      action: "repair_fix_role_connections_all",
      targetType: "system",
      targetId: null,
      meta: { ...beforeData, ...afterData, error: errorMessage }
    });
    await logRepairAction({
      adminId: actorId,
      repairType: "fix_role_connections_all",
      targetTable: "profiles",
      targetId: null,
      beforeData,
      afterData,
      status: errorMessage ? "failed" : "success",
      errorMessage
    });

    if (errorMessage) redirect(`/data-repair?error=${encodeURIComponent(errorMessage)}`);
    redirect("/data-repair");
  }

  async function fixBranchIntegrityAll(formData: FormData) {
    "use server";

    if (!requireConfirm(formData, "CONFIRM")) redirect("/data-repair?error=confirmation_required");
    const dryRun = formBool(formData, "dry_run");

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const actorId = user?.id ?? null;
    if (!user) redirect("/auth/sign-in?next=/data-repair");

    const { data: roleProfile } = await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle();
    if (roleProfile?.role !== "admin") redirect("/");

    const admin = await createSupabaseAdminClient();

    const [{ data: shops }, { data: branches }, { data: barbers }] = await Promise.all([
      admin.from("barbershops").select("id").limit(10000),
      admin.from("shop_branches").select("id, shop_id, created_at").order("created_at", { ascending: true }).limit(20000),
      admin.from("barbers").select("id, shop_id, branch_id").limit(20000)
    ]);

    const shopIdsWithBranches = new Set((branches ?? []).map((b) => String((b as { shop_id?: unknown }).shop_id ?? "")));
    const shopsMissingBranches = (shops ?? []).filter((s) => !shopIdsWithBranches.has(String((s as { id?: unknown }).id ?? "")));
    const barbersMissingBranch = (barbers ?? []).filter((b) => {
      const row = b as { shop_id?: unknown; branch_id?: unknown };
      const shopId = String(row.shop_id ?? "").trim();
      const branchId = String(row.branch_id ?? "").trim();
      return !!shopId && !branchId;
    });

    const beforeData = {
      shops_missing_branches_count: shopsMissingBranches.length,
      barbers_missing_branch_count: barbersMissingBranch.length
    };

    if (dryRun) {
      await logAdminAction({
        actorId,
        action: "repair_fix_branch_integrity_all",
        targetType: "system",
        targetId: null,
        meta: { dryRun: true, ...beforeData }
      });
      await logRepairAction({
        adminId: actorId,
        repairType: "fix_branch_integrity_all",
        targetTable: "shop_branches",
        targetId: null,
        beforeData,
        afterData: beforeData,
        status: "dry_run",
        errorMessage: null
      });
      redirect("/data-repair");
    }

    const { error: branchCreateError } = shopsMissingBranches.length
      ? await admin.from("shop_branches").insert(
          shopsMissingBranches.map((s) => ({
            shop_id: String((s as { id?: unknown }).id ?? ""),
            name: "Main Branch"
          }))
        )
      : { error: null };

    if (branchCreateError) redirect(`/data-repair?error=${encodeURIComponent(branchCreateError.message)}`);

    const { data: refreshedBranches } = await admin
      .from("shop_branches")
      .select("id, shop_id, created_at")
      .order("created_at", { ascending: true })
      .limit(20000);

    const firstBranchByShop = new Map<string, string>();
    for (const b of refreshedBranches ?? []) {
      const row = b as { id?: unknown; shop_id?: unknown };
      const shopId = String(row.shop_id ?? "").trim();
      const branchId = String(row.id ?? "").trim();
      if (!shopId || !branchId) continue;
      if (!firstBranchByShop.has(shopId)) firstBranchByShop.set(shopId, branchId);
    }

    const toFix = barbersMissingBranch
      .map((b) => {
        const row = b as { id?: unknown; shop_id?: unknown };
        const barberId = String(row.id ?? "").trim();
        const shopId = String(row.shop_id ?? "").trim();
        const branchId = shopId ? firstBranchByShop.get(shopId) ?? "" : "";
        return barberId && shopId && branchId ? { barberId, branchId } : null;
      })
      .filter(Boolean) as { barberId: string; branchId: string }[];

    let fixedBarbersCount = 0;
    for (const item of toFix) {
      const { error } = await admin.from("barbers").update({ branch_id: item.branchId }).eq("id", item.barberId);
      if (!error) fixedBarbersCount += 1;
    }

    const afterData = {
      created_branches_count: shopsMissingBranches.length,
      fixed_barbers_count: fixedBarbersCount
    };

    await logAdminAction({
      actorId,
      action: "repair_fix_branch_integrity_all",
      targetType: "system",
      targetId: null,
      meta: { ...beforeData, ...afterData }
    });
    await logRepairAction({
      adminId: actorId,
      repairType: "fix_branch_integrity_all",
      targetTable: "shop_branches",
      targetId: null,
      beforeData,
      afterData,
      status: "success",
      errorMessage: null
    });

    redirect("/data-repair");
  }

  async function fixMissingProfilesAll(formData: FormData) {
    "use server";

    if (!requireConfirm(formData, "CONFIRM")) redirect("/data-repair?error=confirmation_required");
    const dryRun = formBool(formData, "dry_run");

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const actorId = user?.id ?? null;
    if (!user) redirect("/auth/sign-in?next=/data-repair");

    const { data: roleProfile } = await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle();
    if (roleProfile?.role !== "admin") redirect("/");

    const admin = await createSupabaseAdminClient();
    const { data: authUsers, error: authUsersError } = await admin.auth.admin.listUsers({ perPage: 1000, page: 1 });
    if (authUsersError) redirect(`/data-repair?error=${encodeURIComponent(authUsersError.message)}`);

    const ids = authUsers.users.map((u) => u.id);
    const { data: profiles } = ids.length ? await admin.from("profiles").select("id").in("id", ids) : { data: [] as { id: string }[] };
    const set = new Set((profiles ?? []).map((p) => p.id));
    const missing = ids.filter((id) => !set.has(id)).slice(0, 200);

    const beforeData = { missing_profiles_count: missing.length, sample_ids: missing.slice(0, 50) };
    if (dryRun) {
      await logAdminAction({ actorId, action: "repair_fix_missing_profiles_all", targetType: "system", targetId: null, meta: { dryRun: true, ...beforeData } });
      await logRepairAction({
        adminId: actorId,
        repairType: "fix_missing_profiles_all",
        targetTable: "profiles",
        targetId: null,
        beforeData,
        afterData: beforeData,
        status: "dry_run",
        errorMessage: null
      });
      redirect("/data-repair");
    }

    const authMap = new Map(authUsers.users.map((u) => [u.id, u]));
    const inserts = missing.map((id) => {
      const u = authMap.get(id);
      return {
        id,
        email: u?.email ?? null,
        phone: u?.phone ?? null,
        role: "customer",
        status: "active"
      };
    });

    const { error } = inserts.length ? await admin.from("profiles").insert(inserts) : { error: null };
    const errorMessage = error?.message ?? null;
    const afterData = { created_profiles_count: inserts.length };

    await logAdminAction({
      actorId,
      action: "repair_fix_missing_profiles_all",
      targetType: "system",
      targetId: null,
      meta: { ...beforeData, ...afterData, error: errorMessage }
    });
    await logRepairAction({
      adminId: actorId,
      repairType: "fix_missing_profiles_all",
      targetTable: "profiles",
      targetId: null,
      beforeData,
      afterData,
      status: errorMessage ? "failed" : "success",
      errorMessage
    });

    if (errorMessage) redirect(`/data-repair?error=${encodeURIComponent(errorMessage)}`);
    redirect("/data-repair");
  }

  async function normalizeInvalidRolesAll(formData: FormData) {
    "use server";

    if (!requireConfirm(formData, "CONFIRM")) redirect("/data-repair?error=confirmation_required");
    const dryRun = formBool(formData, "dry_run");

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const actorId = user?.id ?? null;
    if (!user) redirect("/auth/sign-in?next=/data-repair");

    const { data: roleProfile } = await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle();
    if (roleProfile?.role !== "admin") redirect("/");

    const admin = await createSupabaseAdminClient();
    const { data: bad, error: badError } = await admin
      .from("profiles")
      .select("id, role")
      .not("role", "in", '("customer","barber","shop_owner","admin")')
      .limit(2000);
    if (badError) redirect(`/data-repair?error=${encodeURIComponent(badError.message)}`);

    const ids = (bad ?? []).map((p) => String((p as { id?: unknown }).id ?? "")).filter(Boolean).slice(0, 2000);
    const beforeData = { invalid_roles_count: ids.length, sample_ids: ids.slice(0, 50) };

    if (dryRun) {
      await logAdminAction({ actorId, action: "repair_normalize_invalid_roles_all", targetType: "system", targetId: null, meta: { dryRun: true, ...beforeData } });
      await logRepairAction({
        adminId: actorId,
        repairType: "normalize_invalid_roles_all",
        targetTable: "profiles",
        targetId: null,
        beforeData,
        afterData: beforeData,
        status: "dry_run",
        errorMessage: null
      });
      redirect("/data-repair");
    }

    const { error } = ids.length ? await admin.from("profiles").update({ role: "customer" }).in("id", ids) : { error: null };
    const errorMessage = error?.message ?? null;
    const afterData = { normalized_roles_count: ids.length };

    await logAdminAction({
      actorId,
      action: "repair_normalize_invalid_roles_all",
      targetType: "system",
      targetId: null,
      meta: { ...beforeData, ...afterData, error: errorMessage }
    });
    await logRepairAction({
      adminId: actorId,
      repairType: "normalize_invalid_roles_all",
      targetTable: "profiles",
      targetId: null,
      beforeData,
      afterData,
      status: errorMessage ? "failed" : "success",
      errorMessage
    });

    if (errorMessage) redirect(`/data-repair?error=${encodeURIComponent(errorMessage)}`);
    redirect("/data-repair");
  }

  async function fixServiceVisibilityAll(formData: FormData) {
    "use server";

    if (!requireConfirm(formData, "CONFIRM")) redirect("/data-repair?error=confirmation_required");
    const dryRun = formBool(formData, "dry_run");

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const actorId = user?.id ?? null;
    if (!user) redirect("/auth/sign-in?next=/data-repair");

    const { data: roleProfile } = await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle();
    if (roleProfile?.role !== "admin") redirect("/");

    const admin = await createSupabaseAdminClient();
    const { data: services } = await admin.from("services").select("id, shop_id, barber_id, status, is_active, deleted_at").limit(10000);

    const targetIds = (services ?? [])
      .filter((s) => {
        const row = s as { id?: unknown; shop_id?: unknown; barber_id?: unknown; status?: unknown; is_active?: unknown; deleted_at?: unknown };
        const owned = !!String(row.shop_id ?? "").trim() || !!String(row.barber_id ?? "").trim();
        const status = String(row.status ?? "").trim();
        return owned && row.deleted_at == null && Boolean(row.is_active ?? true) && !status;
      })
      .map((s) => String((s as { id?: unknown }).id ?? "").trim())
      .filter(Boolean);

    const beforeData = { missing_visibility_status_count: targetIds.length };

    if (dryRun) {
      await logAdminAction({
        actorId,
        action: "repair_fix_service_visibility_all",
        targetType: "system",
        targetId: null,
        meta: { dryRun: true, ...beforeData }
      });
      await logRepairAction({
        adminId: actorId,
        repairType: "fix_service_visibility_all",
        targetTable: "services",
        beforeData,
        afterData: beforeData,
        status: "dry_run"
      });
      redirect("/data-repair");
    }

    if (targetIds.length) {
      const { error: updateError } = await admin.from("services").update({ status: "approved" }).in("id", targetIds);
      if (updateError) redirect(`/data-repair?error=${encodeURIComponent(updateError.message)}`);
    }

    const afterData = { approved_services_count: targetIds.length };
    await logAdminAction({
      actorId,
      action: "repair_fix_service_visibility_all",
      targetType: "system",
      targetId: null,
      meta: { ...beforeData, ...afterData }
    });
    await logRepairAction({
      adminId: actorId,
      repairType: "fix_service_visibility_all",
      targetTable: "services",
      beforeData,
      afterData,
      status: "success"
    });

    redirect("/data-repair");
  }

  async function fixMissingProfile(formData: FormData) {
    "use server";

    const profileId = String(formData.get("profile_id") ?? "").trim();
    if (!profileId) redirect("/data-repair?error=missing_profile_id");
    if (!requireConfirm(formData, "CONFIRM")) redirect("/data-repair?error=confirmation_required");

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const actorId = user?.id ?? null;
    if (!user) redirect("/auth/sign-in?next=/data-repair");

    const admin = await createSupabaseAdminClient();
    const { data: before } = await admin.from("profiles").select("*").eq("id", profileId).maybeSingle();
    const { data: authUser } = await admin.auth.admin.getUserById(profileId);
    const email = authUser.user?.email ?? null;
    const phone = authUser.user?.phone ?? null;

    const { error } = await admin.from("profiles").insert({
      id: profileId,
      email,
      phone,
      role: "customer",
      status: "active"
    });

    const { data: after } = await admin.from("profiles").select("*").eq("id", profileId).maybeSingle();
    await logAdminAction({ actorId, action: "repair_fix_missing_profile", targetType: "profile", targetId: profileId, meta: { error: error?.message ?? null } });
    await logRepairAction({
      adminId: actorId,
      repairType: "fix_missing_profile",
      targetTable: "profiles",
      targetId: profileId,
      beforeData: before ? (before as Record<string, unknown>) : null,
      afterData: after ? (after as Record<string, unknown>) : null,
      status: error ? "failed" : "success",
      errorMessage: error?.message ?? null
    });
    if (error) redirect(`/data-repair?error=${encodeURIComponent(error.message)}`);
    redirect("/data-repair");
  }

  async function fixMissingRole(formData: FormData) {
    "use server";

    const profileId = String(formData.get("profile_id") ?? "").trim();
    const role = normalizeRole(formData.get("role"));
    if (!profileId || !role) redirect("/data-repair?error=invalid_payload");
    if (!requireConfirm(formData, "CONFIRM")) redirect("/data-repair?error=confirmation_required");

    const admin = await createSupabaseAdminClient();
    const { data: before } = await admin.from("profiles").select("*").eq("id", profileId).maybeSingle();
    const { error } = await admin.from("profiles").update({ role }).eq("id", profileId);
    const { data: after } = await admin.from("profiles").select("*").eq("id", profileId).maybeSingle();

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const actorId = user?.id ?? null;
    await logAdminAction({ actorId, action: "repair_fix_missing_role", targetType: "profile", targetId: profileId, meta: { role, error: error?.message ?? null } });
    await logRepairAction({
      adminId: actorId,
      repairType: "fix_missing_role",
      targetTable: "profiles",
      targetId: profileId,
      beforeData: before ? (before as Record<string, unknown>) : null,
      afterData: after ? (after as Record<string, unknown>) : null,
      status: error ? "failed" : "success",
      errorMessage: error?.message ?? null
    });
    if (error) redirect(`/data-repair?error=${encodeURIComponent(error.message)}`);
    redirect("/data-repair");
  }

  async function assignShopOwner(formData: FormData) {
    "use server";

    const shopId = String(formData.get("shop_id") ?? "").trim();
    const ownerProfileId = String(formData.get("owner_profile_id") ?? "").trim();
    if (!shopId || !ownerProfileId) redirect("/data-repair?error=invalid_payload");
    if (!requireConfirm(formData, "CONFIRM")) redirect("/data-repair?error=confirmation_required");

    const admin = await createSupabaseAdminClient();
    const { data: before } = await admin.from("barbershops").select("*").eq("id", shopId).maybeSingle();
    const { error } = await admin.from("barbershops").update({ owner_profile_id: ownerProfileId }).eq("id", shopId);
    const { data: after } = await admin.from("barbershops").select("*").eq("id", shopId).maybeSingle();

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const actorId = user?.id ?? null;
    await logAdminAction({ actorId, action: "repair_assign_shop_owner", targetType: "shop", targetId: shopId, meta: { ownerProfileId, error: error?.message ?? null } });
    await logRepairAction({
      adminId: actorId,
      repairType: "assign_shop_owner",
      targetTable: "barbershops",
      targetId: shopId,
      beforeData: before ? (before as Record<string, unknown>) : null,
      afterData: after ? (after as Record<string, unknown>) : null,
      status: error ? "failed" : "success",
      errorMessage: error?.message ?? null
    });
    if (error) redirect(`/data-repair?error=${encodeURIComponent(error.message)}`);
    redirect("/data-repair");
  }

  async function assignBarberToShop(formData: FormData) {
    "use server";

    const barberId = String(formData.get("barber_id") ?? "").trim();
    const shopId = String(formData.get("shop_id") ?? "").trim();
    if (!barberId || !shopId) redirect("/data-repair?error=invalid_payload");
    if (!requireConfirm(formData, "CONFIRM")) redirect("/data-repair?error=confirmation_required");

    const admin = await createSupabaseAdminClient();
    const { data: before } = await admin.from("barbers").select("*").eq("id", barberId).maybeSingle();
    const { error } = await admin.from("barbers").update({ shop_id: shopId, is_independent: false }).eq("id", barberId);
    const { data: after } = await admin.from("barbers").select("*").eq("id", barberId).maybeSingle();

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const actorId = user?.id ?? null;
    await logAdminAction({ actorId, action: "repair_assign_barber_to_shop", targetType: "barber", targetId: barberId, meta: { shopId, error: error?.message ?? null } });
    await logRepairAction({
      adminId: actorId,
      repairType: "assign_barber_to_shop",
      targetTable: "barbers",
      targetId: barberId,
      beforeData: before ? (before as Record<string, unknown>) : null,
      afterData: after ? (after as Record<string, unknown>) : null,
      status: error ? "failed" : "success",
      errorMessage: error?.message ?? null
    });
    if (error) redirect(`/data-repair?error=${encodeURIComponent(error.message)}`);
    redirect("/data-repair");
  }

  async function markBarberIndependent(formData: FormData) {
    "use server";

    const barberId = String(formData.get("barber_id") ?? "").trim();
    if (!barberId) redirect("/data-repair?error=invalid_payload");
    if (!requireConfirm(formData, "CONFIRM")) redirect("/data-repair?error=confirmation_required");

    const admin = await createSupabaseAdminClient();
    const { data: before } = await admin.from("barbers").select("*").eq("id", barberId).maybeSingle();
    const { error } = await admin.from("barbers").update({ is_independent: true, shop_id: null }).eq("id", barberId);
    const { data: after } = await admin.from("barbers").select("*").eq("id", barberId).maybeSingle();

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const actorId = user?.id ?? null;
    await logAdminAction({ actorId, action: "repair_mark_barber_independent", targetType: "barber", targetId: barberId, meta: { error: error?.message ?? null } });
    await logRepairAction({
      adminId: actorId,
      repairType: "mark_barber_independent",
      targetTable: "barbers",
      targetId: barberId,
      beforeData: before ? (before as Record<string, unknown>) : null,
      afterData: after ? (after as Record<string, unknown>) : null,
      status: error ? "failed" : "success",
      errorMessage: error?.message ?? null
    });
    if (error) redirect(`/data-repair?error=${encodeURIComponent(error.message)}`);
    redirect("/data-repair");
  }

  async function deactivateService(formData: FormData) {
    "use server";

    const serviceId = String(formData.get("service_id") ?? "").trim();
    if (!serviceId) redirect("/data-repair?error=invalid_payload");
    if (!requireConfirm(formData, "CONFIRM")) redirect("/data-repair?error=confirmation_required");

    const admin = await createSupabaseAdminClient();
    const { data: before } = await admin.from("services").select("*").eq("id", serviceId).maybeSingle();
    const { error } = await admin.from("services").update({ is_active: false, deleted_at: new Date().toISOString() }).eq("id", serviceId);
    const { data: after } = await admin.from("services").select("*").eq("id", serviceId).maybeSingle();

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const actorId = user?.id ?? null;
    await logAdminAction({ actorId, action: "repair_deactivate_service", targetType: "service", targetId: serviceId, meta: { error: error?.message ?? null } });
    await logRepairAction({
      adminId: actorId,
      repairType: "deactivate_service",
      targetTable: "services",
      targetId: serviceId,
      beforeData: before ? (before as Record<string, unknown>) : null,
      afterData: after ? (after as Record<string, unknown>) : null,
      status: error ? "failed" : "success",
      errorMessage: error?.message ?? null
    });
    if (error) redirect(`/data-repair?error=${encodeURIComponent(error.message)}`);
    redirect("/data-repair");
  }

  async function hideReel(formData: FormData) {
    "use server";

    const reelId = String(formData.get("reel_id") ?? "").trim();
    if (!reelId) redirect("/data-repair?error=invalid_payload");
    if (!requireConfirm(formData, "CONFIRM")) redirect("/data-repair?error=confirmation_required");

    const admin = await createSupabaseAdminClient();
    const { data: before } = await admin.from("reels").select("*").eq("id", reelId).maybeSingle();
    const { error } = await admin.from("reels").update({ status: "rejected", rejection_reason: "Hidden by data-repair" }).eq("id", reelId);
    const { data: after } = await admin.from("reels").select("*").eq("id", reelId).maybeSingle();

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const actorId = user?.id ?? null;
    await logAdminAction({ actorId, action: "repair_hide_reel", targetType: "reel", targetId: reelId, meta: { error: error?.message ?? null } });
    await logRepairAction({
      adminId: actorId,
      repairType: "hide_reel",
      targetTable: "reels",
      targetId: reelId,
      beforeData: before ? (before as Record<string, unknown>) : null,
      afterData: after ? (after as Record<string, unknown>) : null,
      status: error ? "failed" : "success",
      errorMessage: error?.message ?? null
    });
    if (error) redirect(`/data-repair?error=${encodeURIComponent(error.message)}`);
    redirect("/data-repair");
  }

  async function rebuildCounters(formData: FormData) {
    "use server";

    if (!requireConfirm(formData, "CONFIRM")) redirect("/data-repair?error=confirmation_required");

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const actorId = user?.id ?? null;
    if (!user) redirect("/auth/sign-in?next=/data-repair");

    const { error } = await supabase.rpc("recompute_all_ratings");
    await logAdminAction({ actorId, action: "repair_rebuild_counters", targetType: "system", targetId: null, meta: { error: (error as { message?: string } | null)?.message ?? null } });
    await logRepairAction({
      adminId: actorId,
      repairType: "rebuild_counters",
      targetTable: "rpc",
      targetId: "recompute_all_ratings",
      beforeData: null,
      afterData: null,
      status: error ? "failed" : "success",
      errorMessage: (error as { message?: string } | null)?.message ?? null
    });
    if (error) redirect(`/data-repair?error=${encodeURIComponent((error as { message?: string }).message ?? "failed")}`);
    redirect("/data-repair");
  }

  async function refreshCachedData(formData: FormData) {
    "use server";

    if (!requireConfirm(formData, "CONFIRM")) redirect("/data-repair?error=confirmation_required");

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const actorId = user?.id ?? null;
    if (!user) redirect("/auth/sign-in?next=/data-repair");

    const { error } = await supabase.rpc("warm_availability_cache_all", { p_days_ahead: 62, p_max_barbers: 400, p_slot_minutes: 30 });
    await logAdminAction({ actorId, action: "repair_refresh_cached_data", targetType: "system", targetId: null, meta: { error: (error as { message?: string } | null)?.message ?? null } });
    await logRepairAction({
      adminId: actorId,
      repairType: "refresh_cached_data",
      targetTable: "rpc",
      targetId: "warm_availability_cache_all",
      beforeData: null,
      afterData: null,
      status: error ? "failed" : "success",
      errorMessage: (error as { message?: string } | null)?.message ?? null
    });
    if (error) redirect(`/data-repair?error=${encodeURIComponent((error as { message?: string }).message ?? "failed")}`);
    redirect("/data-repair");
  }

  return (
    <PageFrame title="Data Repair Center" subtitle="Safe admin-only tools. Type CONFIRM for every repair." actions={null}>
      {error ? <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard> : null}

      <div className="mb-4 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <LuxuryCard className="border border-white/10 bg-white/5 p-5">
          <div className="text-sm font-semibold">Role Repair</div>
          <div className="pt-2 text-xs text-muted-foreground">
            Role connections are derived only from profiles.role. This checks required linked rows.
          </div>
          <div className="mt-3 space-y-1 text-sm text-muted-foreground">
            <div>Barber role missing barber row: {missingBarberRows.length}</div>
            <div>Shop owner role missing shop row: {missingShopRows.length}</div>
          </div>
          <form action={fixRoleConnectionsAll} className="mt-4 grid gap-3">
            <label className="flex items-center gap-2 text-xs text-muted-foreground">
              <input type="checkbox" name="dry_run" value="1" />
              Dry-run (log only)
            </label>
            <div className="grid gap-2">
              <Label>Type CONFIRM</Label>
              <Input name="confirm" placeholder="CONFIRM" className="h-11 bg-white/5" />
            </div>
            <Button type="submit" className="h-11">
              Fix all safe issues
            </Button>
          </form>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-5">
          <div className="text-sm font-semibold">User/Profile Repair</div>
          <div className="pt-2 text-xs text-muted-foreground">Detects auth users without profiles and invalid roles.</div>
          <div className="mt-3 space-y-1 text-sm text-muted-foreground">
            <div>Auth users missing profile: {authUsersError ? "—" : missingProfileIds.length}</div>
            <div>Profiles with invalid role: {invalidRoleError ? "—" : (invalidRoleProfiles?.length ?? 0)}</div>
          </div>
          <div className="mt-4 grid gap-3">
            <form action={fixMissingProfilesAll} className="grid gap-3">
              <div className="text-xs text-muted-foreground">Fix missing profiles (safe)</div>
              <label className="flex items-center gap-2 text-xs text-muted-foreground">
                <input type="checkbox" name="dry_run" value="1" />
                Dry-run (log only)
              </label>
              <div className="grid gap-2">
                <Label>Type CONFIRM</Label>
                <Input name="confirm" placeholder="CONFIRM" className="h-11 bg-white/5" />
              </div>
              <Button type="submit" className="h-11" variant="secondary">
                Fix missing profiles
              </Button>
            </form>
            <form action={normalizeInvalidRolesAll} className="grid gap-3">
              <div className="text-xs text-muted-foreground">Normalize invalid roles → customer (safe)</div>
              <label className="flex items-center gap-2 text-xs text-muted-foreground">
                <input type="checkbox" name="dry_run" value="1" />
                Dry-run (log only)
              </label>
              <div className="grid gap-2">
                <Label>Type CONFIRM</Label>
                <Input name="confirm" placeholder="CONFIRM" className="h-11 bg-white/5" />
              </div>
              <Button type="submit" className="h-11" variant="secondary">
                Normalize invalid roles
              </Button>
            </form>
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-5 lg:col-span-2">
          <div className="text-sm font-semibold">Role Repair Preview</div>
          <div className="pt-2 text-xs text-muted-foreground">First 20 issues (for safety).</div>
          <div className="mt-3 grid grid-cols-1 gap-3 md:grid-cols-2">
            <div className="rounded-lg border border-white/10 bg-white/5 p-4 text-sm text-muted-foreground">
              <div className="mb-2 font-semibold text-white/90">Missing barbers rows</div>
              {missingBarberRows.slice(0, 20).map((p) => {
                const row = p as { id?: unknown; full_name?: unknown };
                return (
                  <div key={String(row.id ?? "")} className="font-mono text-xs">
                    {String(row.id ?? "")} {typeof row.full_name === "string" ? `• ${row.full_name}` : ""}
                  </div>
                );
              })}
              {missingBarberRows.length === 0 ? <div className="text-xs">No issues found.</div> : null}
            </div>
            <div className="rounded-lg border border-white/10 bg-white/5 p-4 text-sm text-muted-foreground">
              <div className="mb-2 font-semibold text-white/90">Missing shops rows</div>
              {missingShopRows.slice(0, 20).map((p) => {
                const row = p as { id?: unknown; full_name?: unknown };
                return (
                  <div key={String(row.id ?? "")} className="font-mono text-xs">
                    {String(row.id ?? "")} {typeof row.full_name === "string" ? `• ${row.full_name}` : ""}
                  </div>
                );
              })}
              {missingShopRows.length === 0 ? <div className="text-xs">No issues found.</div> : null}
            </div>
          </div>
        </LuxuryCard>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <LuxuryCard className="border border-white/10 bg-white/5 p-5">
          <div className="text-sm font-semibold">Fix missing profile</div>
          <form action={fixMissingProfile} className="mt-4 grid gap-3">
            <div className="grid gap-2">
              <Label>Profile ID</Label>
              <Input name="profile_id" placeholder="uuid" className="h-11 bg-white/5" />
            </div>
            <div className="grid gap-2">
              <Label>Type CONFIRM</Label>
              <Input name="confirm" placeholder="CONFIRM" className="h-11 bg-white/5" />
            </div>
            <Button type="submit" className="h-11">
              Fix
            </Button>
          </form>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-5">
          <div className="text-sm font-semibold">Fix missing role</div>
          <form action={fixMissingRole} className="mt-4 grid gap-3">
            <div className="grid gap-2">
              <Label>Profile ID</Label>
              <Input name="profile_id" placeholder="uuid" className="h-11 bg-white/5" />
            </div>
            <div className="grid gap-2">
              <Label>Role</Label>
              <select name="role" defaultValue="customer" className="h-11 rounded-md border border-white/10 bg-white/5 px-3 text-sm">
                <option value="customer">customer</option>
                <option value="barber">barber</option>
                <option value="shop_owner">shop_owner</option>
                <option value="admin">admin</option>
              </select>
            </div>
            <div className="grid gap-2">
              <Label>Type CONFIRM</Label>
              <Input name="confirm" placeholder="CONFIRM" className="h-11 bg-white/5" />
            </div>
            <Button type="submit" className="h-11">
              Fix
            </Button>
          </form>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-5">
          <div className="text-sm font-semibold">Assign shop owner</div>
          <form action={assignShopOwner} className="mt-4 grid gap-3">
            <div className="grid gap-2">
              <Label>Shop ID</Label>
              <Input name="shop_id" placeholder="uuid" className="h-11 bg-white/5" />
            </div>
            <div className="grid gap-2">
              <Label>Owner profile ID</Label>
              <Input name="owner_profile_id" placeholder="uuid" className="h-11 bg-white/5" />
            </div>
            <div className="grid gap-2">
              <Label>Type CONFIRM</Label>
              <Input name="confirm" placeholder="CONFIRM" className="h-11 bg-white/5" />
            </div>
            <Button type="submit" className="h-11">
              Assign
            </Button>
          </form>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-5">
          <div className="text-sm font-semibold">Assign barber to shop</div>
          <form action={assignBarberToShop} className="mt-4 grid gap-3">
            <div className="grid gap-2">
              <Label>Barber ID</Label>
              <Input name="barber_id" placeholder="uuid" className="h-11 bg-white/5" />
            </div>
            <div className="grid gap-2">
              <Label>Shop ID</Label>
              <Input name="shop_id" placeholder="uuid" className="h-11 bg-white/5" />
            </div>
            <div className="grid gap-2">
              <Label>Type CONFIRM</Label>
              <Input name="confirm" placeholder="CONFIRM" className="h-11 bg-white/5" />
            </div>
            <Button type="submit" className="h-11">
              Assign
            </Button>
          </form>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-5">
          <div className="text-sm font-semibold">Mark barber independent</div>
          <form action={markBarberIndependent} className="mt-4 grid gap-3">
            <div className="grid gap-2">
              <Label>Barber ID</Label>
              <Input name="barber_id" placeholder="uuid" className="h-11 bg-white/5" />
            </div>
            <div className="grid gap-2">
              <Label>Type CONFIRM</Label>
              <Input name="confirm" placeholder="CONFIRM" className="h-11 bg-white/5" />
            </div>
            <Button type="submit" className="h-11">
              Mark independent
            </Button>
          </form>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-5">
          <div className="text-sm font-semibold">Fix branch integrity</div>
          <div className="pt-2 text-xs text-muted-foreground">Creates missing Main branches and fills barber.branch_id when barber.shop_id is set.</div>
          <div className="mt-3 space-y-1 text-sm text-muted-foreground">
            <div>Shops missing branches: {shopsMissingBranches.length}</div>
            <div>Barbers missing branch_id: {barbersMissingBranch.length}</div>
          </div>
          <div className="mt-3 grid gap-3 md:grid-cols-2">
            <div className="rounded-lg border border-white/10 bg-white/5 p-3 font-mono text-[11px] text-muted-foreground">
              {(shopsMissingBranches ?? []).slice(0, 10).map((s) => String((s as { id?: unknown }).id ?? "")).join("\n") || "No issues found."}
            </div>
            <div className="rounded-lg border border-white/10 bg-white/5 p-3 font-mono text-[11px] text-muted-foreground">
              {(barbersMissingBranch ?? []).slice(0, 10).map((b) => String((b as { id?: unknown }).id ?? "")).join("\n") || "No issues found."}
            </div>
          </div>
          <form action={fixBranchIntegrityAll} className="mt-4 grid gap-3">
            <label className="flex items-center gap-2 text-xs text-muted-foreground">
              <input type="checkbox" name="dry_run" value="1" />
              Dry-run (log only)
            </label>
            <div className="grid gap-2">
              <Label>Type CONFIRM</Label>
              <Input name="confirm" placeholder="CONFIRM" className="h-11 bg-white/5" />
            </div>
            <Button type="submit" className="h-11" variant="secondary">
              Fix branch integrity
            </Button>
          </form>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-5">
          <div className="text-sm font-semibold">Fix service visibility</div>
          <div className="pt-2 text-xs text-muted-foreground">Approves active undeleted shop/barber services that still have empty status, so they become visible in client apps.</div>
          <div className="mt-3 space-y-1 text-sm text-muted-foreground">
            <div>Services hidden by empty status: {servicesMissingVisibilityStatus.length}</div>
          </div>
          <div className="mt-3 rounded-lg border border-white/10 bg-white/5 p-3 font-mono text-[11px] text-muted-foreground">
            {(servicesMissingVisibilityStatus ?? []).slice(0, 10).map((s) => String((s as { id?: unknown }).id ?? "")).join("\n") || "No issues found."}
          </div>
          <form action={fixServiceVisibilityAll} className="mt-4 grid gap-3">
            <label className="flex items-center gap-2 text-xs text-muted-foreground">
              <input type="checkbox" name="dry_run" value="1" />
              Dry-run (log only)
            </label>
            <div className="grid gap-2">
              <Label>Type CONFIRM</Label>
              <Input name="confirm" placeholder="CONFIRM" className="h-11 bg-white/5" />
            </div>
            <Button type="submit" className="h-11" variant="secondary">
              Fix service visibility
            </Button>
          </form>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-5">
          <div className="text-sm font-semibold">Deactivate broken service</div>
          <form action={deactivateService} className="mt-4 grid gap-3">
            <div className="grid gap-2">
              <Label>Service ID</Label>
              <Input name="service_id" placeholder="uuid" className="h-11 bg-white/5" />
            </div>
            <div className="grid gap-2">
              <Label>Type CONFIRM</Label>
              <Input name="confirm" placeholder="CONFIRM" className="h-11 bg-white/5" />
            </div>
            <Button type="submit" className="h-11">
              Deactivate
            </Button>
          </form>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-5">
          <div className="text-sm font-semibold">Hide broken reel</div>
          <form action={hideReel} className="mt-4 grid gap-3">
            <div className="grid gap-2">
              <Label>Reel ID</Label>
              <Input name="reel_id" placeholder="uuid" className="h-11 bg-white/5" />
            </div>
            <div className="grid gap-2">
              <Label>Type CONFIRM</Label>
              <Input name="confirm" placeholder="CONFIRM" className="h-11 bg-white/5" />
            </div>
            <Button type="submit" className="h-11">
              Hide
            </Button>
          </form>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-5">
          <div className="text-sm font-semibold">Rebuild counters</div>
          <div className="pt-2 text-xs text-muted-foreground">Recomputes ratings aggregates (admin RPC).</div>
          <form action={rebuildCounters} className="mt-4 grid gap-3">
            <div className="grid gap-2">
              <Label>Type CONFIRM</Label>
              <Input name="confirm" placeholder="CONFIRM" className="h-11 bg-white/5" />
            </div>
            <Button type="submit" className="h-11">
              Run
            </Button>
          </form>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-5">
          <div className="text-sm font-semibold">Refresh cached data</div>
          <div className="pt-2 text-xs text-muted-foreground">Warms availability cache for barbers.</div>
          <form action={refreshCachedData} className="mt-4 grid gap-3">
            <div className="grid gap-2">
              <Label>Type CONFIRM</Label>
              <Input name="confirm" placeholder="CONFIRM" className="h-11 bg-white/5" />
            </div>
            <Button type="submit" className="h-11">
              Run
            </Button>
          </form>
        </LuxuryCard>
      </div>
    </PageFrame>
  );
}

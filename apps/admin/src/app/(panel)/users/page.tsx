import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getT } from "@hallaq/ui/translations-server";

import { PageFrame } from "@/components/page-frame";
import { logAdminSyncError } from "@/lib/admin-sync-logging";
import { normalizeManagedProfileRole, promoteProfileToShopOwner } from "@/lib/profile-role-sync";
import { barberHasBookings, deleteShopMemberships, upsertShopMembership } from "@/lib/shop-memberships";

export const dynamic = "force-dynamic";

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return null;
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as an admin account.";
  }
  if (m === "use_assign_owner") return "To make a user a shop owner, assign them to a shop (or create a new shop) using the “Assign owner” column.";
  if (m === "use_assign_barber") return "To make a user a barber, assign them to a shop/branch or mark them independent using the “Assign barber” column.";
  if (m === "shop_required") return "Please select a shop (or choose “Create new shop”).";
  if (m === "new_shop_name_required") return "Please enter a name for the new shop.";
  if (m === "branch_required") return "Please select a branch (or choose Independent).";
  if (m === "user_is_shop_owner") return "This user is already a shop owner. Reassign their shop ownership before assigning them as a barber.";
  if (m === "shop_owner_has_shop") return "This user owns a shop. Transfer shop ownership before changing their role away from shop_owner.";
  if (m === "barber_has_bookings" || m === "BOOKING_BARBER_IMMUTABLE") {
    return "This barber already has bookings or booking history, so the barber link cannot be removed or converted to owner/customer.";
  }
  return m;
}

export default async function UsersPage({
  searchParams
}: {
  searchParams?: Promise<{ q?: string; role?: string; error?: string }>;
}) {
  const t = await getT();
  const params = searchParams ? await searchParams : undefined;
  const q = (params?.q ?? "").trim();
  const role = (params?.role ?? "").trim();
  const errorParam = (params?.error ?? "").trim();
  const pageError = userFacingDbError(errorParam);

  const supabase = await createSupabaseServerClient();

  async function updateRole(formData: FormData) {
    "use server";

    const userId = String(formData.get("userId") ?? "").trim();
    const nextRole = String(formData.get("role") ?? "").trim();
    const redirectTo = String(formData.get("redirectTo") ?? "/users").trim() || "/users";

    if (!userId) redirect(redirectTo);
    if (!["customer", "barber", "shop_owner", "admin"].includes(nextRole)) redirect(redirectTo);

    const supabase = await createSupabaseServerClient();
    const { data: current, error: currentError } = await supabase
      .from("profiles")
      .select("id, full_name, email, role")
      .eq("id", userId)
      .maybeSingle();
    if (currentError || !current) redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent(currentError?.message ?? "user_not_found")}`);

    if (nextRole === String(current.role ?? "").trim()) redirect(redirectTo);
    if (nextRole === "shop_owner") redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent("use_assign_owner")}`);
    if (nextRole === "barber") redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent("use_assign_barber")}`);

    const admin = await createSupabaseAdminClient();

    if (String(current.role ?? "").trim() === "barber") {
      if (await barberHasBookings(admin, userId)) {
        redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent("barber_has_bookings")}`);
      }
      await deleteShopMemberships(admin, { profileId: userId, membershipRole: "barber" });
      const { error: barberDeleteError } = await admin.from("barbers").delete().eq("profile_id", userId);
      if (barberDeleteError) redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent(barberDeleteError.message)}`);
    }

    if (String(current.role ?? "").trim() === "shop_owner") {
      const { data: ownedShop } = await admin.from("barbershops").select("id").eq("owner_profile_id", userId).limit(1).maybeSingle();
      if (ownedShop?.id) redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent("shop_owner_has_shop")}`);
    }

    if (nextRole === "customer") {
      try {
        await normalizeManagedProfileRole(admin, userId);
      } catch (e) {
        const message = e instanceof Error ? e.message : "role_sync_failed";
        await logAdminSyncError(admin, {
          page: redirectTo,
          action: "bulk_update_user_role_sync",
          error: message,
          meta: { user_id: userId, requested_role: nextRole }
        });
        redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent(message)}`);
      }
    } else {
      const { error: roleError } = await admin.from("profiles").update({ role: nextRole }).eq("id", userId);
      if (roleError) redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent(roleError.message)}`);
    }

    redirect(redirectTo);
  }

  async function assignOwner(formData: FormData) {
    "use server";

    const userId = String(formData.get("userId") ?? "").trim();
    const shopId = String(formData.get("shopId") ?? "").trim();
    const shopName = String(formData.get("shopName") ?? "").trim();
    const redirectTo = String(formData.get("redirectTo") ?? "/users").trim() || "/users";

    if (!userId) redirect(redirectTo);

    const admin = await createSupabaseAdminClient();

    if (await barberHasBookings(admin, userId)) {
      redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent("barber_has_bookings")}`);
    }
    await deleteShopMemberships(admin, { profileId: userId, membershipRole: "barber" });
    const { error: barberDeleteError } = await admin.from("barbers").delete().eq("profile_id", userId);
    if (barberDeleteError) redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent(barberDeleteError.message)}`);

    if (!shopId) redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent("shop_required")}`);

    const shopChoice = shopId;
    let finalShopId: string | null = null;

    if (shopChoice === "__new__") {
      const { data: current } = await admin.from("profiles").select("full_name, email").eq("id", userId).maybeSingle();
      const fullName = String((current as { full_name?: unknown })?.full_name ?? "").trim();
      const email = String((current as { email?: unknown })?.email ?? "").trim();
      const resolvedShopName = shopName || fullName || email || userId;
      if (!resolvedShopName) redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent("new_shop_name_required")}`);

      const { data: shop, error: shopError } = await admin
        .from("barbershops")
        .insert({ owner_profile_id: userId, name: resolvedShopName })
        .select("id")
        .single();
      if (shopError) redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent(shopError.message)}`);
      finalShopId = String((shop as { id?: unknown })?.id ?? "").trim() || null;
      if (!finalShopId) redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent("shop_insert_failed")}`);
    } else {
      finalShopId = shopChoice;
      const { error: assignError } = await admin.from("barbershops").update({ owner_profile_id: userId }).eq("id", finalShopId);
      if (assignError) redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent(assignError.message)}`);
    }

    if (finalShopId) {
      try {
        await promoteProfileToShopOwner(admin, userId);
        await upsertShopMembership(admin, { profileId: userId, shopId: finalShopId, membershipRole: "owner" });
      } catch (e) {
        const message = e instanceof Error ? e.message : "membership_sync_failed";
        await logAdminSyncError(admin, {
          page: redirectTo,
          action: "bulk_assign_owner_sync",
          error: message,
          meta: { user_id: userId, shop_id: finalShopId }
        });
        redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent(message)}`);
      }
    }

    redirect(redirectTo);
  }

  async function assignBarber(formData: FormData) {
    "use server";

    const userId = String(formData.get("userId") ?? "").trim();
    const shopBranch = String(formData.get("shopBranch") ?? "").trim();
    const redirectTo = String(formData.get("redirectTo") ?? "/users").trim() || "/users";

    if (!userId) redirect(redirectTo);

    const supabase = await createSupabaseServerClient();
    const { data: current, error: currentError } = await supabase
      .from("profiles")
      .select("id, full_name, email")
      .eq("id", userId)
      .maybeSingle();
    if (currentError || !current) redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent(currentError?.message ?? "user_not_found")}`);

    const fullName = String(current.full_name ?? "").trim();
    const email = String(current.email ?? "").trim();

    const admin = await createSupabaseAdminClient();

    const { data: ownedShop } = await admin.from("barbershops").select("id").eq("owner_profile_id", userId).limit(1).maybeSingle();
    if (ownedShop?.id) redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent("user_is_shop_owner")}`);

    const { error: roleError } = await admin.from("profiles").update({ role: "barber" }).eq("id", userId);
    if (roleError) redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent(roleError.message)}`);

    const [shopId, branchId] = shopBranch ? shopBranch.split(":") : ["", ""];
    const resolvedShopId = (shopId ?? "").trim();
    const resolvedBranchId = (branchId ?? "").trim();

    let finalBranchId = resolvedBranchId;

    if (resolvedShopId && !finalBranchId) redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent("branch_required")}`);
    if (resolvedShopId && finalBranchId === "__create__") {
      const { data: createdBranch, error: branchError } = await admin
        .from("shop_branches")
        .insert({ shop_id: resolvedShopId, name: "Main Branch" })
        .select("id")
        .single();
      if (branchError) redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent(branchError.message)}`);
      finalBranchId = String((createdBranch as { id?: unknown })?.id ?? "").trim();
      if (!finalBranchId) redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent("branch_insert_failed")}`);
    }

    const { error: barberUpsertError } = await admin.from("barbers").upsert(
      {
        profile_id: userId,
        display_name: fullName || email,
        is_independent: !resolvedShopId,
        shop_id: resolvedShopId || null,
        branch_id: resolvedShopId ? finalBranchId : null
      },
      { onConflict: "profile_id" }
    );
    if (barberUpsertError) redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent(barberUpsertError.message)}`);

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
        page: redirectTo,
        action: "bulk_assign_barber_sync",
        error: message,
        meta: { user_id: userId, shop_id: resolvedShopId || null, branch_id: finalBranchId || null }
      });
      redirect(`${redirectTo}${redirectTo.includes("?") ? "&" : "?"}error=${encodeURIComponent(message)}`);
    }

    redirect(redirectTo);
  }

  let query = supabase
    .from("profiles")
    .select("*", { count: "exact" })
    .order("created_at", { ascending: false })
    .limit(50);

  if (q) query = query.or(`full_name.ilike.%${q}%,email.ilike.%${q}%,phone.ilike.%${q}%`);
  if (role) query = query.eq("role", role);

  const { data: rows, count, error } = await query;
  const profileIds = rows?.map((r) => r.id).filter(Boolean) ?? [];

  const { data: shops } = await supabase
    .from("barbershops")
    .select("id, name")
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(200);

  const { data: branches } = await supabase
    .from("shop_branches")
    .select("id, name, shop_id")
    .order("created_at", { ascending: true })
    .limit(800);

  const { data: barberLinks } = profileIds.length
    ? await supabase
        .from("barbers")
        .select("profile_id, is_independent, shop_id, branch_id, barbershops(name), shop_branches(name)")
        .in("profile_id", profileIds)
        .limit(500)
    : { data: [] as unknown[] };

  const { data: ownerLinks } = profileIds.length
    ? await supabase
        .from("barbershops")
        .select("id, name, owner_profile_id")
        .in("owner_profile_id", profileIds)
        .order("created_at", { ascending: false })
        .limit(500)
    : { data: [] as unknown[] };

  const barberLinkByProfileId = new Map<
    string,
    { isIndependent: boolean; shopName: string | null; branchName: string | null }
  >();
  for (const item of barberLinks ?? []) {
    const row = item as {
      profile_id?: unknown;
      is_independent?: unknown;
      barbershops?: { name?: unknown } | { name?: unknown }[] | null;
      shop_branches?: { name?: unknown } | { name?: unknown }[] | null;
    };
    const profileId = String(row.profile_id ?? "").trim();
    if (!profileId) continue;
    const shopSource = Array.isArray(row.barbershops) ? row.barbershops[0] : row.barbershops;
    const branchSource = Array.isArray(row.shop_branches) ? row.shop_branches[0] : row.shop_branches;
    barberLinkByProfileId.set(profileId, {
      isIndependent: Boolean(row.is_independent),
      shopName: typeof shopSource?.name === "string" ? shopSource.name : null,
      branchName: typeof branchSource?.name === "string" ? branchSource.name : null
    });
  }

  const ownerShopsByProfileId = new Map<string, string[]>();
  for (const item of ownerLinks ?? []) {
    const row = item as { owner_profile_id?: unknown; name?: unknown };
    const profileId = String(row.owner_profile_id ?? "").trim();
    const shopName = String(row.name ?? "").trim();
    if (!profileId || !shopName) continue;
    ownerShopsByProfileId.set(profileId, [...(ownerShopsByProfileId.get(profileId) ?? []), shopName]);
  }

  const authContactById = new Map<string, { email: string | null; phone: string | null }>();
  if (!error && profileIds.length) {
    try {
      const admin = await createSupabaseAdminClient();
      await Promise.all(
        (rows ?? []).map(async (r) => {
          const id = r.id as string;
          const email = (r.email ?? "").trim();
          const phone = (r.phone ?? "").trim();
          if (email && phone) return;
          const { data } = await admin.auth.admin.getUserById(id);
          const u = data.user;
          if (!u) return;
          authContactById.set(id, { email: u.email ?? null, phone: u.phone ?? null });
        })
      );
    } catch {}
  }

  return (
    <PageFrame
      title={t("admin.nav.users")}
      subtitle="Search, review roles, and inspect booking history."
      actions={
        <div className="flex items-center gap-2">
          <Button asChild variant="ghost" size="sm">
            <Link href="/users/new">Create user</Link>
          </Button>
          <Button asChild variant="secondary" size="sm">
            <Link href="/users">Refresh</Link>
          </Button>
        </div>
      }
    >
      <div className="flex flex-col gap-4">
        {pageError ? (
          <LuxuryCard className="border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{pageError}</LuxuryCard>
        ) : null}
        <form className="flex flex-col gap-3 md:flex-row md:items-center">
          <Input
            name="q"
            placeholder="Search users by name…"
            defaultValue={q}
            className="h-11 bg-white/5"
          />
          <Input
            name="role"
            placeholder="Role: admin, customer, barber…"
            defaultValue={role}
            className="h-11 bg-white/5 md:max-w-[260px]"
          />
          <Button type="submit" className="h-11 md:w-auto">
            Search
          </Button>
        </form>

        <LuxuryCard className="overflow-hidden">
          <div className="flex items-center justify-between gap-4 border-b border-white/10 px-4 py-3">
            <div className="text-sm font-medium">
              Latest users <span className="text-muted-foreground">({count ?? rows?.length ?? 0})</span>
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full min-w-[820px] text-sm">
              <thead className="text-xs text-muted-foreground">
                <tr className="border-b border-white/10">
                  <th className="px-4 py-3 text-left font-medium">Name</th>
                  <th className="px-4 py-3 text-left font-medium">Role</th>
                  <th className="px-4 py-3 text-left font-medium">Assign owner (shop dashboard)</th>
                  <th className="px-4 py-3 text-left font-medium">Assign barber (barber dashboard)</th>
                  <th className="px-4 py-3 text-left font-medium">Status</th>
                  <th className="px-4 py-3 text-left font-medium">Shop details</th>
                  <th className="px-4 py-3 text-left font-medium">Email</th>
                  <th className="px-4 py-3 text-left font-medium">Phone</th>
                  <th className="px-4 py-3 text-left font-medium">Area</th>
                  <th className="px-4 py-3 text-right font-medium">User ID</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/10">
                {error ? (
                  <tr>
                    <td colSpan={10} className="px-4 py-10 text-center text-muted-foreground">
                      {error.message}
                    </td>
                  </tr>
                ) : rows?.length ? (
                  rows.map((r) => (
                    <tr key={r.id} className="hover:bg-white/5">
                      {(() => {
                        const emailValue = String(r.email ?? authContactById.get(r.id)?.email ?? "").trim();
                        const phoneValue = String(r.phone ?? authContactById.get(r.id)?.phone ?? "").trim();
                        const barberLink = barberLinkByProfileId.get(r.id);
                        const ownerShops = ownerShopsByProfileId.get(r.id) ?? [];
                        const redirectParams = new URLSearchParams({
                          ...(q ? { q } : {}),
                          ...(role ? { role } : {})
                        }).toString();
                        const redirectTo = redirectParams ? `/users?${redirectParams}` : "/users";
                        return (
                          <>
                      <td className="px-4 py-3 font-medium">
                        <Link href={`/users/${r.id}`} className="underline-offset-4 hover:underline">
                          {r.full_name ?? "-"}
                        </Link>
                      </td>
                      <td className="px-4 py-3">
                        <form action={updateRole} className="flex items-center gap-2">
                          <input type="hidden" name="userId" value={r.id} />
                          <input type="hidden" name="redirectTo" value={redirectTo} />
                          <select
                            name="role"
                            defaultValue={r.role ?? "customer"}
                            className="flex h-9 w-[150px] rounded-md border border-input bg-white/5 px-2 py-1 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
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
                          <Button type="submit" variant="secondary" size="sm">
                            Save
                          </Button>
                        </form>
                      </td>
                      <td className="px-4 py-3">
                        <form action={assignOwner} className="flex items-center gap-2">
                          <input type="hidden" name="userId" value={r.id} />
                          <input type="hidden" name="redirectTo" value={redirectTo} />
                          <select
                            name="shopId"
                            defaultValue=""
                            className="flex h-9 w-[220px] rounded-md border border-input bg-white/5 px-2 py-1 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
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
                            className="h-9 w-[220px] bg-white/5"
                          />
                          <Button type="submit" variant="ghost" size="sm">
                            Assign
                          </Button>
                        </form>
                      </td>
                      <td className="px-4 py-3">
                        <form action={assignBarber} className="flex items-center gap-2">
                          <input type="hidden" name="userId" value={r.id} />
                          <input type="hidden" name="redirectTo" value={redirectTo} />
                          <select
                            name="shopBranch"
                            defaultValue=""
                            className="flex h-9 w-[220px] rounded-md border border-input bg-white/5 px-2 py-1 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
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
                          <Button type="submit" variant="ghost" size="sm">
                            Assign
                          </Button>
                        </form>
                      </td>
                      <td className="px-4 py-3 text-muted-foreground">{r.status ?? "-"}</td>
                      <td className="px-4 py-3 text-muted-foreground">
                        <div className="flex flex-col gap-1">
                          {ownerShops.length ? (
                            <div className="text-xs">
                              Owner: {ownerShops.join(", ")}
                            </div>
                          ) : null}
                          {barberLink ? (
                            <div className="text-xs">
                              {barberLink.isIndependent
                                ? "Barber: Independent"
                                : `Barber: ${barberLink.shopName ?? "Shop"}${barberLink.branchName ? ` / ${barberLink.branchName}` : ""}`}
                            </div>
                          ) : null}
                          {!ownerShops.length && !barberLink ? <div>-</div> : null}
                        </div>
                      </td>
                      <td className="px-4 py-3 text-muted-foreground">
                        {emailValue || "-"}
                      </td>
                      <td className="px-4 py-3 text-muted-foreground">
                        {phoneValue || "-"}
                      </td>
                      <td className="px-4 py-3 text-muted-foreground">{r.area ?? "-"}</td>
                      <td className="px-4 py-3 text-right font-mono text-xs text-muted-foreground">
                        {r.id}
                      </td>
                          </>
                        );
                      })()}
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan={10} className="px-4 py-10 text-center text-muted-foreground">
                      No users found.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </LuxuryCard>
      </div>
    </PageFrame>
  );
}

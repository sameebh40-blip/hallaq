import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type ProfileRow = {
  id: string;
  full_name: string | null;
  email: string | null;
  role: string | null;
  status: string | null;
  area: string | null;
  created_at: string | null;
};

type BarberRow = {
  id: string;
  profile_id: string;
  shop_id: string | null;
  branch_id: string | null;
  is_independent: boolean | null;
};

type ShopRow = {
  id: string;
  name: string | null;
  owner_profile_id: string;
};

type BranchRow = {
  id: string;
  shop_id: string;
  name: string | null;
};

type StaffRow = {
  profile_id: string;
  shop_id: string;
  branch_id: string;
  staff_role: string;
};

type MembershipRow = {
  profile_id: string;
  shop_id: string;
  branch_id: string;
  membership_role: string;
};

function isMissingMembershipsRelation(message: string) {
  const value = (message ?? "").toLowerCase();
  return (
    value.includes("shop_memberships") &&
    (value.includes("does not exist") || value.includes("schema cache") || value.includes("could not find the table"))
  );
}

export default async function ConnectionsAuditPage({
  searchParams
}: {
  searchParams?: Promise<{ q?: string; error?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const q = (params?.q ?? "").trim();
  const error = (params?.error ?? "").trim() || null;

  const supabase = await createSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();
  if (!user) redirect("/auth/sign-in?next=/admin/connections-audit");

  const { data: myProfile } = await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle();
  if (myProfile?.role !== "admin") redirect("/");

  const admin = await createSupabaseAdminClient();

  let profilesQuery = admin
    .from("profiles")
    .select("id, full_name, email, role, status, area, created_at")
    .order("created_at", { ascending: false })
    .limit(200);
  if (q) profilesQuery = profilesQuery.or(`full_name.ilike.%${q}%,email.ilike.%${q}%,phone.ilike.%${q}%`);

  const { data: profilesRaw, error: profilesError } = await profilesQuery;
  if (profilesError) redirect(`/admin/connections-audit?error=${encodeURIComponent(profilesError.message)}`);

  const profiles = (profilesRaw ?? []) as ProfileRow[];
  const profileIds = profiles.map((p) => p.id);

  const [
    { data: barbersRaw },
    { data: shopsRaw },
    { data: branchesRaw },
    { data: staffRaw }
  ] = await Promise.all([
    profileIds.length ? admin.from("barbers").select("id, profile_id, shop_id, branch_id, is_independent").in("profile_id", profileIds) : { data: [] as BarberRow[] },
    profileIds.length ? admin.from("barbershops").select("id, name, owner_profile_id").in("owner_profile_id", profileIds) : { data: [] as ShopRow[] },
    admin.from("shop_branches").select("id, shop_id, name").limit(5000),
    profileIds.length ? admin.from("shop_staff").select("profile_id, shop_id, branch_id, staff_role").in("profile_id", profileIds) : { data: [] as StaffRow[] }
  ]);

  let memberships: MembershipRow[] | null = null;
  try {
    if (profileIds.length) {
      const { data: membershipsRaw, error: membershipsError } = await admin
        .from("shop_memberships")
        .select("profile_id, shop_id, branch_id, membership_role")
        .in("profile_id", profileIds);
      if (membershipsError) {
        if (!isMissingMembershipsRelation(membershipsError.message)) throw membershipsError;
      } else {
        memberships = (membershipsRaw ?? []) as MembershipRow[];
      }
    }
  } catch (e) {
    const message = e instanceof Error ? e.message : "Failed to load memberships";
    redirect(`/admin/connections-audit?error=${encodeURIComponent(message)}`);
  }

  const barbers = (barbersRaw ?? []) as BarberRow[];
  const shops = (shopsRaw ?? []) as ShopRow[];
  const branches = (branchesRaw ?? []) as BranchRow[];
  const staff = (staffRaw ?? []) as StaffRow[];

  const barberIds = barbers.map((b) => b.id);
  const ownedShopIds = shops.map((s) => s.id);
  const [{ data: barberBookingsRaw }, { data: shopBookingsRaw }] = await Promise.all([
    barberIds.length ? admin.from("bookings").select("barber_id").in("barber_id", barberIds).limit(10000) : { data: [] as { barber_id: string | null }[] },
    ownedShopIds.length ? admin.from("bookings").select("shop_id").in("shop_id", ownedShopIds).limit(10000) : { data: [] as { shop_id: string | null }[] }
  ]);

  const branchNameById = new Map(branches.map((b) => [b.id, b.name ?? b.id]));
  const shopNameById = new Map(shops.map((s) => [s.id, s.name ?? s.id]));
  const barberByProfileId = new Map(barbers.map((b) => [b.profile_id, b]));
  const shopsByOwnerId = new Map<string, ShopRow[]>();
  const staffByProfileId = new Map<string, StaffRow[]>();
  const membershipsByProfileId = new Map<string, MembershipRow[]>();
  const barberBookingCountByBarberId = new Map<string, number>();
  const shopBookingCountByShopId = new Map<string, number>();

  for (const shop of shops) {
    shopsByOwnerId.set(shop.owner_profile_id, [...(shopsByOwnerId.get(shop.owner_profile_id) ?? []), shop]);
  }
  for (const item of staff) {
    staffByProfileId.set(item.profile_id, [...(staffByProfileId.get(item.profile_id) ?? []), item]);
  }
  for (const item of memberships ?? []) {
    membershipsByProfileId.set(item.profile_id, [...(membershipsByProfileId.get(item.profile_id) ?? []), item]);
  }
  for (const item of barberBookingsRaw ?? []) {
    const barberId = String((item as { barber_id?: unknown }).barber_id ?? "").trim();
    if (!barberId) continue;
    barberBookingCountByBarberId.set(barberId, (barberBookingCountByBarberId.get(barberId) ?? 0) + 1);
  }
  for (const item of shopBookingsRaw ?? []) {
    const shopId = String((item as { shop_id?: unknown }).shop_id ?? "").trim();
    if (!shopId) continue;
    shopBookingCountByShopId.set(shopId, (shopBookingCountByShopId.get(shopId) ?? 0) + 1);
  }

  const rows = profiles.map((profile) => {
    const barber = barberByProfileId.get(profile.id) ?? null;
    const ownedShops = shopsByOwnerId.get(profile.id) ?? [];
    const staffLinks = staffByProfileId.get(profile.id) ?? [];
    const membershipLinks = membershipsByProfileId.get(profile.id) ?? [];
    const barberBookingCount = barber ? barberBookingCountByBarberId.get(barber.id) ?? 0 : 0;
    const ownedShopBookingCount = ownedShops.reduce((sum, shop) => sum + (shopBookingCountByShopId.get(shop.id) ?? 0), 0);

    const warnings: string[] = [];
    if (profile.role === "barber" && !barber) warnings.push("role=barber but barber row is missing");
    if (profile.role === "shop_owner" && ownedShops.length === 0) warnings.push("role=shop_owner but no shop is owned");
    if (barber && profile.role !== "barber") warnings.push("barber row exists but profile role is not barber");
    if (ownedShops.length > 0 && profile.role !== "shop_owner") warnings.push("owns shop but profile role is not shop_owner");
    if (ownedShops.length > 0 && barber) warnings.push("user is both barber and shop owner");
    if (barber?.shop_id && !barber.branch_id) warnings.push("barber has shop_id but no branch_id");
    if (memberships !== null) {
      if (ownedShops.length > 0 && !membershipLinks.some((m) => m.membership_role === "owner")) warnings.push("owner membership missing");
      if (barber?.shop_id && !membershipLinks.some((m) => m.membership_role === "barber")) warnings.push("barber membership missing");
      if (staffLinks.length > 0 && !membershipLinks.some((m) => m.membership_role === "receptionist")) warnings.push("receptionist membership missing");
    }
    if (barberBookingCount > 0) warnings.push(`barber has ${barberBookingCount} booking(s)`);

    return {
      profile,
      barber,
      ownedShops,
      staffLinks,
      membershipLinks,
      barberBookingCount,
      ownedShopBookingCount,
      warnings
    };
  });

  const warningRows = rows.filter((row) => row.warnings.length > 0);
  const barberMismatchCount = rows.filter((row) => row.profile.role === "barber" && !row.barber).length;
  const ownerMismatchCount = rows.filter((row) => row.profile.role === "shop_owner" && row.ownedShops.length === 0).length;
  const dualConflictCount = rows.filter((row) => row.barber && row.ownedShops.length > 0).length;
  const membershipMissingCount = rows.filter((row) => row.warnings.some((w) => w.includes("membership"))).length;

  return (
    <PageFrame
      title="Connections audit"
      subtitle="Review user role, shop, barber, branch, membership, and booking relationships in one place."
      actions={
        <div className="flex items-center gap-2">
          <Button asChild variant="ghost" size="sm">
            <Link href="/admin/connections-audit">Refresh</Link>
          </Button>
          <Button asChild variant="secondary" size="sm">
            <Link href="/data-repair">Open Data Repair</Link>
          </Button>
        </div>
      }
    >
      <div className="flex flex-col gap-4">
        {error ? <LuxuryCard className="border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard> : null}

        <form className="flex flex-col gap-3 md:flex-row md:items-center">
          <input
            name="q"
            defaultValue={q}
            placeholder="Search by name / email / phone"
            className="flex h-11 w-full rounded-md border border-input bg-white/5 px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
          />
          <Button type="submit" className="h-11 md:w-auto">
            Search
          </Button>
        </form>

        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
          <LuxuryCard className="p-4">
            <div className="text-xs text-muted-foreground">Rows with warnings</div>
            <div className="pt-2 text-2xl font-semibold">{warningRows.length}</div>
          </LuxuryCard>
          <LuxuryCard className="p-4">
            <div className="text-xs text-muted-foreground">Barber mismatches</div>
            <div className="pt-2 text-2xl font-semibold">{barberMismatchCount}</div>
          </LuxuryCard>
          <LuxuryCard className="p-4">
            <div className="text-xs text-muted-foreground">Owner mismatches</div>
            <div className="pt-2 text-2xl font-semibold">{ownerMismatchCount}</div>
          </LuxuryCard>
          <LuxuryCard className="p-4">
            <div className="text-xs text-muted-foreground">Missing memberships</div>
            <div className="pt-2 text-2xl font-semibold">{membershipMissingCount}</div>
          </LuxuryCard>
        </div>

        <LuxuryCard className="p-4 text-sm text-muted-foreground">
          <div>Dual barber/shop-owner conflicts: {dualConflictCount}</div>
          <div>Membership table available: {memberships === null ? "No (fallback mode)" : "Yes"}</div>
        </LuxuryCard>

        <LuxuryCard className="overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[1400px] text-sm">
              <thead className="text-xs text-muted-foreground">
                <tr className="border-b border-white/10">
                  <th className="px-4 py-3 text-left font-medium">User</th>
                  <th className="px-4 py-3 text-left font-medium">Role</th>
                  <th className="px-4 py-3 text-left font-medium">Barber link</th>
                  <th className="px-4 py-3 text-left font-medium">Owner shops</th>
                  <th className="px-4 py-3 text-left font-medium">Staff</th>
                  <th className="px-4 py-3 text-left font-medium">Memberships</th>
                  <th className="px-4 py-3 text-left font-medium">Bookings</th>
                  <th className="px-4 py-3 text-left font-medium">Warnings</th>
                  <th className="px-4 py-3 text-right font-medium">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/10">
                {rows.length ? (
                  rows.map((row) => {
                    const barberShopName = row.barber?.shop_id ? shopNameById.get(row.barber.shop_id) ?? row.barber.shop_id : null;
                    const barberBranchName = row.barber?.branch_id ? branchNameById.get(row.barber.branch_id) ?? row.barber.branch_id : null;
                    return (
                      <tr key={row.profile.id} className="hover:bg-white/5">
                        <td className="px-4 py-3">
                          <div className="font-medium">{row.profile.full_name ?? "-"}</div>
                          <div className="text-xs text-muted-foreground">{row.profile.email ?? row.profile.id}</div>
                        </td>
                        <td className="px-4 py-3 text-muted-foreground">
                          <div>{row.profile.role ?? "-"}</div>
                          <div className="text-xs">{row.profile.status ?? "-"}</div>
                        </td>
                        <td className="px-4 py-3 text-muted-foreground">
                          {row.barber ? (
                            <div className="flex flex-col gap-1">
                              <div>{row.barber.is_independent ? "Independent" : barberShopName ?? "Shop assigned"}</div>
                              <div className="text-xs">{barberBranchName ?? (row.barber.shop_id ? "Missing branch" : "No branch")}</div>
                            </div>
                          ) : (
                            "-"
                          )}
                        </td>
                        <td className="px-4 py-3 text-muted-foreground">
                          {row.ownedShops.length ? (
                            <div className="flex flex-col gap-1">
                              {row.ownedShops.map((shop) => (
                                <Link key={shop.id} href={`/stores/${shop.id}`} className="underline-offset-4 hover:underline">
                                  {shop.name ?? shop.id}
                                </Link>
                              ))}
                            </div>
                          ) : (
                            "-"
                          )}
                        </td>
                        <td className="px-4 py-3 text-muted-foreground">
                          {row.staffLinks.length ? (
                            <div className="flex flex-col gap-1">
                              {row.staffLinks.map((item, index) => (
                                <div key={`${item.profile_id}-${item.branch_id}-${index}`} className="text-xs">
                                  {item.staff_role}: {shopNameById.get(item.shop_id) ?? item.shop_id} / {branchNameById.get(item.branch_id) ?? item.branch_id}
                                </div>
                              ))}
                            </div>
                          ) : (
                            "-"
                          )}
                        </td>
                        <td className="px-4 py-3 text-muted-foreground">
                          {memberships === null ? (
                            <span className="text-xs">Fallback mode</span>
                          ) : row.membershipLinks.length ? (
                            <div className="flex flex-col gap-1">
                              {row.membershipLinks.map((item, index) => (
                                <div key={`${item.profile_id}-${item.shop_id}-${item.branch_id}-${item.membership_role}-${index}`} className="text-xs">
                                  {item.membership_role}: {shopNameById.get(item.shop_id) ?? item.shop_id} / {branchNameById.get(item.branch_id) ?? item.branch_id}
                                </div>
                              ))}
                            </div>
                          ) : (
                            "-"
                          )}
                        </td>
                        <td className="px-4 py-3 text-muted-foreground">
                          <div>Barber: {row.barberBookingCount}</div>
                          <div className="text-xs">Owned shops: {row.ownedShopBookingCount}</div>
                        </td>
                        <td className="px-4 py-3">
                          {row.warnings.length ? (
                            <div className="flex flex-col gap-1 text-xs text-amber-200">
                              {row.warnings.map((warning) => (
                                <div key={warning}>{warning}</div>
                              ))}
                            </div>
                          ) : (
                            <span className="text-xs text-emerald-200">OK</span>
                          )}
                        </td>
                        <td className="px-4 py-3 text-right">
                          <Button asChild size="sm" variant="secondary">
                            <Link href={`/users/${row.profile.id}`}>Open user</Link>
                          </Button>
                        </td>
                      </tr>
                    );
                  })
                ) : (
                  <tr>
                    <td colSpan={9} className="px-4 py-10 text-center text-muted-foreground">
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

import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";
import { promoteProfileToShopOwner } from "@/lib/profile-role-sync";
import { upsertShopMembership } from "@/lib/shop-memberships";

export const dynamic = "force-dynamic";

type ProfileRow = { id: string; full_name: string | null; email: string | null; role: string | null };
type BarberRow = { id: string; profile_id: string; shop_id: string | null };
type ShopRow = { id: string; name: string | null; owner_profile_id: string };

export default async function RoleRelationshipAuditPage({ searchParams }: { searchParams?: Promise<{ error?: string }> }) {
  const params = searchParams ? await searchParams : undefined;
  const error = (params?.error ?? "").trim() || null;

  const supabase = await createSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();
  if (!user) redirect("/auth/sign-in?next=/admin/role-relationship-audit");

  const { data: myProfile } = await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle();
  if (myProfile?.role !== "admin") redirect("/");

  const admin = await createSupabaseAdminClient();

  async function fixBarberRole(formData: FormData) {
    "use server";

    const profileId = String(formData.get("profileId") ?? "").trim();
    if (!profileId) redirect("/admin/role-relationship-audit");

    const admin = await createSupabaseAdminClient();
    const { error: updateError } = await admin.from("profiles").update({ role: "barber" }).eq("id", profileId);
    if (updateError) redirect(`/admin/role-relationship-audit?error=${encodeURIComponent(updateError.message)}`);

    redirect("/admin/role-relationship-audit");
  }

  async function reconnectBarberRow(formData: FormData) {
    "use server";

    const profileId = String(formData.get("profileId") ?? "").trim();
    const displayName = String(formData.get("displayName") ?? "").trim();
    if (!profileId) redirect("/admin/role-relationship-audit");

    const admin = await createSupabaseAdminClient();
    const { error: upsertError } = await admin.from("barbers").upsert(
      {
        profile_id: profileId,
        display_name: displayName || profileId,
        is_independent: true
      },
      { onConflict: "profile_id" }
    );
    if (upsertError) redirect(`/admin/role-relationship-audit?error=${encodeURIComponent(upsertError.message)}`);

    redirect("/admin/role-relationship-audit");
  }

  async function createOwnedShop(formData: FormData) {
    "use server";

    const profileId = String(formData.get("profileId") ?? "").trim();
    const name = String(formData.get("name") ?? "").trim();
    if (!profileId) redirect("/admin/role-relationship-audit");

    const admin = await createSupabaseAdminClient();
    const { data: createdShop, error: insertError } = await admin
      .from("barbershops")
      .insert({ owner_profile_id: profileId, name: name || "Shop" })
      .select("id")
      .single();
    if (insertError) redirect(`/admin/role-relationship-audit?error=${encodeURIComponent(insertError.message)}`);

    const shopId = String((createdShop as { id?: unknown } | null)?.id ?? "").trim();
    if (shopId) {
      await promoteProfileToShopOwner(admin, profileId);
      await upsertShopMembership(admin, { profileId, shopId, membershipRole: "owner" });
    }

    redirect("/admin/role-relationship-audit");
  }

  async function reassignShopOwner(formData: FormData) {
    "use server";

    const shopId = String(formData.get("shopId") ?? "").trim();
    const ownerProfileId = String(formData.get("ownerProfileId") ?? "").trim();
    if (!shopId || !ownerProfileId) redirect("/admin/role-relationship-audit");

    const admin = await createSupabaseAdminClient();
    const { error: updateError } = await admin.from("barbershops").update({ owner_profile_id: ownerProfileId }).eq("id", shopId);
    if (updateError) redirect(`/admin/role-relationship-audit?error=${encodeURIComponent(updateError.message)}`);

    await promoteProfileToShopOwner(admin, ownerProfileId);
    await upsertShopMembership(admin, { profileId: ownerProfileId, shopId, membershipRole: "owner" });

    redirect("/admin/role-relationship-audit");
  }

  const [
    { data: profilesBarberRole },
    { data: profilesShopOwnerRole },
    { data: profilesShopOwnerCandidates },
    { data: barbers },
    { data: shops }
  ] = await Promise.all([
    admin.from("profiles").select("id, full_name, email, role").eq("role", "barber").limit(2000),
    admin.from("profiles").select("id, full_name, email, role").eq("role", "shop_owner").limit(2000),
    admin.from("profiles").select("id, full_name, email, role").eq("role", "shop_owner").limit(2000),
    admin.from("barbers").select("id, profile_id, shop_id").limit(5000),
    admin.from("barbershops").select("id, name, owner_profile_id").is("deleted_at", null).limit(5000)
  ]);

  const barberByProfileId = new Map((barbers ?? []).map((b) => [String((b as BarberRow).profile_id), b as BarberRow]));
  const shopsByOwnerProfileId = new Map<string, ShopRow[]>();
  for (const s of shops ?? []) {
    const shop = s as ShopRow;
    const owner = String(shop.owner_profile_id);
    const arr = shopsByOwnerProfileId.get(owner) ?? [];
    arr.push(shop);
    shopsByOwnerProfileId.set(owner, arr);
  }

  const barberRoleNoBarberRow = (profilesBarberRole ?? []).filter((p) => !barberByProfileId.has(String((p as ProfileRow).id)));
  const shopOwnerRoleNoShop = (profilesShopOwnerRole ?? []).filter((p) => !(shopsByOwnerProfileId.get(String((p as ProfileRow).id)) ?? []).length);
  const shopOwnerAlsoBarber = (profilesShopOwnerRole ?? []).filter((p) => barberByProfileId.has(String((p as ProfileRow).id)));

  const shopsOwnerIsBarber = (shops ?? []).filter((s) => barberByProfileId.has(String((s as ShopRow).owner_profile_id))) as ShopRow[];

  const shopOwnerCandidates = (profilesShopOwnerCandidates ?? []) as ProfileRow[];

  return (
    <PageFrame
      title="Role & relationship audit"
      subtitle="Detect and repair barber/shop_owner mix-ups."
      actions={
        <div className="flex items-center gap-2">
          <Button asChild variant="ghost" size="sm">
            <Link href="/admin/connections-audit">Connections Audit</Link>
          </Button>
          <Button asChild variant="secondary" size="sm">
            <a href="/admin/role-relationship-audit">Refresh</a>
          </Button>
        </div>
      }
    >
      <div className="flex flex-col gap-4">
        {error ? (
          <LuxuryCard className="p-4 text-sm text-red-200">{error}</LuxuryCard>
        ) : null}

        <LuxuryCard className="p-4">
          <div className="text-sm font-medium">Summary</div>
          <div className="mt-2 grid gap-2 text-sm text-muted-foreground md:grid-cols-2">
            <div>role=barber but no barber row: {barberRoleNoBarberRow.length}</div>
            <div>role=shop_owner but no owned shop: {shopOwnerRoleNoShop.length}</div>
            <div>role=shop_owner but also has barber row: {shopOwnerAlsoBarber.length}</div>
            <div>shops whose owner is a barber: {shopsOwnerIsBarber.length}</div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="overflow-hidden">
          <div className="border-b border-white/10 px-4 py-3 text-sm font-medium">role=barber but no barber row</div>
          <div className="overflow-x-auto">
            <table className="w-full min-w-[900px] text-sm">
              <thead className="text-xs text-muted-foreground">
                <tr className="border-b border-white/10">
                  <th className="px-4 py-3 text-left font-medium">Name</th>
                  <th className="px-4 py-3 text-left font-medium">Email</th>
                  <th className="px-4 py-3 text-left font-medium">Repair</th>
                  <th className="px-4 py-3 text-right font-medium">Profile ID</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/10">
                {barberRoleNoBarberRow.length ? (
                  barberRoleNoBarberRow.slice(0, 50).map((row) => {
                    const p = row as ProfileRow;
                    return (
                      <tr key={p.id} className="hover:bg-white/5">
                        <td className="px-4 py-3">{p.full_name ?? "-"}</td>
                        <td className="px-4 py-3 text-muted-foreground">{p.email ?? "-"}</td>
                        <td className="px-4 py-3">
                          <form action={reconnectBarberRow} className="flex items-center gap-2">
                            <input type="hidden" name="profileId" value={p.id} />
                            <input type="hidden" name="displayName" value={p.full_name ?? p.email ?? ""} />
                            <Button type="submit" size="sm" variant="secondary">
                              Reconnect Barber Row
                            </Button>
                          </form>
                        </td>
                        <td className="px-4 py-3 text-right font-mono text-xs text-muted-foreground">{p.id}</td>
                      </tr>
                    );
                  })
                ) : (
                  <tr>
                    <td colSpan={4} className="px-4 py-10 text-center text-muted-foreground">
                      No issues found.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </LuxuryCard>

        <LuxuryCard className="overflow-hidden">
          <div className="border-b border-white/10 px-4 py-3 text-sm font-medium">role=shop_owner but no owned shop</div>
          <div className="overflow-x-auto">
            <table className="w-full min-w-[900px] text-sm">
              <thead className="text-xs text-muted-foreground">
                <tr className="border-b border-white/10">
                  <th className="px-4 py-3 text-left font-medium">Name</th>
                  <th className="px-4 py-3 text-left font-medium">Email</th>
                  <th className="px-4 py-3 text-left font-medium">Repair</th>
                  <th className="px-4 py-3 text-right font-medium">Profile ID</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/10">
                {shopOwnerRoleNoShop.length ? (
                  shopOwnerRoleNoShop.slice(0, 50).map((row) => {
                    const p = row as ProfileRow;
                    return (
                      <tr key={p.id} className="hover:bg-white/5">
                        <td className="px-4 py-3">{p.full_name ?? "-"}</td>
                        <td className="px-4 py-3 text-muted-foreground">{p.email ?? "-"}</td>
                        <td className="px-4 py-3">
                          <form action={createOwnedShop} className="flex items-center gap-2">
                            <input type="hidden" name="profileId" value={p.id} />
                            <input type="hidden" name="name" value={p.full_name ?? p.email ?? "Shop"} />
                            <Button type="submit" size="sm" variant="secondary">
                              Create Owned Shop
                            </Button>
                          </form>
                        </td>
                        <td className="px-4 py-3 text-right font-mono text-xs text-muted-foreground">{p.id}</td>
                      </tr>
                    );
                  })
                ) : (
                  <tr>
                    <td colSpan={4} className="px-4 py-10 text-center text-muted-foreground">
                      No issues found.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </LuxuryCard>

        <LuxuryCard className="overflow-hidden">
          <div className="border-b border-white/10 px-4 py-3 text-sm font-medium">shops where owner is a barber (wrong ownership)</div>
          <div className="overflow-x-auto">
            <table className="w-full min-w-[1100px] text-sm">
              <thead className="text-xs text-muted-foreground">
                <tr className="border-b border-white/10">
                  <th className="px-4 py-3 text-left font-medium">Shop</th>
                  <th className="px-4 py-3 text-left font-medium">Current owner profile</th>
                  <th className="px-4 py-3 text-left font-medium">Reassign owner</th>
                  <th className="px-4 py-3 text-left font-medium">Fix owner role</th>
                  <th className="px-4 py-3 text-right font-medium">Shop ID</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/10">
                {shopsOwnerIsBarber.length ? (
                  shopsOwnerIsBarber.slice(0, 50).map((shop) => {
                    const currentOwner = String(shop.owner_profile_id);
                    return (
                      <tr key={shop.id} className="hover:bg-white/5">
                        <td className="px-4 py-3">{shop.name ?? "-"}</td>
                        <td className="px-4 py-3 font-mono text-xs text-muted-foreground">{currentOwner}</td>
                        <td className="px-4 py-3">
                          <form action={reassignShopOwner} className="flex items-center gap-2">
                            <input type="hidden" name="shopId" value={shop.id} />
                            <select
                              name="ownerProfileId"
                              defaultValue=""
                              className="flex h-9 w-[260px] rounded-md border border-input bg-white/5 px-2 py-1 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
                            >
                              <option value="">Select shop_owner…</option>
                              {shopOwnerCandidates.map((p) => (
                                <option key={p.id} value={p.id}>
                                  {p.full_name ?? p.email ?? p.id}
                                </option>
                              ))}
                            </select>
                            <Button type="submit" size="sm" variant="secondary">
                              Assign Correct Owner
                            </Button>
                          </form>
                        </td>
                        <td className="px-4 py-3">
                          <form action={fixBarberRole}>
                            <input type="hidden" name="profileId" value={currentOwner} />
                            <Button type="submit" size="sm" variant="ghost">
                              Fix Barber Role
                            </Button>
                          </form>
                        </td>
                        <td className="px-4 py-3 text-right font-mono text-xs text-muted-foreground">{shop.id}</td>
                      </tr>
                    );
                  })
                ) : (
                  <tr>
                    <td colSpan={5} className="px-4 py-10 text-center text-muted-foreground">
                      No issues found.
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

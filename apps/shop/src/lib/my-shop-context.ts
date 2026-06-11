import type { SupabaseClient } from "@supabase/supabase-js";

import { getMyPrimaryShopMembership } from "@hallaq/supabase/memberships";
import { getMyProfile } from "@hallaq/supabase/profile";

type ShopSummary = { id: string; name: string | null; area: string | null; status: string | null; owner_profile_id: string | null };
type BranchSummary = { id: string; name: string; area: string | null };

export type ShopContext = {
  role: string;
  shop: ShopSummary | null;
  branch: BranchSummary | null;
  staff_role: string | null;
};

export async function getMyShopContext(supabase: SupabaseClient): Promise<ShopContext> {
  const profile = await getMyProfile(supabase);
  if (!profile) return { role: "anonymous", shop: null, branch: null, staff_role: null };

  try {
    if (profile.role === "shop_owner") {
      const membership = await getMyPrimaryShopMembership(supabase, ["owner"]);
      if (membership) {
        return {
          role: profile.role,
          shop: membership.barbershops ?? null,
          branch: membership.shop_branches ?? null,
          staff_role: null
        };
      }
    }

    if (profile.role === "receptionist") {
      const membership = await getMyPrimaryShopMembership(supabase, ["receptionist"]);
      if (membership) {
        return {
          role: profile.role,
          shop: membership.barbershops ?? null,
          branch: membership.shop_branches ?? null,
          staff_role: membership.membership_role
        };
      }
    }
  } catch {}

  if (profile.role === "shop_owner") {
    const { data: shop } = await supabase
      .from("barbershops")
      .select("id, name, area, status, owner_profile_id")
      .eq("owner_profile_id", profile.id)
      .order("created_at", { ascending: false })
      .maybeSingle();

    if (!shop) return { role: profile.role, shop: null, branch: null, staff_role: null };

    const { data: branch } = await supabase
      .from("shop_branches")
      .select("id, name, area")
      .eq("shop_id", shop.id)
      .order("created_at", { ascending: true })
      .maybeSingle();

    return { role: profile.role, shop: shop as unknown as ShopSummary, branch: (branch as unknown as BranchSummary) ?? null, staff_role: null };
  }

  if (profile.role === "receptionist") {
    const { data: staff } = await supabase
      .from("shop_staff")
      .select("staff_role, shop_id, branch_id, shop_branches(id, name, area), barbershops(id, name, area, status, owner_profile_id)")
      .eq("profile_id", profile.id)
      .eq("staff_role", "receptionist")
      .order("created_at", { ascending: false })
      .maybeSingle();

    const row = staff as unknown as { staff_role: string; barbershops: ShopSummary | null; shop_branches: BranchSummary | null } | null;
    const shop = row?.barbershops ?? null;
    const branch = row?.shop_branches ?? null;

    return { role: profile.role, shop, branch, staff_role: row?.staff_role ?? null };
  }

  return { role: profile.role, shop: null, branch: null, staff_role: null };
}

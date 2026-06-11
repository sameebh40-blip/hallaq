import type { SupabaseClient } from "@supabase/supabase-js";

export type ShopMembershipRole = "owner" | "barber" | "receptionist";

export type ShopMembership = {
  id: string;
  profile_id: string;
  shop_id: string;
  branch_id: string;
  membership_role: ShopMembershipRole;
  is_primary: boolean;
  barbershops: {
    id: string;
    name: string | null;
    area: string | null;
    status: string | null;
    owner_profile_id: string | null;
  } | null;
  shop_branches: {
    id: string;
    name: string;
    area: string | null;
  } | null;
};

function isMissingMembershipsRelation(message: string) {
  const value = (message ?? "").toLowerCase();
  return (
    value.includes("shop_memberships") &&
    (value.includes("does not exist") || value.includes("schema cache") || value.includes("could not find the table"))
  );
}

export async function getMyShopMemberships(supabase: SupabaseClient, roles?: ShopMembershipRole[]) {
  const {
    data: { user },
    error: userError
  } = await supabase.auth.getUser();
  if (userError) throw userError;
  if (!user) return [];

  let query = supabase
    .from("shop_memberships")
    .select(
      "id, profile_id, shop_id, branch_id, membership_role, is_primary, barbershops(id, name, area, status, owner_profile_id), shop_branches(id, name, area)"
    )
    .eq("profile_id", user.id)
    .order("is_primary", { ascending: false })
    .order("created_at", { ascending: true });

  if (roles?.length) query = query.in("membership_role", roles);

  const { data, error } = await query;
  if (error) {
    if (isMissingMembershipsRelation(error.message)) return [];
    throw error;
  }

  return (data ?? []) as unknown as ShopMembership[];
}

export async function getMyPrimaryShopMembership(supabase: SupabaseClient, roles?: ShopMembershipRole[]) {
  const rows = await getMyShopMemberships(supabase, roles);
  return rows[0] ?? null;
}

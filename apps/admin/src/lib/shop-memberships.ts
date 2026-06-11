import type { SupabaseClient } from "@supabase/supabase-js";

type MembershipRole = "owner" | "barber" | "receptionist";

function isMissingRelationError(message: string) {
  const value = (message ?? "").toLowerCase();
  return (
    value.includes("shop_memberships") &&
    (value.includes("does not exist") || value.includes("schema cache") || value.includes("could not find the table"))
  );
}

export async function barberHasBookings(admin: SupabaseClient, profileId: string) {
  const { data: barber, error: barberError } = await admin.from("barbers").select("id").eq("profile_id", profileId).maybeSingle();
  if (barberError) throw new Error(barberError.message);
  const barberId = String((barber as { id?: unknown } | null)?.id ?? "").trim();
  if (!barberId) return false;

  const { data: bookings, error: bookingsError } = await admin.from("bookings").select("id").eq("barber_id", barberId).limit(1);
  if (bookingsError) throw new Error(bookingsError.message);
  return (bookings?.length ?? 0) > 0;
}

export async function getOrCreatePrimaryBranchId(admin: SupabaseClient, shopId: string) {
  const normalizedShopId = String(shopId ?? "").trim();
  if (!normalizedShopId) return null;

  const { data: existingBranch, error: existingBranchError } = await admin
    .from("shop_branches")
    .select("id")
    .eq("shop_id", normalizedShopId)
    .order("created_at", { ascending: true })
    .maybeSingle();
  if (existingBranchError) throw new Error(existingBranchError.message);

  const existingId = String((existingBranch as { id?: unknown } | null)?.id ?? "").trim();
  if (existingId) return existingId;

  const { data: createdBranch, error: branchError } = await admin
    .from("shop_branches")
    .insert({ shop_id: normalizedShopId, name: "Main Branch" })
    .select("id")
    .single();
  if (branchError) throw new Error(branchError.message);

  return String((createdBranch as { id?: unknown })?.id ?? "").trim() || null;
}

export async function upsertShopMembership(
  admin: SupabaseClient,
  params: { profileId: string; shopId: string; branchId?: string | null; membershipRole: MembershipRole }
) {
  const profileId = String(params.profileId ?? "").trim();
  const shopId = String(params.shopId ?? "").trim();
  if (!profileId || !shopId) return null;

  const resolvedBranchId = String(params.branchId ?? "").trim() || (await getOrCreatePrimaryBranchId(admin, shopId));
  if (!resolvedBranchId) return null;

  const { error } = await admin.from("shop_memberships").upsert(
    {
      profile_id: profileId,
      shop_id: shopId,
      branch_id: resolvedBranchId,
      membership_role: params.membershipRole,
      is_primary: true
    },
    { onConflict: "profile_id,shop_id,branch_id,membership_role" }
  );

  if (error) {
    if (isMissingRelationError(error.message)) return resolvedBranchId;
    throw new Error(error.message);
  }

  return resolvedBranchId;
}

export async function deleteShopMemberships(
  admin: SupabaseClient,
  params: { profileId: string; membershipRole?: MembershipRole; shopId?: string | null }
) {
  const profileId = String(params.profileId ?? "").trim();
  if (!profileId) return;

  let query = admin.from("shop_memberships").delete().eq("profile_id", profileId);
  if (params.membershipRole) query = query.eq("membership_role", params.membershipRole);
  if (params.shopId) query = query.eq("shop_id", params.shopId);

  const { error } = await query;
  if (error && !isMissingRelationError(error.message)) throw new Error(error.message);
}

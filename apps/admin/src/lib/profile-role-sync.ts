import type { SupabaseClient } from "@supabase/supabase-js";

type ManagedRole = "customer" | "barber" | "shop_owner";
type EffectiveRole = ManagedRole | "admin";

export function resolveManagedProfileRole(params: { currentRole?: string | null; ownsShop: boolean; hasBarberRecord: boolean }): EffectiveRole {
  const currentRole = String(params.currentRole ?? "").trim();
  if (currentRole === "admin") return "admin";
  if (params.ownsShop) return "shop_owner";
  if (params.hasBarberRecord) return "barber";
  return "customer";
}

async function setManagedProfileRole(admin: SupabaseClient, profileId: string, role: ManagedRole) {
  const normalizedProfileId = String(profileId ?? "").trim();
  if (!normalizedProfileId) return role;

  const { error } = await admin.from("profiles").update({ role }).eq("id", normalizedProfileId);
  if (error) throw new Error(error.message);
  return role;
}

export async function promoteProfileToShopOwner(admin: SupabaseClient, profileId: string) {
  return setManagedProfileRole(admin, profileId, "shop_owner");
}

export async function normalizeManagedProfileRole(admin: SupabaseClient, profileId: string) {
  const normalizedProfileId = String(profileId ?? "").trim();
  if (!normalizedProfileId) return "customer" as const;

  const { data: profile, error: profileError } = await admin.from("profiles").select("role").eq("id", normalizedProfileId).maybeSingle();
  if (profileError) throw new Error(profileError.message);

  const currentRole = String((profile as { role?: unknown } | null)?.role ?? "").trim();
  if (currentRole === "admin") return "admin" as const;

  const [{ data: ownedShop, error: ownedShopError }, { data: barber, error: barberError }] = await Promise.all([
    admin.from("barbershops").select("id").eq("owner_profile_id", normalizedProfileId).limit(1).maybeSingle(),
    admin.from("barbers").select("id").eq("profile_id", normalizedProfileId).limit(1).maybeSingle()
  ]);
  if (ownedShopError) throw new Error(ownedShopError.message);
  if (barberError) throw new Error(barberError.message);

  const nextRole = resolveManagedProfileRole({
    currentRole,
    ownsShop: Boolean(ownedShop?.id),
    hasBarberRecord: Boolean(barber?.id)
  });
  if (nextRole === "admin") return nextRole;
  if (nextRole === currentRole) return nextRole;

  return setManagedProfileRole(admin, normalizedProfileId, nextRole);
}

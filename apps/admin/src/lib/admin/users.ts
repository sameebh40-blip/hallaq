import { createSupabaseAdminClient } from "@hallaq/supabase/admin";

import { upsertShopMembership } from "@/lib/shop-memberships";

export type CreateUserRole = "customer" | "barber" | "shop_owner" | "admin";

export async function createAuthUserWithProfile(input: {
  email: string;
  password: string;
  fullName: string;
  phone?: string;
  role: CreateUserRole;
}) {
  const email = input.email.trim().toLowerCase();
  const password = input.password;
  const fullName = input.fullName.trim();
  const phone = (input.phone ?? "").trim();
  const role = input.role;

  if (!email || !password || !fullName) {
    throw new Error("Missing required fields.");
  }

  const admin = await createSupabaseAdminClient();

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName }
  });

  if (createError) throw new Error(createError.message);

  const userId = created.user?.id ?? "";
  if (!userId) throw new Error("Failed to create user.");

  const { error: profileError } = await admin.from("profiles").upsert({
    id: userId,
    email,
    full_name: fullName,
    phone: phone || null,
    role,
    status: "active",
    must_change_password: true
  });

  if (profileError) throw new Error(profileError.message);

  if (role === "barber") {
    const { error: barberError } = await admin.from("barbers").upsert(
      {
        profile_id: userId,
        display_name: fullName,
        area: null,
        is_independent: true
      },
      { onConflict: "profile_id" }
    );
    if (barberError) throw new Error(barberError.message);
  }

  if (role === "shop_owner") {
    const { data: existingShop, error: existingShopError } = await admin
      .from("barbershops")
      .select("id")
      .eq("owner_profile_id", userId)
      .maybeSingle();
    if (existingShopError) throw new Error(existingShopError.message);
    if (!existingShop?.id) {
      const { data: createdShop, error: shopError } = await admin
        .from("barbershops")
        .insert({
        owner_profile_id: userId,
        name: fullName
        })
        .select("id")
        .single();
      if (shopError) throw new Error(shopError.message);
      const shopId = String((createdShop as { id?: unknown } | null)?.id ?? "").trim();
      if (shopId) await upsertShopMembership(admin, { profileId: userId, shopId, membershipRole: "owner" });
    } else {
      await upsertShopMembership(admin, { profileId: userId, shopId: existingShop.id, membershipRole: "owner" });
    }
  }

  return { userId };
}

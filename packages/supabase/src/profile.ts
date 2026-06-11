import type { SupabaseClient } from "@supabase/supabase-js";

export type ProfileRole = "customer" | "barber" | "shop_owner" | "admin" | "receptionist";

export type Profile = {
  id: string;
  full_name: string | null;
  role: ProfileRole;
  phone: string | null;
  avatar_url: string | null;
};

export async function getMyProfile(supabase: SupabaseClient) {
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError) throw userError;
  if (!userData.user) return null;

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("id, full_name, role, phone, avatar_url")
    .eq("id", userData.user.id)
    .maybeSingle();

  if (profileError) throw profileError;
  if (!profile) return null;
  return profile as Profile;
}

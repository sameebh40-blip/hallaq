import type { SupabaseClient } from "@supabase/supabase-js";

import { getMyProfile } from "@hallaq/supabase/profile";

export type MyShop = {
  id: string;
  owner_profile_id: string;
  name: string;
  description: string | null;
  area: string | null;
  address: string | null;
  google_maps_url: string | null;
  lat: number | null;
  lng: number | null;
  opening_hours: Record<string, string> | null;
  home_service: boolean;
  phone: string | null;
  whatsapp: string | null;
  instagram: string | null;
  status: string;
  is_featured: boolean;
  is_verified: boolean;
  created_at: string;
};

export async function getMyShop(supabase: SupabaseClient) {
  const profile = await getMyProfile(supabase);
  if (!profile) return null;

  const { data } = await supabase
    .from("barbershops")
    .select(
      "id, owner_profile_id, name, description, area, address, google_maps_url, lat, lng, opening_hours, home_service, phone, whatsapp, instagram, status, is_featured, is_verified, created_at"
    )
    .eq("owner_profile_id", profile.id)
    .order("created_at", { ascending: false })
    .maybeSingle();

  return (data as MyShop | null) ?? null;
}

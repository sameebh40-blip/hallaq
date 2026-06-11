import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";

import { PageFrame } from "@/components/page-frame";
import { RealtimeRefresh } from "@/components/realtime-refresh";

import { ShopBarberMapClient } from "./shop-barber-map-client";

export const dynamic = "force-dynamic";

type ShopRow = {
  id: string;
  name: string | null;
  area: string | null;
  status: string | null;
  is_active: boolean | null;
};

type BarberRow = {
  id: string;
  display_name: string | null;
  shop_id: string | null;
  is_independent: boolean | null;
  status: string | null;
  is_active: boolean | null;
};

export default async function ShopBarberMapPage() {
  const supabase = await createSupabaseServerClient();

  const { data: shops, error: shopsError } = await supabase
    .from("barbershops")
    .select("id, name, area, status, is_active")
    .order("created_at", { ascending: false })
    .limit(500);

  if (shopsError) {
    return (
      <PageFrame title="Shop ↔ Barber Map" subtitle="Assign barbers to shops.">
        <div className="text-sm text-muted-foreground">{shopsError.message}</div>
      </PageFrame>
    );
  }

  const { data: barbers, error: barbersError } = await supabase
    .from("barbers")
    .select("id, display_name, shop_id, is_independent, status, is_active")
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(2000);

  if (barbersError) {
    return (
      <PageFrame title="Shop ↔ Barber Map" subtitle="Assign barbers to shops.">
        <div className="text-sm text-muted-foreground">{barbersError.message}</div>
      </PageFrame>
    );
  }

  async function assignBarber(formData: FormData) {
    "use server";

    const barberId = String(formData.get("barber_id") ?? "").trim();
    const shopId = String(formData.get("shop_id") ?? "").trim();
    if (!barberId || !shopId) redirect("/shop-barber-map");

    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("barbers").update({ shop_id: shopId, is_independent: false }).eq("id", barberId);
    if (error) redirect(`/shop-barber-map?error=${encodeURIComponent(error.message)}`);
    redirect("/shop-barber-map");
  }

  async function removeBarber(formData: FormData) {
    "use server";

    const barberId = String(formData.get("barber_id") ?? "").trim();
    if (!barberId) redirect("/shop-barber-map");

    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("barbers").update({ shop_id: null, is_independent: true }).eq("id", barberId);
    if (error) redirect(`/shop-barber-map?error=${encodeURIComponent(error.message)}`);
    redirect("/shop-barber-map");
  }

  async function setIndependent(formData: FormData) {
    "use server";

    const barberId = String(formData.get("barber_id") ?? "").trim();
    const value = String(formData.get("is_independent") ?? "").trim();
    if (!barberId) redirect("/shop-barber-map");

    const isIndependent = value === "1";
    const supabase = await createSupabaseServerClient();
    const updates: Record<string, unknown> = { is_independent: isIndependent };
    if (isIndependent) updates.shop_id = null;
    const { error } = await supabase.from("barbers").update(updates).eq("id", barberId);
    if (error) redirect(`/shop-barber-map?error=${encodeURIComponent(error.message)}`);
    redirect("/shop-barber-map");
  }

  return (
    <PageFrame title="Shop ↔ Barber Map" subtitle="Assign barbers to shops.">
      <RealtimeRefresh tables={["barbers", "barbershops"]} />
      <ShopBarberMapClient
        shops={(shops ?? []) as ShopRow[]}
        barbers={(barbers ?? []) as BarberRow[]}
        assignBarber={assignBarber}
        removeBarber={removeBarber}
        setIndependent={setIndependent}
      />
    </PageFrame>
  );
}

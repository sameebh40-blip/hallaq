import { redirect } from "next/navigation";

import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";
import { getMyShopContext } from "@/lib/my-shop-context";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type ServiceRow = {
  id: string;
  name_en: string | null;
  name_ar: string | null;
  price_bhd: number | null;
  duration_minutes: number | null;
};

function toIsoFromLocal(value: string) {
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString();
}

export default async function ReceptionPage({
  searchParams
}: {
  searchParams?: Promise<{ barberId?: string; error?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const selectedBarberId = (params?.barberId ?? "").trim() || null;
  const error = (params?.error ?? "").trim();

  const supabase = await createAppSupabaseServerClient();
  const ctx = await getMyShopContext(supabase);

  if (!ctx.shop || !ctx.branch) {
    return (
      <PageFrame title="Reception" subtitle="Quick booking requires a shop + branch assignment.">
        <div className="text-sm text-muted-foreground">No shop/branch assigned to this account.</div>
      </PageFrame>
    );
  }

  const { data: barbers } = await supabase
    .from("barbers")
    .select("id, display_name")
    .eq("shop_id", ctx.shop.id)
    .eq("branch_id", ctx.branch.id)
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(80);

  const barberId = selectedBarberId ?? barbers?.[0]?.id ?? null;

  const { data: services } = barberId
    ? await supabase
        .from("services")
        .select("id, name_en, name_ar, price_bhd, duration_minutes, is_active, active, deleted_at, barber_id, shop_id")
        .is("deleted_at", null)
        .eq("barber_id", barberId)
        .or("is_active.eq.true,active.eq.true")
        .order("created_at", { ascending: false })
        .limit(80)
    : { data: [] as ServiceRow[] };

  async function createReceptionBooking(formData: FormData) {
    "use server";

    const barberId = String(formData.get("barberId") ?? "").trim();
    const serviceId = String(formData.get("serviceId") ?? "").trim();
    const startAtLocal = String(formData.get("startAt") ?? "").trim();
    const customerName = String(formData.get("customerName") ?? "").trim();
    const customerPhone = String(formData.get("customerPhone") ?? "").trim();
    const notes = String(formData.get("notes") ?? "").trim() || null;

    const startAt = toIsoFromLocal(startAtLocal);
    if (!barberId || !serviceId || !startAt) redirect(`/reception?error=${encodeURIComponent("Missing barber, service, or start time")}`);

    const supabase = await createAppSupabaseServerClient();
    const ctx = await getMyShopContext(supabase);
    if (!ctx.shop || !ctx.branch) redirect(`/reception?error=${encodeURIComponent("No shop/branch assigned")}`);

    let customerProfileId: string | null = null;
    if (customerPhone) {
      const { data: existing } = await supabase.from("profiles").select("id").eq("phone", customerPhone).maybeSingle();
      customerProfileId = existing?.id ?? null;
    }

    const { error: rpcError } = await supabase.rpc("create_reception_booking", {
      service_id: serviceId,
      start_at: startAt,
      barber_id: barberId,
      shop_id: ctx.shop.id,
      branch_id: ctx.branch.id,
      customer_profile_id: customerProfileId,
      customer_name: customerProfileId ? null : customerName,
      customer_phone: customerProfileId ? null : customerPhone,
      notes
    });

    if (rpcError) redirect(`/reception?error=${encodeURIComponent(rpcError.message)}`);
    redirect("/appointments");
  }

  return (
    <PageFrame title="Reception" subtitle="Quick booking for walk-ins or existing customers.">
      {error ? (
        <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard>
      ) : null}

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <LuxuryCard className="border border-white/10 bg-white/5 p-5">
          <div className="text-sm font-semibold">Quick Booking</div>
          <div className="pt-1 text-xs text-muted-foreground">
            {ctx.shop.name ?? "Shop"} • {ctx.branch.name}
          </div>

          <form method="get" className="mt-4 grid gap-3 text-sm">
            <div className="grid gap-2">
              <Label htmlFor="barberId">Barber</Label>
              <select id="barberId" name="barberId" className="h-11 rounded-lg border border-white/10 bg-white/5 px-3" defaultValue={barberId ?? ""}>
                {(barbers ?? []).map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.display_name ?? b.id}
                  </option>
                ))}
              </select>
            </div>
            <Button type="submit" variant="secondary" className="h-11">
              Load services
            </Button>
          </form>

          <form action={createReceptionBooking} className="mt-4 grid gap-3 text-sm">
            <input type="hidden" name="barberId" value={barberId ?? ""} />

            <div className="grid gap-2">
              <Label htmlFor="serviceId">Service</Label>
              <select id="serviceId" name="serviceId" className="h-11 rounded-lg border border-white/10 bg-white/5 px-3">
                {(services ?? []).map((s) => (
                  <option key={s.id} value={s.id}>
                    {(s.name_en ?? s.name_ar ?? "Service").trim()} • BD {Number(s.price_bhd ?? 0).toFixed(3)}
                  </option>
                ))}
              </select>
            </div>

            <div className="grid gap-2">
              <Label htmlFor="startAt">Date & Time</Label>
              <Input id="startAt" name="startAt" type="datetime-local" className="h-11 bg-white/5" required />
            </div>

            <div className="grid gap-2">
              <Label htmlFor="customerName">Customer name (for guests)</Label>
              <Input id="customerName" name="customerName" className="h-11 bg-white/5" placeholder="Walk-in name" />
            </div>

            <div className="grid gap-2">
              <Label htmlFor="customerPhone">Customer phone</Label>
              <Input id="customerPhone" name="customerPhone" className="h-11 bg-white/5" placeholder="+973…" required />
            </div>

            <div className="grid gap-2">
              <Label htmlFor="notes">Notes</Label>
              <Input id="notes" name="notes" className="h-11 bg-white/5" placeholder="Optional" />
            </div>

            <Button type="submit" className="h-11">
              Create Booking
            </Button>
          </form>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-5">
          <div className="text-sm font-semibold">Branch Scope</div>
          <div className="pt-2 text-sm text-muted-foreground">
            Bookings created here are strictly scoped to branch_id and will appear in shop/barber schedules for this branch.
          </div>
        </LuxuryCard>
      </div>
    </PageFrame>
  );
}

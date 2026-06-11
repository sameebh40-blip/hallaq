import Image from "next/image";

import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { Button } from "@hallaq/ui/button";
import { getMyProfile } from "@hallaq/supabase/profile";

import { BusinessPageHeader } from "@/components/business/page-header";
import { getMyShopContext } from "@/lib/my-shop-context";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

function qrUrl(data: string, size = 240) {
  const encoded = encodeURIComponent(data);
  return `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${encoded}&margin=10`;
}

function toDateInputValue(date: Date) {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

export default async function BusinessQrPage({ searchParams }: { searchParams?: Promise<{ shopId?: string }> }) {
  const sp = searchParams ? await searchParams : undefined;
  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);
  const ctx = await getMyShopContext(supabase);
  const shopId = ctx.shop?.id ?? (profile?.role === "admin" ? (sp?.shopId ?? null) : null);
  if (!shopId) return <div className="text-sm text-muted-foreground">No shop selected.</div>;

  const { data: shop } = await supabase.from("barbershops").select("id, name").eq("id", shopId).maybeSingle();
  const { data: barbers } = await supabase.from("barbers").select("id, display_name, is_active").eq("shop_id", shopId).is("deleted_at", null).order("display_name", { ascending: true }).limit(200);

  const now = new Date();
  const to = toDateInputValue(now);
  const from = toDateInputValue(new Date(now.getFullYear(), now.getMonth(), now.getDate() - 30));

  const { data: daily } = await supabase.rpc("get_shop_qr_scans_daily", { p_shop_id: shopId, p_from: from, p_to: to });
  const { data: byBarber } = await supabase.rpc("get_shop_qr_scans_by_barber", { p_shop_id: shopId, p_from: from, p_to: to });

  const barberScanCount = new Map<string, number>();
  for (const r of (byBarber ?? []) as Array<{ barber_id: string; scans: number }>) {
    barberScanCount.set(String(r.barber_id), Number(r.scans ?? 0));
  }

  const dailyRows = (daily ?? []) as Array<{ day: string; scans: number; unique_sessions: number }>;
  const totals = dailyRows.reduce(
    (acc, r) => {
      acc.scans += Number(r.scans ?? 0);
      acc.sessions += Number(r.unique_sessions ?? 0);
      return acc;
    },
    { scans: 0, sessions: 0 }
  );

  const shopPayload = `shop:${shopId}`;

  return (
    <div className="grid gap-4">
      <BusinessPageHeader
        title="QR Center"
        subtitle="These QR codes are compatible with the in-app scanner and open the correct entity instantly."
      />

      <div className="grid gap-4 lg:grid-cols-3">
        <LuxuryCard className="p-5">
          <div className="text-sm text-muted-foreground">QR scans (30d)</div>
          <div className="pt-1 text-2xl font-semibold">{totals.scans}</div>
        </LuxuryCard>
        <LuxuryCard className="p-5">
          <div className="text-sm text-muted-foreground">Unique sessions (30d)</div>
          <div className="pt-1 text-2xl font-semibold">{totals.sessions}</div>
        </LuxuryCard>
        <LuxuryCard className="p-5">
          <div className="text-sm text-muted-foreground">Period</div>
          <div className="pt-1 text-sm font-semibold">
            {from} → {to}
          </div>
        </LuxuryCard>
      </div>

      <LuxuryCard className="overflow-hidden">
        <div className="border-b border-white/10 px-5 py-4 text-sm font-semibold">Daily scans</div>
        <div className="overflow-x-auto">
          <table className="w-full min-w-[720px] text-sm">
            <thead className="text-xs text-muted-foreground">
              <tr className="border-b border-white/10">
                <th className="px-5 py-3 text-left font-medium">Day</th>
                <th className="px-5 py-3 text-left font-medium">Scans</th>
                <th className="px-5 py-3 text-left font-medium">Unique sessions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/10">
              {dailyRows.length ? (
                dailyRows.map((r) => (
                  <tr key={r.day} className="hover:bg-white/5">
                    <td className="px-5 py-3 font-medium">{r.day}</td>
                    <td className="px-5 py-3 text-muted-foreground">{Number(r.scans ?? 0)}</td>
                    <td className="px-5 py-3 text-muted-foreground">{Number(r.unique_sessions ?? 0)}</td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={3} className="px-5 py-10 text-center text-muted-foreground">
                    No QR scans recorded yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </LuxuryCard>

      <div className="grid gap-4 lg:grid-cols-2">
        <LuxuryCard className="p-5">
          <div className="flex items-end justify-between gap-3">
            <div>
              <div className="text-sm font-semibold">Shop QR</div>
              <div className="text-xs text-muted-foreground">{shop?.name ?? "Shop"}</div>
            </div>
            <Button asChild size="sm" variant="secondary">
              <a href={qrUrl(shopPayload, 720)} target="_blank" rel="noreferrer">
                Download
              </a>
            </Button>
          </div>
          <div className="mt-4 flex items-center justify-center rounded-2xl border border-white/10 bg-white/5 p-6">
            <Image
              unoptimized
              src={qrUrl(shopPayload)}
              alt="Shop QR"
              width={240}
              height={240}
              className="h-[240px] w-[240px] rounded-xl bg-white p-2"
            />
          </div>
          <div className="mt-3 text-xs text-muted-foreground">Encoded: {shopPayload}</div>
        </LuxuryCard>

        <LuxuryCard className="p-5">
          <div className="text-sm font-semibold">Barber QRs</div>
          <div className="mt-4 grid gap-3">
            {(barbers ?? []).map((b) => {
              const payload = `barber:${b.id}`;
              return (
                <LuxuryCard key={b.id} className="grid gap-3 p-4 md:grid-cols-[120px_1fr_auto] md:items-center">
                  <Image
                    unoptimized
                    src={qrUrl(payload, 160)}
                    alt="Barber QR"
                    width={120}
                    height={120}
                    className="h-[120px] w-[120px] rounded-xl bg-white p-2"
                  />
                  <div className="min-w-0">
                    <div className="truncate text-sm font-semibold">{b.display_name ?? "Barber"}</div>
                    <div className="text-xs text-muted-foreground">{b.is_active ? "Active" : "Inactive"}</div>
                    <div className="mt-1 text-xs text-muted-foreground">Scans (30d): {barberScanCount.get(b.id) ?? 0}</div>
                    <div className="mt-1 truncate text-xs text-muted-foreground">Encoded: {payload}</div>
                  </div>
                  <Button asChild size="sm" variant="secondary">
                    <a href={qrUrl(payload, 720)} target="_blank" rel="noreferrer">
                      Download
                    </a>
                  </Button>
                </LuxuryCard>
              );
            })}
            {(barbers?.length ?? 0) === 0 ? <div className="text-sm text-muted-foreground">No barbers found.</div> : null}
          </div>
        </LuxuryCard>
      </div>
    </div>
  );
}

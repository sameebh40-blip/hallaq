import Link from "next/link";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type Status = "ok" | "warning" | "broken";

type Item = { id: string; label: string; status: Status; detail?: string };

function statusBadge(status: Status) {
  if (status === "ok") return { label: "✅ Working", cls: "border-emerald-500/25 bg-emerald-500/10 text-emerald-200" };
  if (status === "warning") return { label: "⚠ Warning", cls: "border-amber-500/25 bg-amber-500/10 text-amber-100" };
  return { label: "❌ Broken", cls: "border-rose-500/25 bg-rose-500/10 text-rose-200" };
}

export default async function ClientHealthPage() {
  const supabase = await createSupabaseServerClient();

  const [
    shopsRes,
    categoriesRes,
    searchShopsRes,
    searchBarbersRes,
    reelsRes,
    bookingsRes,
    profilesRes,
    bannersRes,
    brandDefaultsRes
  ] = await Promise.all([
    supabase.from("barbershops").select("id", { count: "exact", head: true }).eq("status", "approved").is("deleted_at", null).limit(1),
    supabase.from("categories").select("id", { count: "exact", head: true }).limit(1),
    supabase.from("barbershops").select("id").eq("status", "approved").is("deleted_at", null).limit(1),
    supabase.from("barbers").select("id").is("deleted_at", null).limit(1),
    supabase.from("reels").select("id").eq("status", "approved").is("deleted_at", null).limit(1),
    supabase.from("bookings").select("id").limit(1),
    supabase.from("profiles").select("id").limit(1),
    supabase.from("city_banners").select("id").limit(1),
    supabase
      .from("brand_assets")
      .select("key")
      .in("key", [
        "default_avatar",
        "default_barber_avatar",
        "default_shop_logo",
        "default_shop_cover",
        "default_service_image",
        "default_product_image",
        "default_reel_thumbnail"
      ])
  ]);

  const defaultKeys = new Set((brandDefaultsRes.data ?? []).map((r) => String((r as { key?: string }).key ?? "")));
  const expectedKeys = [
    "default_avatar",
    "default_barber_avatar",
    "default_shop_logo",
    "default_shop_cover",
    "default_service_image",
    "default_product_image",
    "default_reel_thumbnail"
  ];
  const missingDefaults = expectedKeys.filter((k) => !defaultKeys.has(k));

  const items: Item[] = [
    {
      id: "home",
      label: "Home loads",
      status: shopsRes.error ? "broken" : "ok",
      detail: shopsRes.error?.message ?? `${shopsRes.count ?? 0} approved shops`
    },
    {
      id: "categories",
      label: "Categories visible",
      status: categoriesRes.error ? "broken" : (categoriesRes.count ?? 0) > 0 ? "ok" : "warning",
      detail: categoriesRes.error?.message ?? `${categoriesRes.count ?? 0} categories`
    },
    {
      id: "search",
      label: "Search works",
      status: searchShopsRes.error || searchBarbersRes.error ? "broken" : "ok",
      detail: searchShopsRes.error?.message ?? searchBarbersRes.error?.message ?? "Queries OK"
    },
    {
      id: "nearby",
      label: "Nearby shops works",
      status: "warning",
      detail: "Requires geo RPC and real device location. Use system-health + customer app smoke test."
    },
    {
      id: "city",
      label: "City works",
      status: bannersRes.error ? "warning" : "ok",
      detail: bannersRes.error?.message ?? "City banners query OK"
    },
    {
      id: "discover",
      label: "Discover reels works",
      status: reelsRes.error ? "broken" : "ok",
      detail: reelsRes.error?.message ?? "Reels query OK"
    },
    {
      id: "booking",
      label: "Booking flow works",
      status: bookingsRes.error ? "broken" : "ok",
      detail: bookingsRes.error?.message ?? "Bookings table accessible"
    },
    {
      id: "profile",
      label: "Profile loads",
      status: profilesRes.error ? "broken" : "ok",
      detail: profilesRes.error?.message ?? "Profiles table accessible"
    },
    {
      id: "edit_profile",
      label: "Edit profile works",
      status: "warning",
      detail: "Requires authenticated customer session + UI flow test."
    },
    {
      id: "bottom_nav",
      label: "Bottom nav no overflow",
      status: "warning",
      detail: "Requires client UI smoke test."
    },
    {
      id: "fallback_images",
      label: "Images fallback works",
      status: missingDefaults.length ? "warning" : "ok",
      detail: missingDefaults.length ? `Missing brand_assets keys: ${missingDefaults.join(", ")}` : "Brand defaults present"
    },
    {
      id: "yellow_overlay",
      label: "No yellow overlay",
      status: "warning",
      detail: "Requires client UI smoke test."
    }
  ];

  return (
    <PageFrame
      title="Client Experience Health"
      subtitle="Live checks + required manual smoke tests. No fake data."
      actions={
        <>
          <Button asChild size="sm" variant="secondary">
            <Link href="/system-health">System Health</Link>
          </Button>
          <Button asChild size="sm" variant="secondary">
            <Link href="/branding">Branding</Link>
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        {items.map((i) => {
          const b = statusBadge(i.status);
          return (
            <LuxuryCard key={i.id} className="border border-white/10 bg-white/5 p-4">
              <div className="flex flex-col gap-2">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="text-sm font-semibold">{i.label}</div>
                  <span className={`rounded-full border px-2.5 py-1 text-xs font-semibold ${b.cls}`}>{b.label}</span>
                </div>
                {i.detail ? <div className="text-xs text-muted-foreground">{i.detail}</div> : null}
              </div>
            </LuxuryCard>
          );
        })}
      </div>
    </PageFrame>
  );
}


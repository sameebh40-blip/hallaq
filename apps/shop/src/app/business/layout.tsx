import type { ReactNode } from "react";

import { redirect } from "next/navigation";

import { getMyProfile } from "@hallaq/supabase/profile";

import { RealtimeRefresh } from "@/components/realtime-refresh";
import { BusinessMobileRedirect } from "@/components/business/mobile-redirect";
import { BusinessShell } from "@/components/business/shell";
import { getMyShopContext } from "@/lib/my-shop-context";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

async function safeCount(query: PromiseLike<{ count: number | null }>) {
  const { count } = await query;
  return typeof count === "number" ? count : 0;
}

export default async function BusinessLayout({ children }: { children: ReactNode }) {
  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);

  if (!profile) redirect("/auth/sign-in");

  if (profile.role === "barber") redirect("/barber-dashboard");
  if (profile.role === "customer") redirect("/home");
  if (profile.role === "receptionist") redirect("/reception");
  if (profile.role !== "shop_owner" && profile.role !== "admin") redirect("/home");

  const ctx = await getMyShopContext(supabase);
  const shop = ctx.shop;

  if (profile.role === "shop_owner" && !shop) {
    return (
      <main className="mx-auto flex min-h-dvh max-w-2xl flex-col justify-center gap-4 px-6 py-12">
        <div className="text-lg font-semibold">No shop assigned</div>
        <div className="text-sm text-muted-foreground">
          This account is not linked to a shop yet. Ask an admin to assign your shop owner membership.
        </div>
      </main>
    );
  }

  const { data: shopMeta } = shop
    ? await supabase
        .from("barbershops")
        .select("id, name, area, logo_url, is_verified")
        .eq("id", shop.id)
        .maybeSingle()
    : { data: null as null | { id: string; name: string | null; area: string | null; logo_url: string | null; is_verified: boolean | null } };

  const activeShop = shopMeta ?? (shop ? { id: shop.id, name: shop.name, area: shop.area, logo_url: null, is_verified: null } : null);

  const unreadNotifications = await safeCount(
    supabase
      .from("notifications")
      .select("*", { count: "exact", head: true })
      .eq("profile_id", profile.id)
      .eq("read", false)
  );

  const unreadMessages = await safeCount(
    supabase
      .from("notifications")
      .select("*", { count: "exact", head: true })
      .eq("profile_id", profile.id)
      .eq("read", false)
      .in("type", ["message", "chat", "dm"])
  );

  return (
    <>
      <BusinessMobileRedirect redirectTo="/dashboard" />
      {shop ? (
        <RealtimeRefresh
          subscriptions={[
            { table: "bookings", filter: `shop_id=eq.${shop.id}` },
            { table: "payments", filter: `payee_id=eq.${shop.id}` },
            { table: "notifications", filter: `profile_id=eq.${profile.id}` },
            { table: "barbershops", filter: `id=eq.${shop.id}` },
            { table: "services", filter: `shop_id=eq.${shop.id}` },
            { table: "barbers", filter: `shop_id=eq.${shop.id}` },
            { table: "shop_barbers", filter: `shop_id=eq.${shop.id}` },
            { table: "products", filter: `shop_id=eq.${shop.id}` },
            { table: "orders", filter: `shop_id=eq.${shop.id}` },
            { table: "reviews", filter: `shop_id=eq.${shop.id}` },
            { table: "reels", filter: `shop_id=eq.${shop.id}` },
            { table: "posts", filter: `shop_id=eq.${shop.id}` },
            { table: "offers", filter: `shop_id=eq.${shop.id}` },
          ]}
        />
      ) : (
        <RealtimeRefresh tables={["notifications"]} />
      )}
      <BusinessShell
        shop={{
          name: activeShop?.name ?? "Shop",
          logoUrl: activeShop?.logo_url ?? null,
          isVerified: Boolean(activeShop?.is_verified),
          area: activeShop?.area ?? null
        }}
        unreadNotifications={unreadNotifications}
        unreadMessages={unreadMessages}
      >
        {children}
      </BusinessShell>
    </>
  );
}

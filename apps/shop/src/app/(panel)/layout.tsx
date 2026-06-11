import type { ReactNode } from "react";

import Link from "next/link";

import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { RealtimeRefresh } from "@/components/realtime-refresh";
import { createAppSupabaseServerClient } from "@/lib/supabase";
import { getMyShopContext } from "@/lib/my-shop-context";

export default async function ShopPanelLayout({ children }: { children: ReactNode }) {
  const supabase = await createAppSupabaseServerClient();
  const ctx = await getMyShopContext(supabase);
  const shop = ctx.shop;
  const branch = ctx.branch;

  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-7xl flex-col gap-6 px-4 py-6">
      {shop ? (
        <RealtimeRefresh
          subscriptions={[
            { table: "bookings", filter: `shop_id=eq.${shop.id}` },
            { table: "notifications", filter: `profile_id=eq.${shop.owner_profile_id}` },
            { table: "barbershops", filter: `id=eq.${shop.id}` },
            { table: "services", filter: `shop_id=eq.${shop.id}` },
            { table: "barbers", filter: `shop_id=eq.${shop.id}` },
            { table: "shop_barbers", filter: `shop_id=eq.${shop.id}` },
            { table: "reels", filter: `shop_id=eq.${shop.id}` }
          ]}
        />
      ) : (
        <RealtimeRefresh tables={["bookings", "notifications", "barbershops"]} />
      )}
      <div className="flex flex-col gap-2">
        <div className="flex items-center justify-between gap-4">
          <div className="flex flex-col">
            <div className="text-xl font-semibold tracking-tight">
              {shop?.name ?? "Shop dashboard"}
            </div>
            <div className="text-sm text-muted-foreground">
              {shop ? `${shop.area ?? "Bahrain"} • ${shop.status}${branch?.name ? ` • ${branch.name}` : ""}` : "No shop assigned to this account"}
            </div>
          </div>
          <form action="/auth/sign-out" method="post">
            <Button type="submit" variant="ghost">
              Sign out
            </Button>
          </form>
        </div>

        <div className="flex flex-wrap gap-2 pt-2">
          <Button asChild variant="secondary" size="sm">
            <Link href="/dashboard">Dashboard</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/reception">Reception</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/barbers">Barbers</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/barber-requests">Barber Requests</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/appointments">Appointments</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/calendar">Calendar</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/posts">Posts</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/services">Services</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/gallery">Gallery</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/barber-portfolio">Barber Portfolio</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/reviews">Reviews</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/profile">Profile</Link>
          </Button>
        </div>
      </div>

      <LuxuryCard className="p-5">{children}</LuxuryCard>
    </main>
  );
}

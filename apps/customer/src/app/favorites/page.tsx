import Link from "next/link";
import { redirect } from "next/navigation";

import { createAppSupabaseServerClient } from "@/lib/supabase";
import { signedOrUrl } from "@hallaq/supabase/storage";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { SafeImage } from "@/components/safe-image";

export const dynamic = "force-dynamic";

type FavoriteRow = { id: string; target_type: "barber" | "shop"; target_id: string; created_at: string };
type BarberRow = { id: string; display_name: string | null; avatar_url: string | null; avatar_path: string | null };
type ShopRow = { id: string; name: string | null; logo_url: string | null; logo_path: string | null };

export default async function FavoritesPage() {
  const supabase = await createAppSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) redirect("/auth/sign-in?next=/favorites");

  const { data: favsRaw } = await supabase.from("favorites").select("id, target_type, target_id, created_at").eq("profile_id", user.id).order("created_at", { ascending: false }).limit(60);
  const favs = (favsRaw ?? []) as FavoriteRow[];

  const barberIds = favs.filter((f) => f.target_type === "barber").map((f) => f.target_id);
  const shopIds = favs.filter((f) => f.target_type === "shop").map((f) => f.target_id);

  const [{ data: barbersRaw }, { data: shopsRaw }] = await Promise.all([
    barberIds.length ? supabase.from("barbers").select("id, display_name, avatar_url, avatar_path").in("id", barberIds) : Promise.resolve({ data: [] }),
    shopIds.length ? supabase.from("barbershops").select("id, name, logo_url, logo_path").in("id", shopIds) : Promise.resolve({ data: [] })
  ]);

  const barbers = new Map<string, BarberRow>();
  for (const b of (barbersRaw ?? []) as BarberRow[]) barbers.set(b.id, b);

  const shops = new Map<string, ShopRow>();
  for (const s of (shopsRaw ?? []) as ShopRow[]) shops.set(s.id, s);

  const items = await Promise.all(
    favs.map(async (f) => {
      if (f.target_type === "barber") {
        const b = barbers.get(f.target_id);
        const avatar = await signedOrUrl(supabase, "barber-images", b?.avatar_path ?? b?.avatar_url);
        return { type: "barber" as const, id: f.target_id, name: b?.display_name ?? "Barber", image: avatar };
      }
      const s = shops.get(f.target_id);
      const logo = await signedOrUrl(supabase, "shop-images", s?.logo_path ?? s?.logo_url);
      return { type: "shop" as const, id: f.target_id, name: s?.name ?? "Shop", image: logo };
    })
  );

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 py-6 pb-28 text-white">
      <div className="flex items-center justify-between">
        <Link href="/profile" className="text-sm font-semibold text-[#9E9E9E]">
          Back
        </Link>
        <div className="text-sm font-extrabold">Favorites</div>
        <div className="w-10" />
      </div>

      {items.length ? (
        <div className="flex flex-col gap-3">
          {items.map((i) => (
            <Link
              key={`${i.type}:${i.id}`}
              href={i.type === "barber" ? `/barber/${encodeURIComponent(i.id)}` : `/shop/${encodeURIComponent(i.id)}`}
              className="flex items-center gap-3 rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-4 shadow-[0_18px_44px_rgba(0,0,0,0.55)]"
            >
              <div className="h-14 w-14 overflow-hidden rounded-[22px] border border-[#2A2A2A] bg-black">
                <SafeImage
                  src={i.image ?? null}
                  fallbackKey={i.type === "barber" ? "default_barber_avatar" : "default_shop_logo"}
                  alt={i.name}
                  className="h-full w-full object-cover"
                />
              </div>
              <div className="min-w-0 flex-1">
                <div className="truncate text-sm font-extrabold">{i.name}</div>
                <div className="pt-1 text-[12px] font-semibold text-[#9E9E9E]">{i.type === "barber" ? "Barber" : "Shop"}</div>
              </div>
              <div className="text-[hsl(var(--gold))]">›</div>
            </Link>
          ))}
        </div>
      ) : (
        <div className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-6">
          <div className="text-sm font-extrabold">No favorites yet</div>
          <div className="pt-1 text-sm font-semibold text-[#9E9E9E]">Save barbers and shops to access them quickly.</div>
        </div>
      )}

      <CustomerBottomNav />
    </main>
  );
}

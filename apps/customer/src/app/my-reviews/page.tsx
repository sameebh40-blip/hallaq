import Link from "next/link";
import { redirect } from "next/navigation";

import { createAppSupabaseServerClient } from "@/lib/supabase";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";

export const dynamic = "force-dynamic";

type ReviewRow = {
  id: string;
  target_type: "barber" | "shop";
  barber_id: string | null;
  shop_id: string | null;
  rating: number | null;
  text: string | null;
  comment: string | null;
  created_at: string;
};

type BarberRow = { id: string; display_name: string | null };
type ShopRow = { id: string; name: string | null };

export default async function MyReviewsPage() {
  const supabase = await createAppSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) redirect("/auth/sign-in?next=/my-reviews");

  const { data: rowsRaw } = await supabase
    .from("reviews")
    .select("id, target_type, barber_id, shop_id, rating, text, comment, created_at")
    .eq("customer_profile_id", user.id)
    .order("created_at", { ascending: false })
    .limit(60);

  const rows = (rowsRaw ?? []) as ReviewRow[];
  const barberIds = rows.map((r) => r.barber_id).filter((v): v is string => typeof v === "string" && v.length > 0);
  const shopIds = rows.map((r) => r.shop_id).filter((v): v is string => typeof v === "string" && v.length > 0);

  const [{ data: barbersRaw }, { data: shopsRaw }] = await Promise.all([
    barberIds.length ? supabase.from("barbers").select("id, display_name").in("id", barberIds) : Promise.resolve({ data: [] }),
    shopIds.length ? supabase.from("barbershops").select("id, name").in("id", shopIds) : Promise.resolve({ data: [] })
  ]);

  const barbers = new Map<string, string>();
  for (const b of (barbersRaw ?? []) as BarberRow[]) barbers.set(b.id, (b.display_name ?? "Barber").trim());

  const shops = new Map<string, string>();
  for (const s of (shopsRaw ?? []) as ShopRow[]) shops.set(s.id, (s.name ?? "Shop").trim());

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 py-6 pb-28 text-white">
      <div className="flex items-center justify-between">
        <Link href="/profile" className="text-sm font-semibold text-[#9E9E9E]">
          Back
        </Link>
        <div className="text-sm font-extrabold">My Reviews</div>
        <div className="w-10" />
      </div>

      {rows.length ? (
        <div className="flex flex-col gap-3">
          {rows.map((r) => {
            const rating = typeof r.rating === "number" ? r.rating : 5;
            const targetName =
              r.target_type === "barber"
                ? r.barber_id
                  ? barbers.get(r.barber_id)
                  : null
                : r.shop_id
                  ? shops.get(r.shop_id)
                  : null;
            return (
              <div key={r.id} className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-4 shadow-[0_18px_44px_rgba(0,0,0,0.55)]">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-sm font-extrabold">{targetName ?? "Review"}</div>
                    <div className="pt-1 text-[12px] font-semibold text-[hsl(var(--gold))]">{"★".repeat(Math.max(1, Math.min(5, rating)))}</div>
                  </div>
                  <div className="text-[12px] font-semibold text-[#9E9E9E]">{new Date(r.created_at).toLocaleDateString()}</div>
                </div>
                {(r.text || r.comment) ? <div className="pt-3 text-sm font-semibold text-[#9E9E9E]">{(r.text ?? r.comment ?? "").trim()}</div> : null}
              </div>
            );
          })}
        </div>
      ) : (
        <div className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-6">
          <div className="text-sm font-extrabold">No reviews yet</div>
          <div className="pt-1 text-sm font-semibold text-[#9E9E9E]">Your reviews will appear here after completed bookings.</div>
        </div>
      )}

      <CustomerBottomNav />
    </main>
  );
}

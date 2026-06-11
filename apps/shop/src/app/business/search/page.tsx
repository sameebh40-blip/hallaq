import Link from "next/link";

import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getMyProfile } from "@hallaq/supabase/profile";

import { getMyShopContext } from "@/lib/my-shop-context";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type BookingSearchRow = {
  id: string;
  status: string | null;
  start_at: string;
  profiles: { full_name: string | null; phone: string | null; email: string | null } | null;
  services: { name_en: string | null; name: string | null } | null;
};

export default async function BusinessSearchPage({ searchParams }: { searchParams?: Promise<{ q?: string; shopId?: string }> }) {
  const sp = searchParams ? await searchParams : undefined;
  const q = (sp?.q ?? "").trim();

  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);
  const ctx = await getMyShopContext(supabase);
  const shopId = ctx.shop?.id ?? (profile?.role === "admin" ? (sp?.shopId ?? null) : null);
  if (!shopId) return <div className="text-sm text-muted-foreground">No shop selected.</div>;

  if (!q) {
    return (
      <LuxuryCard className="p-6">
        <div className="text-base font-semibold">Search</div>
        <div className="pt-2 text-sm text-muted-foreground">Type a query in the top search bar.</div>
      </LuxuryCard>
    );
  }

  const qLike = `%${q}%`;

  const { data: services } = await supabase
    .from("services")
    .select("id, name_en, name, price_bhd, duration_minutes, is_active, deleted_at")
    .or(`shop_id.eq.${shopId},and(owner_type.eq.shop,owner_id.eq.${shopId})`)
    .is("deleted_at", null)
    .or(`name_en.ilike.${qLike},name.ilike.${qLike},category.ilike.${qLike}`)
    .limit(20);

  const { data: customers } = await supabase
    .from("profiles")
    .select("id, full_name, phone, email")
    .or(`full_name.ilike.${qLike},phone.ilike.${qLike},email.ilike.${qLike}`)
    .limit(20);

  const { data: bookings } = await supabase
    .from("bookings")
    .select("id, status, start_at, customer_profile_id, profiles(full_name, phone, email), services(name_en, name)")
    .eq("shop_id", shopId)
    .order("created_at", { ascending: false })
    .limit(30);

  const bookingMatches = ((bookings ?? []) as unknown as BookingSearchRow[]).filter((b) => {
    const id = String(b.id ?? "");
    const status = String(b.status ?? "");
    const name = String(b.profiles?.full_name ?? "");
    const phone = String(b.profiles?.phone ?? "");
    const email = String(b.profiles?.email ?? "");
    const service = String(b.services?.name_en ?? b.services?.name ?? "");
    const hay = `${id} ${status} ${name} ${phone} ${email} ${service}`.toLowerCase();
    return hay.includes(q.toLowerCase());
  });

  return (
    <div className="grid gap-4">
      <LuxuryCard className="p-4">
        <div className="text-base font-semibold">Search</div>
        <div className="pt-1 text-sm text-muted-foreground">
          Results for: <span className="text-foreground">{q}</span>
        </div>
      </LuxuryCard>

      <div className="grid gap-4 lg:grid-cols-3">
        <LuxuryCard className="p-5 lg:col-span-2">
          <div className="text-sm font-semibold">Bookings</div>
          <div className="mt-3 grid gap-2">
            {bookingMatches.length ? (
              bookingMatches.slice(0, 20).map((b) => (
                <div key={b.id} className="flex items-center justify-between gap-3 rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm">
                  <div className="min-w-0">
                    <div className="truncate font-medium">{b.profiles?.full_name ?? "Customer"}</div>
                    <div className="truncate text-xs text-muted-foreground">
                      {new Date(b.start_at).toLocaleString()} • {b.services?.name_en ?? b.services?.name ?? "Service"} • {b.status}
                    </div>
                  </div>
                  <Link className="text-sm text-primary hover:underline" href={`/business/bookings?status=all`}>
                    Open
                  </Link>
                </div>
              ))
            ) : (
              <div className="text-sm text-muted-foreground">No matching bookings.</div>
            )}
          </div>
        </LuxuryCard>

        <LuxuryCard className="p-5">
          <div className="text-sm font-semibold">Customers</div>
          <div className="mt-3 grid gap-2">
            {customers?.length ? (
              customers.map((c) => (
                <div key={c.id} className="rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm">
                  <div className="font-medium">{c.full_name ?? "Customer"}</div>
                  <div className="text-xs text-muted-foreground">{c.phone ?? c.email ?? c.id}</div>
                </div>
              ))
            ) : (
              <div className="text-sm text-muted-foreground">No matching customers.</div>
            )}
          </div>
        </LuxuryCard>
      </div>

      <LuxuryCard className="p-5">
        <div className="text-sm font-semibold">Services</div>
        <div className="mt-3 grid gap-2 md:grid-cols-2">
          {services?.length ? (
            services.map((s) => (
              <div key={s.id} className="rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm">
                <div className="font-medium">{s.name_en ?? s.name ?? "Service"}</div>
                <div className="text-xs text-muted-foreground">
                  {Number(s.price_bhd ?? 0).toFixed(3)} BHD • {Number(s.duration_minutes ?? 0)} min • {s.is_active ? "Active" : "Inactive"}
                </div>
              </div>
            ))
          ) : (
            <div className="text-sm text-muted-foreground">No matching services.</div>
          )}
        </div>
      </LuxuryCard>
    </div>
  );
}

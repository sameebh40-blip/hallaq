import Link from "next/link";
import { redirect } from "next/navigation";

import { createAppSupabaseServerClient } from "@/lib/supabase";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";

export const dynamic = "force-dynamic";

async function addAddress(formData: FormData) {
  "use server";

  const supabase = await createAppSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) redirect("/auth/sign-in?next=/addresses");

  const label = String(formData.get("label") ?? "").trim();
  const line1 = String(formData.get("line1") ?? "").trim();
  const line2 = String(formData.get("line2") ?? "").trim();
  const city = String(formData.get("city") ?? "").trim();
  const country = String(formData.get("country") ?? "").trim();

  if (!label || !line1) return;

  await supabase.from("profile_addresses").insert({
    profile_id: user.id,
    label,
    line1,
    line2: line2 || null,
    city: city || null,
    country: country || "Bahrain",
    is_default: false
  });
}

export default async function AddressesPage() {
  const supabase = await createAppSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) redirect("/auth/sign-in?next=/addresses");

  const { data: rows } = await supabase
    .from("profile_addresses")
    .select("id, label, line1, line2, city, country, is_default, created_at")
    .eq("profile_id", user.id)
    .order("is_default", { ascending: false })
    .order("created_at", { ascending: false })
    .limit(50);

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 py-6 pb-28 text-white">
      <div className="flex items-center justify-between">
        <Link href="/profile" className="text-sm font-semibold text-[#9E9E9E]">
          Back
        </Link>
        <div className="text-sm font-extrabold">Addresses</div>
        <div className="w-10" />
      </div>

      <form action={addAddress} className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-4 shadow-[0_18px_44px_rgba(0,0,0,0.55)]">
        <div className="text-sm font-extrabold">Add Address</div>
        <div className="pt-3 grid grid-cols-1 gap-2">
          <input name="label" placeholder="Label (Home, Office…)" className="h-11 rounded-[18px] border border-[#2A2A2A] bg-black/20 px-4 text-sm font-semibold text-white outline-none" />
          <input name="line1" placeholder="Address line 1" className="h-11 rounded-[18px] border border-[#2A2A2A] bg-black/20 px-4 text-sm font-semibold text-white outline-none" />
          <input name="line2" placeholder="Address line 2 (optional)" className="h-11 rounded-[18px] border border-[#2A2A2A] bg-black/20 px-4 text-sm font-semibold text-white outline-none" />
          <div className="grid grid-cols-2 gap-2">
            <input name="city" placeholder="City" className="h-11 rounded-[18px] border border-[#2A2A2A] bg-black/20 px-4 text-sm font-semibold text-white outline-none" />
            <input name="country" placeholder="Country" defaultValue="Bahrain" className="h-11 rounded-[18px] border border-[#2A2A2A] bg-black/20 px-4 text-sm font-semibold text-white outline-none" />
          </div>
          <button type="submit" className="mt-2 inline-flex h-12 items-center justify-center rounded-[14px] bg-[hsl(var(--gold))] px-5 text-sm font-extrabold text-black shadow-[0_18px_42px_rgba(212,175,55,0.28)]">
            Save
          </button>
        </div>
      </form>

      {rows?.length ? (
        <div className="flex flex-col gap-3">
          {rows.map((a) => (
            <div key={a.id} className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-4 shadow-[0_18px_44px_rgba(0,0,0,0.55)]">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0 flex-1">
                  <div className="truncate text-sm font-extrabold">{a.label || "Address"}</div>
                  <div className="pt-1 text-sm font-semibold text-[#9E9E9E]">
                    {a.line1}
                    {a.line2 ? `, ${a.line2}` : ""}
                  </div>
                  <div className="pt-1 text-[12px] font-semibold text-[#9E9E9E]">
                    {[a.city, a.country].filter(Boolean).join(", ")}
                  </div>
                </div>
                {a.is_default ? <div className="rounded-full border border-[hsl(var(--gold))]/25 bg-black/30 px-3 py-1 text-[11px] font-extrabold text-[hsl(var(--gold))]">Default</div> : null}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-6">
          <div className="text-sm font-extrabold">No addresses</div>
          <div className="pt-1 text-sm font-semibold text-[#9E9E9E]">Add an address to speed up booking checkout.</div>
        </div>
      )}

      <CustomerBottomNav />
    </main>
  );
}


import Link from "next/link";
import { redirect } from "next/navigation";

import { createAppSupabaseServerClient } from "@/lib/supabase";
import { signedOrUrl } from "@hallaq/supabase/storage";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { SafeImage } from "@/components/safe-image";

export const dynamic = "force-dynamic";

type ProfileRow = {
  id: string;
  full_name: string | null;
  email: string | null;
  role: string | null;
  avatar_url: string | null;
  avatar_path: string | null;
  cover_url: string | null;
  cover_path: string | null;
  membership_tier: string | null;
};

type MembershipRow = { points: number | null; tier: string | null };

export default async function CustomerProfilePage() {
  const supabase = await createAppSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) redirect("/auth/sign-in?next=/profile");

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("id, full_name, email, role, avatar_url, avatar_path, cover_url, cover_path, membership_tier")
    .eq("id", user.id)
    .maybeSingle();

  if (profileError) {
    return (
      <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 py-6 pb-28 text-white">
        <div className="text-lg font-extrabold">Profile</div>
        <div className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-6">
          <div className="text-sm font-extrabold">Could not load profile</div>
          <div className="pt-1 text-sm font-semibold text-[#9E9E9E]">Please try again.</div>
        </div>
        <CustomerBottomNav />
      </main>
    );
  }

  if (!profile) redirect("/complete-profile?next=/profile");

  const profileEmail = (profile as ProfileRow | null)?.email ?? null;
  const authEmail = (user.email ?? "").trim();
  if ((!profileEmail || profileEmail.trim() === "") && authEmail) {
    await supabase.from("profiles").upsert({ id: user.id, email: authEmail });
  }

  const [{ count: bookingsCount }, { count: favoritesCount }, { count: addressesCount }, { count: reviewsCount }, { data: membership }] = await Promise.all([
    supabase.from("bookings").select("id", { count: "exact", head: true }).eq("customer_profile_id", user.id),
    supabase.from("favorites").select("id", { count: "exact", head: true }).eq("profile_id", user.id),
    supabase.from("profile_addresses").select("id", { count: "exact", head: true }).eq("profile_id", user.id),
    supabase.from("reviews").select("id", { count: "exact", head: true }).eq("customer_profile_id", user.id),
    supabase.from("customer_membership").select("points, tier").eq("user_id", user.id).maybeSingle()
  ]);

  const p = profile as ProfileRow | null;
  const m = membership as MembershipRow | null;
  const displayName = (p?.full_name ?? "").trim() || (user.email ?? "").trim() || "Customer";
  const displayEmail = (p?.email ?? "").trim() || (user.email ?? "").trim();
  const avatar = await signedOrUrl(supabase, "avatars", p?.avatar_path ?? p?.avatar_url);
  const cover =
    (await signedOrUrl(supabase, "profile-covers", p?.cover_path ?? p?.cover_url)) ??
    (await signedOrUrl(supabase, "avatars", p?.cover_path ?? p?.cover_url));
  const tier = (m?.tier ?? p?.membership_tier ?? "Silver").toString();
  const points = typeof m?.points === "number" ? m.points : 0;

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 py-6 pb-28 text-white">
      <div className="text-lg font-extrabold">Profile</div>

      <section className="overflow-hidden rounded-[24px] border border-[#2A2A2A] bg-[#111111] shadow-[0_18px_44px_rgba(0,0,0,0.55)]">
        <div className="relative h-[150px] w-full">
          <SafeImage src={cover} fallbackKey="default_profile_cover" alt="Cover" className="h-full w-full object-cover" />
          <div className="absolute inset-0 bg-gradient-to-b from-black/20 via-black/20 to-black/75" />
        </div>
        <div className="relative px-4 pb-4">
          <div className="-mt-9 flex items-end justify-between gap-3">
            <div className="flex items-end gap-3">
              <div className="h-[74px] w-[74px] overflow-hidden rounded-[24px] border border-[#2A2A2A] bg-black">
                <SafeImage src={avatar} fallbackKey="default_profile_avatar" alt={displayName} className="h-full w-full object-cover" />
              </div>
              <div className="pb-1">
                <div className="max-w-[220px] truncate text-base font-extrabold">{displayName}</div>
                <div className="pt-1 text-[12px] font-semibold text-[#9E9E9E]">{(p?.role ?? "customer").replace("_", " ")}</div>
                {displayEmail ? <div className="pt-0.5 text-[12px] font-semibold text-[#9E9E9E]">{displayEmail}</div> : null}
              </div>
            </div>
            <div className="rounded-full border border-[hsl(var(--gold))]/25 bg-black/30 px-3 py-1 text-[11px] font-extrabold text-[hsl(var(--gold))]">
              {tier} • {points} pts
            </div>
          </div>

          <div className="grid grid-cols-4 gap-2 pt-4 text-center">
            <div className="rounded-[18px] border border-[#2A2A2A] bg-black/20 p-3">
              <div className="text-base font-extrabold">{bookingsCount ?? 0}</div>
              <div className="pt-0.5 text-[11px] font-semibold text-[#9E9E9E]">Bookings</div>
            </div>
            <div className="rounded-[18px] border border-[#2A2A2A] bg-black/20 p-3">
              <div className="text-base font-extrabold">{favoritesCount ?? 0}</div>
              <div className="pt-0.5 text-[11px] font-semibold text-[#9E9E9E]">Favorites</div>
            </div>
            <div className="rounded-[18px] border border-[#2A2A2A] bg-black/20 p-3">
              <div className="text-base font-extrabold">{reviewsCount ?? 0}</div>
              <div className="pt-0.5 text-[11px] font-semibold text-[#9E9E9E]">Reviews</div>
            </div>
            <div className="rounded-[18px] border border-[#2A2A2A] bg-black/20 p-3">
              <div className="text-base font-extrabold">{addressesCount ?? 0}</div>
              <div className="pt-0.5 text-[11px] font-semibold text-[#9E9E9E]">Addresses</div>
            </div>
          </div>
        </div>
      </section>

      <section className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-3 shadow-[0_18px_44px_rgba(0,0,0,0.55)]">
        <div className="grid grid-cols-2 gap-2">
          <Link href="/bookings" className="rounded-[18px] border border-[#2A2A2A] bg-black/20 p-4 text-sm font-extrabold">
            Bookings
          </Link>
          <Link href="/favorites" className="rounded-[18px] border border-[#2A2A2A] bg-black/20 p-4 text-sm font-extrabold">
            Favorites
          </Link>
          <Link href="/my-reviews" className="rounded-[18px] border border-[#2A2A2A] bg-black/20 p-4 text-sm font-extrabold">
            My Reviews
          </Link>
          <Link href="/addresses" className="rounded-[18px] border border-[#2A2A2A] bg-black/20 p-4 text-sm font-extrabold">
            Addresses
          </Link>
          <Link href="/city/levels" className="rounded-[18px] border border-[#2A2A2A] bg-black/20 p-4 text-sm font-extrabold">
            Loyalty
          </Link>
          <Link href="/notifications" className="rounded-[18px] border border-[#2A2A2A] bg-black/20 p-4 text-sm font-extrabold">
            Notifications
          </Link>
        </div>
      </section>

      <section className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-4 shadow-[0_18px_44px_rgba(0,0,0,0.55)]">
        <div className="text-sm font-extrabold">Settings</div>
        <div className="pt-3 flex flex-col gap-2">
          <Link href="/auth/reset-password" className="rounded-[18px] border border-[#2A2A2A] bg-black/20 px-4 py-3 text-sm font-bold">
            Change password
          </Link>
          <div className="grid grid-cols-2 gap-2">
            <a href="/locale?value=en" className="rounded-[18px] border border-[#2A2A2A] bg-black/20 px-4 py-3 text-center text-sm font-bold">
              English
            </a>
            <a href="/locale?value=ar" className="rounded-[18px] border border-[#2A2A2A] bg-black/20 px-4 py-3 text-center text-sm font-bold">
              العربية
            </a>
          </div>
          <Link href="/support" className="rounded-[18px] border border-[#2A2A2A] bg-black/20 px-4 py-3 text-sm font-bold">
            Support
          </Link>
          <form action="/auth/sign-out" method="post">
            <button type="submit" className="w-full rounded-[18px] border border-rose-500/25 bg-black/20 px-4 py-3 text-sm font-extrabold text-rose-400">
              Logout
            </button>
          </form>
        </div>
      </section>

      <CustomerBottomNav />
    </main>
  );
}

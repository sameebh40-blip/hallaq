import { redirect } from "next/navigation";

import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getMyProfile } from "@hallaq/supabase/profile";

import { BusinessPageHeader } from "@/components/business/page-header";
import { getMyShopContext } from "@/lib/my-shop-context";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong.";
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as the shop owner account.";
  }
  return m;
}

export default async function BusinessReviewsPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string; shopId?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((params?.error ?? "").trim());

  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);
  const ctx = await getMyShopContext(supabase);
  const shopId = ctx.shop?.id ?? (profile?.role === "admin" ? (params?.shopId ?? null) : null);
  if (!shopId) return <div className="text-sm text-muted-foreground">No shop selected.</div>;

  const { data: barbers } = await supabase.from("barbers").select("id, display_name").eq("shop_id", shopId).limit(500);
  const barberIds = (barbers ?? []).map((b) => b.id);

  const { data: reviews } = await supabase
    .from("reviews")
    .select("id, barber_id, shop_id, rating, comment, text, image_url, photo_url, is_verified, reply_text, created_at")
    .or(`shop_id.eq.${shopId}${barberIds.length ? `,barber_id.in.(${barberIds.join(",")})` : ""}`)
    .eq("status", "published")
    .order("created_at", { ascending: false })
    .limit(200);

  async function reply(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "").trim();
    const replyText = String(formData.get("reply_text") ?? "").trim();
    if (!id) redirect("/business/reviews");

    const supabase = await createAppSupabaseServerClient();
    const { error } = await supabase.from("reviews").update({ reply_text: replyText || null }).eq("id", id);
    if (error) redirect(`/business/reviews?error=${encodeURIComponent(error.message)}`);
    redirect("/business/reviews");
  }

  return (
    <div className="grid gap-4">
      <BusinessPageHeader title="Reviews" subtitle="Replying here shows under the review in the app." />
      {params?.error ? <LuxuryCard className="border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard> : null}

      <div className="grid gap-3">
        {reviews?.length ? (
          reviews.map((r) => (
            <LuxuryCard key={r.id} className="p-4">
              <div className="flex items-center justify-between gap-3">
                <div className="text-sm font-medium">
                  {r.barber_id ? barbers?.find((b) => b.id === r.barber_id)?.display_name ?? "Barber" : "Shop"}
                </div>
                <div className="text-xs text-muted-foreground">
                  {new Date(r.created_at).toLocaleDateString()} • {Number(r.rating ?? 0).toFixed(0)}/5 {r.is_verified ? "• Verified" : ""}
                </div>
              </div>
              <div className="mt-2 text-sm text-muted-foreground">{r.comment ?? r.text ?? ""}</div>
              <form action={reply} className="mt-4 grid gap-2">
                <input type="hidden" name="id" value={r.id} />
                <Label>Reply</Label>
                <Input name="reply_text" defaultValue={r.reply_text ?? ""} placeholder="Thank you for your review..." />
                <div className="flex justify-end">
                  <Button type="submit" variant="secondary" size="sm">
                    Save reply
                  </Button>
                </div>
              </form>
            </LuxuryCard>
          ))
        ) : (
          <LuxuryCard className="p-6 text-sm text-muted-foreground">No reviews yet.</LuxuryCard>
        )}
      </div>
    </div>
  );
}

import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getT } from "@hallaq/ui/translations-server";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

export default async function ReviewsPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const t = await getT();
  const params = searchParams ? await searchParams : undefined;
  const supabase = await createSupabaseServerClient();

  const { data: rows } = await supabase
    .from("reviews")
    .select("id, rating, text, target_type, target_id, customer_profile_id, status, is_verified, reply_text, created_at")
    .order("created_at", { ascending: false })
    .limit(50);

  async function recomputeAll() {
    "use server";

    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.rpc("recompute_all_ratings");
    if (error) redirect(`/reviews?error=${encodeURIComponent(error.message)}`);
    redirect("/reviews");
  }

  async function setStatus(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "").trim();
    const status = String(formData.get("status") ?? "").trim();
    if (!id || !status) redirect("/reviews");

    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("reviews").update({ status }).eq("id", id);
    if (error) redirect(`/reviews?error=${encodeURIComponent(error.message)}`);
    redirect("/reviews");
  }

  return (
    <PageFrame title={t("admin.nav.reviews")} subtitle="Moderate feedback and monitor reputation.">
      {params?.error ? (
        <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">
          {params.error}
        </LuxuryCard>
      ) : null}
      <div className="mb-4 flex justify-end">
        <form action={recomputeAll}>
          <Button type="submit" variant="secondary">
            Recompute ratings
          </Button>
        </form>
      </div>
      <LuxuryCard className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[1040px] text-sm">
            <thead className="text-xs text-muted-foreground">
              <tr className="border-b border-white/10">
                <th className="px-4 py-3 text-left font-medium">Rating</th>
                <th className="px-4 py-3 text-left font-medium">Review</th>
                <th className="px-4 py-3 text-left font-medium">Target</th>
                <th className="px-4 py-3 text-left font-medium">Customer</th>
                <th className="px-4 py-3 text-left font-medium">Status</th>
                <th className="px-4 py-3 text-right font-medium">Review ID</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/10">
              {rows?.length ? (
                rows.map((r) => (
                  <tr key={r.id} className="hover:bg-white/5">
                    <td className="px-4 py-3">
                      <span className="rounded-full border border-white/10 bg-white/5 px-2.5 py-1 text-xs text-primary">
                        {r.rating}/5
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <div className="line-clamp-2 font-medium">{r.text ?? "-"}</div>
                      {r.is_verified ? <div className="text-xs text-primary">Verified</div> : null}
                      {r.reply_text ? <div className="text-xs text-muted-foreground">Reply: {r.reply_text}</div> : null}
                      <div className="text-xs text-muted-foreground">
                        {Intl.DateTimeFormat("en", { dateStyle: "medium" }).format(new Date(r.created_at))}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">
                      <span className="font-mono text-xs">{`${r.target_type} • ${r.target_id}`}</span>
                    </td>
                    <td className="px-4 py-3 font-mono text-xs text-muted-foreground">
                      {r.customer_profile_id}
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex flex-wrap gap-2">
                        <span className="rounded-full border border-white/10 bg-white/5 px-2.5 py-1 text-xs">
                          {r.status}
                        </span>
                        <form action={setStatus}>
                          <input type="hidden" name="id" value={r.id} />
                          <input type="hidden" name="status" value="published" />
                          <Button type="submit" size="sm" variant="secondary">
                            Publish
                          </Button>
                        </form>
                        <form action={setStatus}>
                          <input type="hidden" name="id" value={r.id} />
                          <input type="hidden" name="status" value="rejected" />
                          <Button type="submit" size="sm" variant="ghost">
                            Reject
                          </Button>
                        </form>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-right font-mono text-xs text-muted-foreground">
                      {r.id}
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-muted-foreground">
                    No reviews yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </LuxuryCard>
    </PageFrame>
  );
}

import Link from "next/link";
import { redirect } from "next/navigation";

import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getMyProfile } from "@hallaq/supabase/profile";

import { BusinessPageHeader } from "@/components/business/page-header";
import { getMyShopContext } from "@/lib/my-shop-context";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

export default async function BusinessReelsPage({ searchParams }: { searchParams?: Promise<{ shopId?: string }> }) {
  const sp = searchParams ? await searchParams : undefined;
  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);
  const ctx = await getMyShopContext(supabase);
  const shopId = ctx.shop?.id ?? (profile?.role === "admin" ? (sp?.shopId ?? null) : null);
  if (!shopId) return <div className="text-sm text-muted-foreground">No shop selected.</div>;

  const { data: rows } = await supabase
    .from("posts")
    .select("id, media_type, caption, status, created_at, likes_count, comments_count, saves_count, views_count, reach_count")
    .eq("shop_id", shopId)
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(100);

  async function deletePost(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const supabase = await createAppSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;
    await supabase.from("posts").update({ deleted_at: new Date().toISOString() }).eq("id", id);
    if (actorId) {
      await supabase.from("audit_events").insert({
        actor_profile_id: actorId,
        action: "reel_soft_deleted",
        entity_type: "reel",
        entity_id: id,
        meta: {}
      });
    }
    redirect("/business/reels");
  }

  return (
    <div className="grid gap-4">
      <BusinessPageHeader
        title="Reels"
        subtitle="Manage reels and keep the customer feed updated."
        actions={
          <Button asChild variant="secondary" size="sm">
            <Link href="/business/reels/upload">Upload reel</Link>
          </Button>
        }
      />

      <LuxuryCard className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[1100px] text-sm">
            <thead className="text-xs text-muted-foreground">
              <tr className="border-b border-white/10">
                <th className="px-5 py-3 text-left font-medium">Caption</th>
                <th className="px-5 py-3 text-left font-medium">Status</th>
                <th className="px-5 py-3 text-left font-medium">Media</th>
                <th className="px-5 py-3 text-left font-medium">Engagement</th>
                <th className="px-5 py-3 text-right font-medium">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/10">
              {rows?.length ? (
                rows.map((r) => (
                  <tr key={r.id} className="hover:bg-white/5">
                    <td className="px-5 py-3">
                      <div className="line-clamp-1 font-medium">{r.caption ?? "-"}</div>
                      <div className="text-xs text-muted-foreground">
                        {Intl.DateTimeFormat("en", { dateStyle: "medium" }).format(new Date(r.created_at))}
                      </div>
                    </td>
                    <td className="px-5 py-3 text-muted-foreground">{r.status}</td>
                    <td className="px-5 py-3 text-muted-foreground">{r.media_type}</td>
                    <td className="px-5 py-3 text-muted-foreground">
                      <div className="flex items-center gap-3 text-xs">
                        <span>{r.views_count ?? 0} views</span>
                        <span>{r.likes_count ?? 0} likes</span>
                        <span>{r.comments_count ?? 0} comments</span>
                        <span>{r.saves_count ?? 0} saves</span>
                      </div>
                    </td>
                    <td className="px-5 py-3 text-right">
                      <div className="flex justify-end gap-2">
                        <Button asChild size="sm" variant="ghost">
                          <Link href={`/business/reels/${r.id}`}>Edit</Link>
                        </Button>
                        <form action={deletePost}>
                          <input type="hidden" name="id" value={r.id} />
                          <Button type="submit" size="sm" variant="ghost">
                            Delete
                          </Button>
                        </form>
                      </div>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={5} className="px-5 py-10 text-center text-muted-foreground">
                    No reels yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </LuxuryCard>
    </div>
  );
}

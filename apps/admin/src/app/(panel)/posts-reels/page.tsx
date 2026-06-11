import Link from "next/link";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getT } from "@hallaq/ui/translations-server";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

function statusTone(status: string) {
  if (status === "approved") return "text-emerald-200";
  if (status === "rejected") return "text-rose-200";
  return "text-amber-100";
}

export default async function PostsReelsPage({
  searchParams
}: {
  searchParams?: Promise<{ status?: string; view?: string; cursor?: string; error?: string }>;
}) {
  const t = await getT();
  const params = searchParams ? await searchParams : undefined;
  const status = params?.status ?? "pending";
  const view = params?.view === "trash" ? "trash" : "active";
  const cursor = (params?.cursor ?? "").trim() || null;
  const error = (params?.error ?? "").trim();
  const supabase = await createSupabaseServerClient();

  let query = supabase
    .from("posts")
    .select(
      "id, media_type, caption, likes_count, comments_count, saves_count, created_at, barber_id, shop_id, status, is_featured, is_sponsored, location"
    )
    .order("created_at", { ascending: false })
    .limit(50);

  if (status !== "all") query = query.eq("status", status);
  if (view === "trash") query = query.not("deleted_at", "is", null);
  else query = query.is("deleted_at", null);
  if (cursor) query = query.lt("created_at", cursor);

  const { data: rows } = await query;
  const nextCursor = rows?.length ? rows[rows.length - 1].created_at : null;

  async function restore(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const { error: restoreError } = await supabase.from("posts").update({ deleted_at: null }).eq("id", id);
    if (restoreError) redirect(`/posts-reels?status=${encodeURIComponent(status)}&view=trash&error=${encodeURIComponent(restoreError.message)}`);
    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "reel_restored",
      entity_type: "reel",
      entity_id: id,
      meta: {}
    });
    if (logError) redirect(`/posts-reels?status=${encodeURIComponent(status)}&view=trash&error=${encodeURIComponent(logError.message)}`);

    redirect(`/posts-reels?status=${encodeURIComponent(status)}&view=trash`);
  }

  async function approve(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const { error: approveError } = await supabase
      .from("posts")
      .update({
        status: "approved",
        approved_by: actorId,
        approved_at: new Date().toISOString(),
        rejected_by: null,
        rejected_at: null,
        rejection_reason: null
      })
      .eq("id", id);
    if (approveError) redirect(`/posts-reels?status=${encodeURIComponent(status)}&error=${encodeURIComponent(approveError.message)}`);

    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "reel_approved",
      entity_type: "reel",
      entity_id: id,
      meta: {}
    });
    if (logError) redirect(`/posts-reels?status=${encodeURIComponent(status)}&error=${encodeURIComponent(logError.message)}`);

    redirect(`/posts-reels?status=${encodeURIComponent(status)}`);
  }

  async function reject(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const reason = String(formData.get("reason") ?? "");
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const { error: rejectError } = await supabase
      .from("posts")
      .update({
        status: "rejected",
        rejected_by: actorId,
        rejected_at: new Date().toISOString(),
        rejection_reason: reason || null
      })
      .eq("id", id);
    if (rejectError) redirect(`/posts-reels?status=${encodeURIComponent(status)}&error=${encodeURIComponent(rejectError.message)}`);

    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "reel_rejected",
      entity_type: "reel",
      entity_id: id,
      meta: { reason: reason || null }
    });
    if (logError) redirect(`/posts-reels?status=${encodeURIComponent(status)}&error=${encodeURIComponent(logError.message)}`);

    redirect(`/posts-reels?status=${encodeURIComponent(status)}`);
  }

  async function revoke(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const { error: revokeError } = await supabase
      .from("posts")
      .update({
        status: "pending",
        approved_by: null,
        approved_at: null,
        rejected_by: null,
        rejected_at: null,
        rejection_reason: null
      })
      .eq("id", id);
    if (revokeError) redirect(`/posts-reels?status=${encodeURIComponent(status)}&error=${encodeURIComponent(revokeError.message)}`);

    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "reel_revoked",
      entity_type: "reel",
      entity_id: id,
      meta: {}
    });
    if (logError) redirect(`/posts-reels?status=${encodeURIComponent(status)}&error=${encodeURIComponent(logError.message)}`);

    redirect(`/posts-reels?status=${encodeURIComponent(status)}`);
  }

  async function toggleFlag(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const flag = String(formData.get("flag") ?? "");
    const current = String(formData.get("current") ?? "") === "true";

    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    if (!["is_featured", "is_sponsored"].includes(flag)) return;

    const { error: toggleError } = await supabase.from("posts").update({ [flag]: !current }).eq("id", id);
    if (toggleError) redirect(`/posts-reels?status=${encodeURIComponent(status)}&error=${encodeURIComponent(toggleError.message)}`);

    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: flag === "is_featured" ? "reel_feature_toggled" : "reel_sponsor_toggled",
      entity_type: "reel",
      entity_id: id,
      meta: { value: !current }
    });
    if (logError) redirect(`/posts-reels?status=${encodeURIComponent(status)}&error=${encodeURIComponent(logError.message)}`);

    redirect(`/posts-reels?status=${encodeURIComponent(status)}`);
  }

  return (
    <PageFrame
      title={t("admin.reels.title")}
      subtitle={t("admin.reels.subtitle")}
      actions={
        <div className="flex items-center gap-2">
          <Button asChild variant="ghost" size="sm">
            <Link href={`/posts-reels?status=${encodeURIComponent("pending")}`}>
              {t("admin.common.pending")}
            </Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href={`/posts-reels?status=${encodeURIComponent("approved")}`}>
              {t("admin.common.approved")}
            </Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href={`/posts-reels?status=${encodeURIComponent("rejected")}`}>
              {t("admin.common.rejected")}
            </Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href={`/posts-reels?status=${encodeURIComponent("all")}`}>All</Link>
          </Button>
          <Button asChild variant="secondary" size="sm">
            <Link href="/posts-reels/upload">{t("admin.common.upload")}</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link
              href={
                view === "trash"
                  ? `/posts-reels?status=${encodeURIComponent(status)}`
                  : `/posts-reels?status=${encodeURIComponent(status)}&view=trash`
              }
            >
              {view === "trash" ? "Active" : "Trash"}
            </Link>
          </Button>
        </div>
      }
    >
      {error ? (
        <LuxuryCard className="mb-4 border border-rose-500/40 bg-rose-500/10 p-4 text-sm text-rose-100">
          {error}
        </LuxuryCard>
      ) : null}
      <LuxuryCard className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[1180px] text-sm">
            <thead className="text-xs text-muted-foreground">
              <tr className="border-b border-white/10">
                <th className="px-4 py-3 text-left font-medium">Caption</th>
                <th className="px-4 py-3 text-left font-medium">Author</th>
                <th className="px-4 py-3 text-left font-medium">{t("admin.common.status")}</th>
                <th className="px-4 py-3 text-left font-medium">Media</th>
                <th className="px-4 py-3 text-left font-medium">Engagement</th>
                <th className="px-4 py-3 text-right font-medium">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/10">
              {rows?.length ? (
                rows.map((r) => (
                  <tr key={r.id} className="hover:bg-white/5">
                    <td className="px-4 py-3">
                      <Link href={`/posts-reels/${r.id}`} className="line-clamp-1 font-medium underline-offset-4 hover:underline">
                        {r.caption ?? "-"}
                      </Link>
                      <div className="text-xs text-muted-foreground">
                        {Intl.DateTimeFormat("en", { dateStyle: "medium" }).format(new Date(r.created_at))}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">
                      {r.barber_id ? (
                        <span className="font-mono text-xs">{`Barber • ${r.barber_id}`}</span>
                      ) : (
                        <span className="font-mono text-xs">{`Shop • ${r.shop_id}`}</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`rounded-full border border-white/10 bg-white/5 px-2.5 py-1 text-xs ${statusTone(
                          r.status ?? "pending"
                        )}`}
                      >
                        {r.status}
                      </span>
                      {r.location ? <div className="mt-1 text-xs text-muted-foreground">{r.location}</div> : null}
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">{r.media_type ?? "-"}</td>
                    <td className="px-4 py-3 text-muted-foreground">
                      <div className="flex items-center gap-3 text-xs">
                        <span>{r.likes_count ?? 0} likes</span>
                        <span>{r.comments_count ?? 0} comments</span>
                        <span>{r.saves_count ?? 0} saves</span>
                        {r.is_featured ? <span className="text-primary">Featured</span> : null}
                        {r.is_sponsored ? <span className="text-amber-100">Sponsored</span> : null}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-right">
                      <div className="flex justify-end gap-2">
                        {view === "trash" ? (
                          <form action={restore}>
                            <input type="hidden" name="id" value={r.id} />
                            <Button type="submit" size="sm" variant="secondary">
                              Restore
                            </Button>
                          </form>
                        ) : (
                          <>
                            {r.status !== "approved" ? (
                              <form action={approve}>
                                <input type="hidden" name="id" value={r.id} />
                                <Button type="submit" size="sm">
                                  {t("admin.common.approve")}
                                </Button>
                              </form>
                            ) : null}

                            {r.status !== "rejected" ? (
                              <form action={reject} className="flex items-center gap-2">
                                <input type="hidden" name="id" value={r.id} />
                                <input
                                  type="hidden"
                                  name="reason"
                                  value={r.status === "pending" ? "" : "Admin rejection"}
                                />
                                <Button type="submit" size="sm" variant="secondary">
                                  {t("admin.common.reject")}
                                </Button>
                              </form>
                            ) : null}

                            {r.status !== "pending" ? (
                              <form action={revoke}>
                                <input type="hidden" name="id" value={r.id} />
                                <Button type="submit" size="sm" variant="ghost">
                                  Revoke
                                </Button>
                              </form>
                            ) : null}

                            <form action={toggleFlag}>
                              <input type="hidden" name="id" value={r.id} />
                              <input type="hidden" name="flag" value="is_featured" />
                              <input type="hidden" name="current" value={String(Boolean(r.is_featured))} />
                              <Button type="submit" size="sm" variant="ghost">
                                {r.is_featured ? t("admin.common.unfeature") : t("admin.common.feature")}
                              </Button>
                            </form>

                            <form action={toggleFlag}>
                              <input type="hidden" name="id" value={r.id} />
                              <input type="hidden" name="flag" value="is_sponsored" />
                              <input type="hidden" name="current" value={String(Boolean(r.is_sponsored))} />
                              <Button type="submit" size="sm" variant="ghost">
                                {r.is_sponsored ? t("admin.common.unsponsor") : t("admin.common.sponsor")}
                              </Button>
                            </form>
                          </>
                        )}
                      </div>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-muted-foreground">
                    No reels yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </LuxuryCard>

      {view === "active" && nextCursor ? (
        <div className="flex justify-center pt-4">
          <Button asChild variant="ghost">
            <Link href={`/posts-reels?status=${encodeURIComponent(status)}&cursor=${encodeURIComponent(nextCursor)}`}>
              Load more
            </Link>
          </Button>
        </div>
      ) : null}
    </PageFrame>
  );
}

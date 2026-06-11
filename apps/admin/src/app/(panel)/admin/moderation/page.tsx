import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type TabKey = "reels" | "reviews" | "portfolio" | "comments" | "reports";

function normalizeTab(value: string | undefined): TabKey {
  if (value === "reviews") return "reviews";
  if (value === "portfolio") return "portfolio";
  if (value === "comments") return "comments";
  if (value === "reports") return "reports";
  return "reels";
}

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong.";
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as an admin account.";
  }
  return m;
}

export default async function ModerationPage({
  searchParams
}: {
  searchParams?: Promise<{ tab?: string; cursor?: string; status?: string; error?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const tab = normalizeTab(params?.tab);
  const cursor = (params?.cursor ?? "").trim() || null;
  const status = (params?.status ?? "").trim() || null;
  const error = userFacingDbError((params?.error ?? "").trim());

  const supabase = await createSupabaseServerClient();
  const { data: auth } = await supabase.auth.getUser();
  const actorId = auth.user?.id ?? null;

  async function logModeration(action: string, target_type: string, target_id: string, meta?: unknown, reason?: string | null) {
    "use server";

    const supabase = await createSupabaseServerClient();
    const { data: auth } = await supabase.auth.getUser();
    const actorId = auth.user?.id ?? null;

    const { error: historyError } = await supabase.from("moderation_actions").insert({
      actor_profile_id: actorId,
      action,
      target_type,
      target_id,
      reason: reason ?? null,
      meta: (meta ?? {}) as object
    });
    if (historyError) throw historyError;

    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action,
      entity_type: target_type,
      entity_id: target_id,
      meta: (meta ?? {}) as object
    });
    if (logError) throw logError;
  }

  async function approveReel(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const { error: approveError } = await supabase
      .from("reels")
      .update({
        status: "approved",
        approved_by: actorId,
        approved_at: new Date().toISOString(),
        rejected_by: null,
        rejected_at: null,
        rejection_reason: null
      })
      .eq("id", id);
    if (approveError) redirect(`/admin/moderation?tab=reels&error=${encodeURIComponent(approveError.message)}`);

    try {
      await logModeration("reel_approved", "reel", id, {});
    } catch (e) {
      redirect(`/admin/moderation?tab=reels&error=${encodeURIComponent(e instanceof Error ? e.message : "Failed to log moderation")}`);
    }

    redirect("/admin/moderation?tab=reels");
  }

  async function rejectReel(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const reason = String(formData.get("reason") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const { error: rejectError } = await supabase
      .from("reels")
      .update({
        status: "rejected",
        rejected_by: actorId,
        rejected_at: new Date().toISOString(),
        rejection_reason: reason || null
      })
      .eq("id", id);
    if (rejectError) redirect(`/admin/moderation?tab=reels&error=${encodeURIComponent(rejectError.message)}`);

    try {
      await logModeration("reel_rejected", "reel", id, {}, reason || null);
    } catch (e) {
      redirect(`/admin/moderation?tab=reels&error=${encodeURIComponent(e instanceof Error ? e.message : "Failed to log moderation")}`);
    }

    redirect("/admin/moderation?tab=reels");
  }

  async function approvePortfolio(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const { error: approveError } = await supabase
      .from("portfolio_items")
      .update({
        status: "approved",
        approved_by: actorId,
        approved_at: new Date().toISOString(),
        rejected_by: null,
        rejected_at: null,
        rejection_reason: null
      })
      .eq("id", id);
    if (approveError) redirect(`/admin/moderation?tab=portfolio&error=${encodeURIComponent(approveError.message)}`);

    try {
      await logModeration("portfolio_item_approved", "portfolio_item", id, {});
    } catch (e) {
      redirect(`/admin/moderation?tab=portfolio&error=${encodeURIComponent(e instanceof Error ? e.message : "Failed to log moderation")}`);
    }

    redirect("/admin/moderation?tab=portfolio");
  }

  async function rejectPortfolio(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const reason = String(formData.get("reason") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const { error: rejectError } = await supabase
      .from("portfolio_items")
      .update({
        status: "rejected",
        rejected_by: actorId,
        rejected_at: new Date().toISOString(),
        rejection_reason: reason || null
      })
      .eq("id", id);
    if (rejectError) redirect(`/admin/moderation?tab=portfolio&error=${encodeURIComponent(rejectError.message)}`);

    try {
      await logModeration("portfolio_item_rejected", "portfolio_item", id, {}, reason || null);
    } catch (e) {
      redirect(`/admin/moderation?tab=portfolio&error=${encodeURIComponent(e instanceof Error ? e.message : "Failed to log moderation")}`);
    }

    redirect("/admin/moderation?tab=portfolio");
  }

  async function publishReview(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("reviews").update({ status: "published" }).eq("id", id);
    if (error) redirect(`/admin/moderation?tab=reviews&error=${encodeURIComponent(error.message)}`);

    try {
      await logModeration("review_published", "review", id, {});
    } catch (e) {
      redirect(`/admin/moderation?tab=reviews&error=${encodeURIComponent(e instanceof Error ? e.message : "Failed to log moderation")}`);
    }

    redirect("/admin/moderation?tab=reviews");
  }

  async function rejectReview(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("reviews").update({ status: "rejected" }).eq("id", id);
    if (error) redirect(`/admin/moderation?tab=reviews&error=${encodeURIComponent(error.message)}`);

    try {
      await logModeration("review_rejected", "review", id, {});
    } catch (e) {
      redirect(`/admin/moderation?tab=reviews&error=${encodeURIComponent(e instanceof Error ? e.message : "Failed to log moderation")}`);
    }

    redirect("/admin/moderation?tab=reviews");
  }

  async function hideComment(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const reason = String(formData.get("reason") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const { error } = await supabase
      .from("reel_comments")
      .update({ status: "hidden", hidden_by: actorId, hidden_at: new Date().toISOString(), hidden_reason: reason || null })
      .eq("id", id);
    if (error) redirect(`/admin/moderation?tab=comments&error=${encodeURIComponent(error.message)}`);

    try {
      await logModeration("comment_hidden", "reel_comment", id, {}, reason || null);
    } catch (e) {
      redirect(`/admin/moderation?tab=comments&error=${encodeURIComponent(e instanceof Error ? e.message : "Failed to log moderation")}`);
    }

    redirect("/admin/moderation?tab=comments");
  }

  async function unhideComment(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("reel_comments").update({ status: "visible", hidden_by: null, hidden_at: null, hidden_reason: null }).eq("id", id);
    if (error) redirect(`/admin/moderation?tab=comments&error=${encodeURIComponent(error.message)}`);

    try {
      await logModeration("comment_unhidden", "reel_comment", id, {});
    } catch (e) {
      redirect(`/admin/moderation?tab=comments&error=${encodeURIComponent(e instanceof Error ? e.message : "Failed to log moderation")}`);
    }

    redirect("/admin/moderation?tab=comments");
  }

  async function setReportStatus(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const next = String(formData.get("status") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    if (!["open", "under_review", "resolved", "rejected"].includes(next)) redirect("/admin/moderation?tab=reports");

    const update: Record<string, unknown> = { status: next };
    if (next === "under_review") {
      update.reviewed_by = actorId;
      update.reviewed_at = new Date().toISOString();
    }
    if (next === "resolved") {
      update.resolved_by = actorId;
      update.resolved_at = new Date().toISOString();
    }

    const { error } = await supabase.from("reports").update(update).eq("id", id);
    if (error) redirect(`/admin/moderation?tab=reports&error=${encodeURIComponent(error.message)}`);

    try {
      await logModeration("report_status_updated", "report", id, { status: next });
    } catch (e) {
      redirect(`/admin/moderation?tab=reports&error=${encodeURIComponent(e instanceof Error ? e.message : "Failed to log moderation")}`);
    }

    redirect("/admin/moderation?tab=reports");
  }

  const titleByTab: Record<TabKey, string> = {
    reels: "Moderation Queue — Reels",
    reviews: "Moderation Queue — Reviews",
    portfolio: "Moderation Queue — Portfolio",
    comments: "Moderation Queue — Comments",
    reports: "Moderation Queue — Reports"
  };

  const actions = (
    <div className="flex items-center gap-2">
      <Button asChild variant={tab === "reels" ? "secondary" : "ghost"} size="sm">
        <Link href="/admin/moderation?tab=reels">Reels</Link>
      </Button>
      <Button asChild variant={tab === "reviews" ? "secondary" : "ghost"} size="sm">
        <Link href="/admin/moderation?tab=reviews">Reviews</Link>
      </Button>
      <Button asChild variant={tab === "portfolio" ? "secondary" : "ghost"} size="sm">
        <Link href="/admin/moderation?tab=portfolio">Portfolio</Link>
      </Button>
      <Button asChild variant={tab === "comments" ? "secondary" : "ghost"} size="sm">
        <Link href="/admin/moderation?tab=comments">Comments</Link>
      </Button>
      <Button asChild variant={tab === "reports" ? "secondary" : "ghost"} size="sm">
        <Link href="/admin/moderation?tab=reports">Reports</Link>
      </Button>
    </div>
  );

  if (!actorId) {
    redirect("/auth/sign-in");
  }

  if (tab === "reels") {
    let q = supabase
      .from("reels")
      .select("id, caption, created_at, status, barber_id, shop_id")
      .order("created_at", { ascending: false })
      .limit(25);
    q = status ? q.eq("status", status) : q.eq("status", "pending");
    if (cursor) q = q.lt("created_at", cursor);
    const { data: rows } = await q;
    const nextCursor = rows?.length ? rows[rows.length - 1].created_at : null;

    return (
      <PageFrame title={titleByTab[tab]} subtitle="Approve or reject reels. Actions are audited." actions={actions}>
        {params?.error ? (
          <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard>
        ) : null}
        <div className="flex items-center gap-2 pb-4">
          <Button asChild variant="ghost" size="sm">
            <Link href="/admin/moderation?tab=reels&status=pending">Pending</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/admin/moderation?tab=reels&status=approved">Approved</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/admin/moderation?tab=reels&status=rejected">Rejected</Link>
          </Button>
        </div>
        <div className="space-y-3">
          {(rows ?? []).map((r) => (
            <LuxuryCard key={r.id} className="border border-white/10 bg-white/5 p-4">
              <div className="flex flex-col gap-3">
                <div className="flex items-start justify-between gap-4">
                  <div className="min-w-0">
                    <div className="truncate text-sm font-semibold">{r.caption || "Untitled reel"}</div>
                    <div className="mt-1 text-xs text-muted-foreground">
                      {r.created_at} · {r.status} · reel:{r.id}
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <Button asChild variant="ghost" size="sm">
                      <Link href={`/posts-reels?status=${encodeURIComponent(r.status)}`}>Open</Link>
                    </Button>
                  </div>
                </div>
                <div className="grid grid-cols-1 gap-2 md:grid-cols-3">
                  <form action={approveReel}>
                    <input type="hidden" name="id" value={r.id} />
                    <Button type="submit" className="h-10 w-full">
                      Approve
                    </Button>
                  </form>
                  <form action={rejectReel} className="md:col-span-2">
                    <input type="hidden" name="id" value={r.id} />
                    <div className="flex gap-2">
                      <Input name="reason" placeholder="Rejection reason (optional)" className="h-10 bg-white/5" />
                      <Button type="submit" variant="destructive" className="h-10">
                        Reject
                      </Button>
                    </div>
                  </form>
                </div>
              </div>
            </LuxuryCard>
          ))}
          {nextCursor ? (
            <Button asChild variant="secondary" size="sm">
              <Link href={`/admin/moderation?tab=reels&status=${encodeURIComponent(status ?? "pending")}&cursor=${encodeURIComponent(nextCursor)}`}>
                Load more
              </Link>
            </Button>
          ) : null}
        </div>
      </PageFrame>
    );
  }

  if (tab === "portfolio") {
    let q = supabase
      .from("portfolio_items")
      .select("id, caption, created_at, status, owner_type, owner_id")
      .order("created_at", { ascending: false })
      .limit(25);
    q = status ? q.eq("status", status) : q.eq("status", "pending");
    if (cursor) q = q.lt("created_at", cursor);
    const { data: rows } = await q;
    const nextCursor = rows?.length ? rows[rows.length - 1].created_at : null;

    return (
      <PageFrame title={titleByTab[tab]} subtitle="Approve or reject portfolio items. Actions are audited." actions={actions}>
        {params?.error ? (
          <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard>
        ) : null}
        <div className="flex items-center gap-2 pb-4">
          <Button asChild variant="ghost" size="sm">
            <Link href="/admin/moderation?tab=portfolio&status=pending">Pending</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/admin/moderation?tab=portfolio&status=approved">Approved</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/admin/moderation?tab=portfolio&status=rejected">Rejected</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/approvals">Open legacy approvals</Link>
          </Button>
        </div>
        <div className="space-y-3">
          {(rows ?? []).map((r) => (
            <LuxuryCard key={r.id} className="border border-white/10 bg-white/5 p-4">
              <div className="flex flex-col gap-3">
                <div className="min-w-0">
                  <div className="truncate text-sm font-semibold">{r.caption || "Untitled portfolio item"}</div>
                  <div className="mt-1 text-xs text-muted-foreground">
                    {r.created_at} · {r.status} · {r.owner_type}:{r.owner_id} · item:{r.id}
                  </div>
                </div>
                <div className="grid grid-cols-1 gap-2 md:grid-cols-3">
                  <form action={approvePortfolio}>
                    <input type="hidden" name="id" value={r.id} />
                    <Button type="submit" className="h-10 w-full">
                      Approve
                    </Button>
                  </form>
                  <form action={rejectPortfolio} className="md:col-span-2">
                    <input type="hidden" name="id" value={r.id} />
                    <div className="flex gap-2">
                      <Input name="reason" placeholder="Rejection reason (optional)" className="h-10 bg-white/5" />
                      <Button type="submit" variant="destructive" className="h-10">
                        Reject
                      </Button>
                    </div>
                  </form>
                </div>
              </div>
            </LuxuryCard>
          ))}
          {nextCursor ? (
            <Button asChild variant="secondary" size="sm">
              <Link
                href={`/admin/moderation?tab=portfolio&status=${encodeURIComponent(status ?? "pending")}&cursor=${encodeURIComponent(nextCursor)}`}
              >
                Load more
              </Link>
            </Button>
          ) : null}
        </div>
      </PageFrame>
    );
  }

  if (tab === "reviews") {
    let q = supabase
      .from("reviews")
      .select("id, target_type, target_id, rating, text, comment, created_at, status")
      .order("created_at", { ascending: false })
      .limit(25);
    q = status ? q.eq("status", status) : q.eq("status", "pending");
    if (cursor) q = q.lt("created_at", cursor);
    const { data: rows } = await q;
    const nextCursor = rows?.length ? rows[rows.length - 1].created_at : null;

    return (
      <PageFrame title={titleByTab[tab]} subtitle="Publish or reject reviews. Actions are audited." actions={actions}>
        {params?.error ? (
          <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard>
        ) : null}
        <div className="flex items-center gap-2 pb-4">
          <Button asChild variant="ghost" size="sm">
            <Link href="/admin/moderation?tab=reviews&status=pending">Pending</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/admin/moderation?tab=reviews&status=published">Published</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/admin/moderation?tab=reviews&status=rejected">Rejected</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/reviews">Open legacy reviews</Link>
          </Button>
        </div>
        <div className="space-y-3">
          {(rows ?? []).map((r) => (
            <LuxuryCard key={r.id} className="border border-white/10 bg-white/5 p-4">
              <div className="flex flex-col gap-2">
                <div className="flex items-start justify-between gap-4">
                  <div className="min-w-0">
                    <div className="truncate text-sm font-semibold">
                      {r.target_type}:{r.target_id} · {r.rating}★ · {r.status}
                    </div>
                    <div className="mt-1 text-xs text-muted-foreground">
                      {r.created_at} · review:{r.id}
                    </div>
                  </div>
                </div>
                <div className="text-sm text-muted-foreground">{(r.text ?? r.comment ?? "").slice(0, 220)}</div>
                <div className="grid grid-cols-1 gap-2 md:grid-cols-2">
                  <form action={publishReview}>
                    <input type="hidden" name="id" value={r.id} />
                    <Button type="submit" className="h-10 w-full">
                      Publish
                    </Button>
                  </form>
                  <form action={rejectReview}>
                    <input type="hidden" name="id" value={r.id} />
                    <Button type="submit" variant="destructive" className="h-10 w-full">
                      Reject
                    </Button>
                  </form>
                </div>
              </div>
            </LuxuryCard>
          ))}
          {nextCursor ? (
            <Button asChild variant="secondary" size="sm">
              <Link
                href={`/admin/moderation?tab=reviews&status=${encodeURIComponent(status ?? "pending")}&cursor=${encodeURIComponent(nextCursor)}`}
              >
                Load more
              </Link>
            </Button>
          ) : null}
        </div>
      </PageFrame>
    );
  }

  if (tab === "comments") {
    let q = supabase
      .from("reel_comments")
      .select("id, reel_id, profile_id, text, created_at, status, hidden_reason")
      .order("created_at", { ascending: false })
      .limit(25);
    q = status ? q.eq("status", status) : q.eq("status", "visible");
    if (cursor) q = q.lt("created_at", cursor);
    const { data: rows } = await q;
    const nextCursor = rows?.length ? rows[rows.length - 1].created_at : null;

    return (
      <PageFrame title={titleByTab[tab]} subtitle="Hide or unhide comments. Hidden comments are not publicly visible." actions={actions}>
        {params?.error ? (
          <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard>
        ) : null}
        <div className="flex items-center gap-2 pb-4">
          <Button asChild variant="ghost" size="sm">
            <Link href="/admin/moderation?tab=comments&status=visible">Visible</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/admin/moderation?tab=comments&status=hidden">Hidden</Link>
          </Button>
        </div>
        <div className="space-y-3">
          {(rows ?? []).map((r) => (
            <LuxuryCard key={r.id} className="border border-white/10 bg-white/5 p-4">
              <div className="flex flex-col gap-3">
                <div className="flex items-start justify-between gap-4">
                  <div className="min-w-0">
                    <div className="truncate text-sm font-semibold">{r.text.slice(0, 80) || "Comment"}</div>
                    <div className="mt-1 text-xs text-muted-foreground">
                      {r.created_at} · {r.status} · reel:{r.reel_id} · comment:{r.id}
                    </div>
                  </div>
                </div>
                <div className="text-sm text-muted-foreground">{r.text}</div>
                {r.status === "visible" ? (
                  <form action={hideComment}>
                    <input type="hidden" name="id" value={r.id} />
                    <div className="flex gap-2">
                      <Input name="reason" placeholder="Hide reason (optional)" className="h-10 bg-white/5" />
                      <Button type="submit" variant="destructive" className="h-10">
                        Hide
                      </Button>
                    </div>
                  </form>
                ) : (
                  <div className="flex items-center justify-between gap-3">
                    <div className="text-xs text-muted-foreground">{r.hidden_reason ? `Reason: ${r.hidden_reason}` : null}</div>
                    <form action={unhideComment}>
                      <input type="hidden" name="id" value={r.id} />
                      <Button type="submit" variant="secondary" className="h-10">
                        Unhide
                      </Button>
                    </form>
                  </div>
                )}
              </div>
            </LuxuryCard>
          ))}
          {nextCursor ? (
            <Button asChild variant="secondary" size="sm">
              <Link
                href={`/admin/moderation?tab=comments&status=${encodeURIComponent(status ?? "visible")}&cursor=${encodeURIComponent(nextCursor)}`}
              >
                Load more
              </Link>
            </Button>
          ) : null}
        </div>
      </PageFrame>
    );
  }

  let q = supabase
    .from("reports")
    .select("id, report_type, entity_type, entity_id, reason, details, status, created_at, reporter_profile_id")
    .order("created_at", { ascending: false })
    .limit(25);
  q = status ? q.eq("status", status) : q.in("status", ["open", "under_review"]);
  if (cursor) q = q.lt("created_at", cursor);
  const { data: rows } = await q;
  const nextCursor = rows?.length ? rows[rows.length - 1].created_at : null;

  return (
    <PageFrame title={titleByTab[tab]} subtitle="Every report is a ticket. Update status as it moves through the workflow." actions={actions}>
      {params?.error ? (
        <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard>
      ) : null}
      <div className="flex items-center gap-2 pb-4">
        <Button asChild variant="ghost" size="sm">
          <Link href="/admin/moderation?tab=reports&status=open">Open</Link>
        </Button>
        <Button asChild variant="ghost" size="sm">
          <Link href="/admin/moderation?tab=reports&status=under_review">Under Review</Link>
        </Button>
        <Button asChild variant="ghost" size="sm">
          <Link href="/admin/moderation?tab=reports&status=resolved">Resolved</Link>
        </Button>
        <Button asChild variant="ghost" size="sm">
          <Link href="/admin/moderation?tab=reports&status=rejected">Rejected</Link>
        </Button>
      </div>
      <div className="space-y-3">
        {(rows ?? []).map((r) => (
          <LuxuryCard key={r.id} className="border border-white/10 bg-white/5 p-4">
            <div className="flex flex-col gap-2">
              <div className="flex items-start justify-between gap-4">
                <div className="min-w-0">
                  <div className="truncate text-sm font-semibold">
                    {r.report_type} · {r.status} · {r.entity_type}:{r.entity_id ?? "n/a"}
                  </div>
                  <div className="mt-1 text-xs text-muted-foreground">
                    {r.created_at} · reporter:{r.reporter_profile_id ?? "n/a"} · report:{r.id}
                  </div>
                </div>
              </div>
              <div className="text-sm text-muted-foreground">{(r.reason ?? "").slice(0, 220)}</div>
              {r.details ? <div className="text-sm text-muted-foreground">{r.details}</div> : null}
              <form action={setReportStatus} className="flex flex-wrap gap-2">
                <input type="hidden" name="id" value={r.id} />
                <Button type="submit" name="status" value="under_review" variant="secondary" size="sm">
                  Under Review
                </Button>
                <Button type="submit" name="status" value="resolved" size="sm">
                  Resolve
                </Button>
                <Button type="submit" name="status" value="rejected" variant="destructive" size="sm">
                  Reject
                </Button>
              </form>
            </div>
          </LuxuryCard>
        ))}
        {nextCursor ? (
          <Button asChild variant="secondary" size="sm">
            <Link
              href={`/admin/moderation?tab=reports&status=${encodeURIComponent(status ?? "open")}&cursor=${encodeURIComponent(nextCursor)}`}
            >
              Load more
            </Link>
          </Button>
        ) : null}
      </div>
    </PageFrame>
  );
}


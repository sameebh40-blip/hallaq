import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { signedOrUrl } from "@hallaq/supabase/storage";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";
import { SafeImage } from "@/components/safe-image";

export const dynamic = "force-dynamic";

type PortfolioRow = {
  id: string;
  owner_type: "barber" | "shop";
  owner_id: string;
  status: "pending" | "approved" | "rejected";
  media_type: "image" | "video";
  media_path: string | null;
  media_url: string | null;
  thumbnail_path: string | null;
  thumbnail_url: string | null;
  caption: string | null;
  created_at: string;
};

function userFacingDbError(message: string) {
  const m = message.toLowerCase();
  if (m.includes("row-level security") || m.includes("rls")) return "Access denied.";
  if (m.includes("permission")) return "Not allowed.";
  return "Something went wrong.";
}

export default async function ApprovalsPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const errorMessage = (params?.error ?? "").trim();
  const supabase = await createSupabaseServerClient();

  const { data: pendingPortfolio } = await supabase
    .from("portfolio_items")
    .select(
      "id, owner_type, owner_id, status, media_type, media_path, media_url, thumbnail_path, thumbnail_url, caption, created_at"
    )
    .eq("status", "pending")
    .order("created_at", { ascending: false })
    .limit(200);

  const rows = (pendingPortfolio ?? []) as PortfolioRow[];

  const signedRows = await Promise.all(
    rows.map(async (r) => {
      const preview = await signedOrUrl(supabase, "portfolio", r.thumbnail_path ?? r.thumbnail_url ?? r.media_path ?? r.media_url);
      const media = await signedOrUrl(supabase, "portfolio", r.media_path ?? r.media_url);
      return { ...r, previewUrl: preview ?? media ?? "" };
    })
  );

  async function approve(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "").trim();
    if (!id) redirect("/approvals");

    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const { error } = await supabase
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

    if (error) redirect(`/approvals?error=${encodeURIComponent(userFacingDbError(error.message))}`);
    redirect("/approvals");
  }

  async function reject(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "").trim();
    const reason = String(formData.get("reason") ?? "").trim();
    if (!id) redirect("/approvals");

    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const { error } = await supabase
      .from("portfolio_items")
      .update({
        status: "rejected",
        rejected_by: actorId,
        rejected_at: new Date().toISOString(),
        rejection_reason: reason || null
      })
      .eq("id", id);

    if (error) redirect(`/approvals?error=${encodeURIComponent(userFacingDbError(error.message))}`);
    redirect("/approvals");
  }

  return (
    <PageFrame
      title="Approvals"
      subtitle="Approve or reject pending media before it becomes public."
      actions={
        <div className="flex items-center gap-2">
          <Button asChild variant="ghost" size="sm">
            <Link href="/posts-reels?status=pending">Reels pending</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/posts-reels">All reels</Link>
          </Button>
        </div>
      }
    >
      {errorMessage ? (
        <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{errorMessage}</LuxuryCard>
      ) : null}
      <LuxuryCard className="p-5">
        <div className="text-sm font-medium">Pending portfolio</div>
        {signedRows.length ? (
          <div className="mt-4 overflow-x-auto">
            <table className="w-full min-w-[900px] text-sm">
              <thead className="text-xs text-muted-foreground">
                <tr className="border-b border-white/10">
                  <th className="py-2 text-left">Preview</th>
                  <th className="py-2 text-left">Owner</th>
                  <th className="py-2 text-left">Caption</th>
                  <th className="py-2 text-left">Created</th>
                  <th className="py-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {signedRows.map((r) => (
                  <tr key={r.id} className="border-b border-white/5 align-top">
                    <td className="py-3 pr-3">
                      <div className="h-16 w-28 overflow-hidden rounded-md border border-white/10 bg-white/5">
                        <SafeImage
                          src={r.previewUrl}
                          fallbackKey="default_reel_thumbnail"
                          width={112}
                          height={64}
                          className="h-full w-full object-cover"
                        />
                      </div>
                    </td>
                    <td className="py-3 pr-3">
                      <div className="text-xs text-muted-foreground">
                        {r.owner_type}:{r.owner_id}
                      </div>
                      <div className="text-xs text-muted-foreground">{r.media_type}</div>
                      <div className="text-xs text-muted-foreground">{r.id}</div>
                    </td>
                    <td className="py-3 pr-3">
                      <div className="max-w-[360px] truncate text-xs text-muted-foreground">{(r.caption ?? "").trim() || "—"}</div>
                    </td>
                    <td className="py-3 pr-3">
                      <div className="text-xs text-muted-foreground">{new Date(r.created_at).toLocaleString()}</div>
                    </td>
                    <td className="py-3 text-right">
                      <div className="flex justify-end gap-2">
                        <form action={approve}>
                          <input type="hidden" name="id" value={r.id} />
                          <Button type="submit" size="sm" variant="secondary">
                            Approve
                          </Button>
                        </form>
                        <form action={reject} className="grid gap-2">
                          <input type="hidden" name="id" value={r.id} />
                          <Input name="reason" placeholder="Rejection reason" className="h-9 w-52 text-xs" />
                          <Button type="submit" size="sm" variant="ghost">
                            Reject
                          </Button>
                        </form>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="mt-3 text-xs text-muted-foreground">No pending portfolio items.</div>
        )}
      </LuxuryCard>
    </PageFrame>
  );
}

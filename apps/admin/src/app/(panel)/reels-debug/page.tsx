import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type DebugRow = {
  id: string;
  created_by: string | null;
  owner_type: string | null;
  shop_id: string | null;
  barber_id: string | null;
  media_url: string | null;
  media_path: string | null;
  thumbnail_url: string | null;
  thumbnail_path: string | null;
  media_type: string | null;
  status: string | null;
  is_active: boolean | null;
  deleted_at: string | null;
  created_at: string | null;
};

function visibleToClient(row: DebugRow) {
  const reasons: string[] = [];
  if (row.deleted_at) reasons.push("deleted_at != null");
  if (row.is_active !== true) reasons.push("is_active != true");
  if (row.status !== "approved") reasons.push("status != approved");
  const mediaRef = (row.media_path ?? row.media_url ?? "").trim();
  if (!mediaRef) reasons.push("missing media_url/media_path");
  return { ok: reasons.length === 0, reasons };
}

export default async function ReelsDebugPage({
  searchParams,
}: {
  searchParams?: Promise<{ clientCount?: string; clientError?: string }>;
}) {
  const sp = searchParams ? await searchParams : undefined;
  const clientCount = (sp?.clientCount ?? "").trim();
  const clientError = (sp?.clientError ?? "").trim();
  const supabase = await createSupabaseServerClient();

  const { data: rows, error } = await supabase
    .from("posts")
    .select(
      "id, created_by, owner_type, shop_id, barber_id, media_url, media_path, thumbnail_url, thumbnail_path, media_type, status, is_active, deleted_at, created_at"
    )
    .order("created_at", { ascending: false })
    .limit(50);

  async function testClientDiscoverQuery() {
    "use server";

    const supabase = await createSupabaseServerClient();
    const { count, error } = await supabase
      .from("posts")
      .select("id", { count: "exact", head: true })
      .eq("status", "approved")
      .eq("is_active", true)
      .is("deleted_at", null)
      .limit(1);

    if (error) redirect(`/reels-debug?clientError=${encodeURIComponent(error.message)}`);
    redirect(`/reels-debug?clientCount=${encodeURIComponent(String(count ?? 0))}`);
  }

  const list = (rows ?? []) as DebugRow[];

  return (
    <PageFrame
      title="Reels Debug"
      subtitle="Visibility and client query diagnostics for the last 50 posts."
      actions={
        <form action={testClientDiscoverQuery}>
          <Button type="submit" size="sm" variant="secondary">
            Test Client Discover Query
          </Button>
        </form>
      }
    >
      {clientCount ? (
        <LuxuryCard className="mb-4 border border-emerald-500/30 bg-emerald-500/10 p-4 text-sm text-emerald-50">
          Client Discover query count: {clientCount}
        </LuxuryCard>
      ) : null}
      {clientError ? (
        <LuxuryCard className="mb-4 border border-rose-500/40 bg-rose-500/10 p-4 text-sm text-rose-100">{clientError}</LuxuryCard>
      ) : null}
      {error ? (
        <LuxuryCard className="mb-4 border border-rose-500/40 bg-rose-500/10 p-4 text-sm text-rose-100">{error.message}</LuxuryCard>
      ) : null}
      <LuxuryCard className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[1400px] text-sm">
            <thead className="text-xs text-muted-foreground">
              <tr className="border-b border-white/10">
                <th className="px-4 py-3 text-left font-medium">Created</th>
                <th className="px-4 py-3 text-left font-medium">Status</th>
                <th className="px-4 py-3 text-left font-medium">Active</th>
                <th className="px-4 py-3 text-left font-medium">Owner</th>
                <th className="px-4 py-3 text-left font-medium">shop_id</th>
                <th className="px-4 py-3 text-left font-medium">barber_id</th>
                <th className="px-4 py-3 text-left font-medium">created_by</th>
                <th className="px-4 py-3 text-left font-medium">Media Ref</th>
                <th className="px-4 py-3 text-left font-medium">Visible To Client</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/10">
              {list.length ? (
                list.map((r) => {
                  const v = visibleToClient(r);
                  const mediaRef = (r.media_path ?? r.media_url ?? "").trim() || "—";
                  const created = r.created_at ? Intl.DateTimeFormat("en", { dateStyle: "medium" }).format(new Date(r.created_at)) : "—";
                  return (
                    <tr key={r.id} className="hover:bg-white/5">
                      <td className="px-4 py-3 text-muted-foreground">{created}</td>
                      <td className="px-4 py-3 text-muted-foreground">{r.status ?? "—"}</td>
                      <td className="px-4 py-3 text-muted-foreground">{r.is_active === true ? "true" : "false"}</td>
                      <td className="px-4 py-3 text-muted-foreground">{(r.owner_type ?? "").trim() || "—"}</td>
                      <td className="px-4 py-3 text-muted-foreground">{(r.shop_id ?? "").trim() || "—"}</td>
                      <td className="px-4 py-3 text-muted-foreground">{(r.barber_id ?? "").trim() || "—"}</td>
                      <td className="px-4 py-3 text-muted-foreground">{(r.created_by ?? "").trim() || "—"}</td>
                      <td className="px-4 py-3 text-muted-foreground break-all">{mediaRef}</td>
                      <td className="px-4 py-3">
                        {v.ok ? (
                          <span className="text-emerald-200">true</span>
                        ) : (
                          <div className="text-rose-200">
                            <div>false</div>
                            <div className="text-xs text-rose-100/80">{v.reasons.join(", ")}</div>
                          </div>
                        )}
                      </td>
                    </tr>
                  );
                })
              ) : (
                <tr>
                  <td colSpan={9} className="px-4 py-10 text-center text-muted-foreground">
                    No posts yet.
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


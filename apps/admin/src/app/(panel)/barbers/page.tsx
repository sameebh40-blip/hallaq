import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getT } from "@hallaq/ui/translations-server";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

export default async function BarbersPage({
  searchParams
}: {
  searchParams?: Promise<{ view?: string; cursor?: string; error?: string }>;
}) {
  const t = await getT();
  const params = searchParams ? await searchParams : undefined;
  const view = params?.view === "trash" ? "trash" : "active";
  const cursor = (params?.cursor ?? "").trim() || null;
  const error = (params?.error ?? "").trim();
  const supabase = await createSupabaseServerClient();

  let query = supabase
    .from("barbers")
    .select(
      "id, display_name, area, shop_id, status, is_independent, is_verified, is_hallaq_certified, badge_elite, badge_trending, created_at, deleted_at"
    )
    .order("created_at", { ascending: false })
    .limit(50);

  if (view === "trash") query = query.not("deleted_at", "is", null);
  else query = query.is("deleted_at", null);
  if (cursor) query = query.lt("created_at", cursor);

  const { data: rows } = await query;
  const nextCursor = rows?.length ? rows[rows.length - 1].created_at : null;

  async function restoreBarber(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const { error: restoreError } = await supabase.from("barbers").update({ deleted_at: null }).eq("id", id);
    if (restoreError) redirect(`/barbers?view=trash&error=${encodeURIComponent(restoreError.message)}`);

    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "barber_restored",
      entity_type: "barber",
      entity_id: id,
      meta: {}
    });
    if (logError) redirect(`/barbers?view=trash&error=${encodeURIComponent(logError.message)}`);

    redirect("/barbers?view=trash");
  }

  async function toggleField(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const field = String(formData.get("field") ?? "");
    const current = String(formData.get("current") ?? "") === "true";
    const supabase = await createSupabaseServerClient();

    if (!["is_verified", "is_hallaq_certified", "badge_elite", "badge_trending"].includes(field)) {
      redirect("/barbers");
    }

    const { error } = await supabase.from("barbers").update({ [field]: !current }).eq("id", id);
    if (error) redirect(`/barbers?error=${encodeURIComponent(error.message)}`);
    redirect("/barbers");
  }

  async function toggleSuspended(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const current = String(formData.get("current") ?? "");
    const supabase = await createSupabaseServerClient();

    const { error } = await supabase
      .from("barbers")
      .update({ status: current === "suspended" ? "active" : "suspended" })
      .eq("id", id);
    if (error) redirect(`/barbers?error=${encodeURIComponent(error.message)}`);
    redirect("/barbers");
  }

  return (
    <PageFrame
      title={t("admin.nav.barbers")}
      subtitle="Verify, certify, and manage premium badges."
      actions={
        <div className="flex items-center gap-2">
          <Button asChild type="button" variant="ghost" size="sm">
            <Link href={view === "trash" ? "/barbers" : "/barbers?view=trash"}>{view === "trash" ? "Active" : "Trash"}</Link>
          </Button>
          <Button asChild type="button" variant="secondary" size="sm">
            <Link href="/barbers/new">Create Barber</Link>
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
          <table className="w-full min-w-[1040px] text-sm">
            <thead className="text-xs text-muted-foreground">
              <tr className="border-b border-white/10">
                <th className="px-4 py-3 text-left font-medium">Barber</th>
                <th className="px-4 py-3 text-left font-medium">Area</th>
                <th className="px-4 py-3 text-left font-medium">Assignment</th>
                <th className="px-4 py-3 text-left font-medium">Badges</th>
                <th className="px-4 py-3 text-right font-medium">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/10">
              {rows?.length ? (
                rows.map((r) => (
                  <tr key={r.id} className="hover:bg-white/5">
                    <td className="px-4 py-3 font-medium">
                      <Link href={`/barbers/${r.id}`} className="underline-offset-4 hover:underline">
                        {r.display_name ?? "-"}
                      </Link>
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">{r.area ?? "-"}</td>
                    <td className="px-4 py-3 text-muted-foreground">
                      {r.is_independent ? (
                        <span className="text-primary">Independent</span>
                      ) : (
                        <span className="text-muted-foreground">
                          Shop • <span className="font-mono text-xs">{r.shop_id ?? "-"}</span>
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex flex-wrap gap-2 text-xs">
                        <span className={r.is_verified ? "text-emerald-200" : "text-muted-foreground"}>
                          {r.is_verified ? "Verified" : "Unverified"}
                        </span>
                        <span className={r.is_hallaq_certified ? "text-primary" : "text-muted-foreground"}>
                          {r.is_hallaq_certified ? "Certified" : "Not certified"}
                        </span>
                        <span className={r.status === "suspended" ? "text-rose-200" : "text-muted-foreground"}>
                          {r.status ?? "active"}
                        </span>
                        <span className={r.badge_elite ? "text-amber-100" : "text-muted-foreground"}>
                          {r.badge_elite ? "Elite" : "—"}
                        </span>
                        <span className={r.badge_trending ? "text-amber-100" : "text-muted-foreground"}>
                          {r.badge_trending ? "Trending" : "—"}
                        </span>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-right">
                      <div className="flex justify-end gap-2">
                        {view === "trash" ? (
                          <form action={restoreBarber}>
                            <input type="hidden" name="id" value={r.id} />
                            <Button type="submit" size="sm" variant="secondary">
                              Restore
                            </Button>
                          </form>
                        ) : (
                          <>
                            <form action={toggleField}>
                              <input type="hidden" name="id" value={r.id} />
                              <input type="hidden" name="field" value="is_verified" />
                              <input type="hidden" name="current" value={String(Boolean(r.is_verified))} />
                              <Button type="submit" size="sm" variant="secondary">
                                {r.is_verified ? "Unverify" : "Verify"}
                              </Button>
                            </form>
                            <form action={toggleField}>
                              <input type="hidden" name="id" value={r.id} />
                              <input type="hidden" name="field" value="is_hallaq_certified" />
                              <input
                                type="hidden"
                                name="current"
                                value={String(Boolean(r.is_hallaq_certified))}
                              />
                              <Button type="submit" size="sm">
                                {r.is_hallaq_certified ? "Uncertify" : "Certify"}
                              </Button>
                            </form>
                            <form action={toggleSuspended}>
                              <input type="hidden" name="id" value={r.id} />
                              <input type="hidden" name="current" value={String(r.status ?? "")} />
                              <Button type="submit" size="sm" variant="ghost">
                                {r.status === "suspended" ? "Unsuspend" : "Suspend"}
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
                  <td colSpan={5} className="px-4 py-10 text-center text-muted-foreground">
                    No barbers yet.
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
            <Link href={`/barbers?cursor=${encodeURIComponent(nextCursor)}`}>Load more</Link>
          </Button>
        </div>
      ) : null}
    </PageFrame>
  );
}

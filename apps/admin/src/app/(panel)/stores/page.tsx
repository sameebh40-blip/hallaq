import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getT } from "@hallaq/ui/translations-server";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

export default async function StoresPage({
  searchParams
}: {
  searchParams?: Promise<{ view?: string; cursor?: string; error?: string; created?: string }>;
}) {
  const t = await getT();
  const params = searchParams ? await searchParams : undefined;
  const view = params?.view === "trash" ? "trash" : "active";
  const cursor = (params?.cursor ?? "").trim() || null;
  const errorMessage = (params?.error ?? "").trim();
  const createdId = (params?.created ?? "").trim();
  const supabase = await createSupabaseServerClient();

  let query = supabase
    .from("barbershops")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(50);

  if (view === "trash") query = query.not("deleted_at", "is", null);
  else query = query.is("deleted_at", null);
  if (cursor) query = query.lt("created_at", cursor);

  const { data: rows, error } = await query;
  const nextCursor = rows?.length ? rows[rows.length - 1].created_at : null;
  const formatDeletedAt = (value: unknown) => {
    if (!value) return null;
    const d = value instanceof Date ? value : new Date(String(value));
    if (Number.isNaN(d.getTime())) return null;
    return Intl.DateTimeFormat("en", { dateStyle: "medium" }).format(d);
  };

  async function restoreStore(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const { error } = await supabase.from("barbershops").update({ deleted_at: null }).eq("id", id);
    if (error) redirect(`/stores?view=trash&error=${encodeURIComponent(error.message)}`);
    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "store_restored",
      entity_type: "shop",
      entity_id: id,
      meta: {}
    });
    if (logError) redirect(`/stores?view=trash&error=${encodeURIComponent(logError.message)}`);

    redirect("/stores?view=trash");
  }

  async function toggleVerified(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const current = String(formData.get("current") ?? "") === "true";
    const supabase = await createSupabaseServerClient();

    const { error } = await supabase
      .from("barbershops")
      .update({ is_verified: !current, status: !current ? "approved" : "pending" })
      .eq("id", id);
    if (error) redirect(`/stores?error=${encodeURIComponent(error.message)}`);
    redirect("/stores");
  }

  async function toggleFeatured(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const current = String(formData.get("current") ?? "") === "true";
    const supabase = await createSupabaseServerClient();

    const { error } = await supabase.from("barbershops").update({ is_featured: !current }).eq("id", id);
    if (error) redirect(`/stores?error=${encodeURIComponent(error.message)}`);
    redirect("/stores");
  }

  async function toggleSuspended(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const current = String(formData.get("current") ?? "");
    const supabase = await createSupabaseServerClient();

    const { error } = await supabase
      .from("barbershops")
      .update({ status: current === "suspended" ? "approved" : "suspended" })
      .eq("id", id);
    if (error) redirect(`/stores?error=${encodeURIComponent(error.message)}`);
    redirect("/stores");
  }

  return (
    <PageFrame
      title={t("admin.nav.stores")}
      subtitle="Manage barbershops: verification, featured placement, and contact details."
      actions={
        <div className="flex items-center gap-2">
          <Button asChild type="button" variant="ghost" size="sm">
            <Link href={view === "trash" ? "/stores" : "/stores?view=trash"}>{view === "trash" ? "Active" : "Trash"}</Link>
          </Button>
          <Button asChild type="button" variant="secondary" size="sm">
            <Link href="/stores/new">Create Store</Link>
          </Button>
        </div>
      }
    >
      {createdId ? (
        <div className="mb-4 rounded-xl border border-emerald-500/20 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-100">
          Store created: <span className="font-mono text-xs">{createdId}</span>
        </div>
      ) : null}
      {errorMessage ? (
        <div className="mb-4 rounded-xl border border-rose-500/20 bg-rose-500/10 px-4 py-3 text-sm text-rose-100">
          {errorMessage}
        </div>
      ) : null}
      <LuxuryCard className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[980px] text-sm">
            <thead className="text-xs text-muted-foreground">
              <tr className="border-b border-white/10">
                <th className="px-4 py-3 text-left font-medium">Store</th>
                <th className="px-4 py-3 text-left font-medium">Shop ID</th>
                <th className="px-4 py-3 text-left font-medium">Area</th>
                <th className="px-4 py-3 text-left font-medium">Owner</th>
                <th className="px-4 py-3 text-left font-medium">Contact</th>
                <th className="px-4 py-3 text-left font-medium">Status</th>
                <th className="px-4 py-3 text-right font-medium">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/10">
              {error ? (
                <tr>
                  <td colSpan={7} className="px-4 py-10 text-center text-muted-foreground">
                    {error.message}
                  </td>
                </tr>
              ) : rows?.length ? (
                rows.map((r) => (
                  <tr key={r.id} className="hover:bg-white/5">
                    <td className="px-4 py-3 font-medium">
                      <Link href={`/stores/${r.id}`} className="underline-offset-4 hover:underline">
                        {r.name ?? "-"}
                      </Link>
                    </td>
                    <td className="px-4 py-3 font-mono text-xs text-muted-foreground">{r.id}</td>
                    <td className="px-4 py-3 text-muted-foreground">
                      {r.area ?? "-"}
                      {r.address ? <div className="text-xs text-muted-foreground/70">{r.address}</div> : null}
                    </td>
                    <td className="px-4 py-3 font-mono text-xs text-muted-foreground">
                      {r.owner_profile_id ?? "-"}
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">
                      <div className="flex flex-col gap-1">
                        {"whatsapp" in r ? <div>{(r as { whatsapp?: string }).whatsapp ?? "-"}</div> : <div>-</div>}
                        {"instagram" in r ? (
                          <div className="text-xs text-muted-foreground/70">{(r as { instagram?: string }).instagram ?? "-"}</div>
                        ) : (
                          <div className="text-xs text-muted-foreground/70">-</div>
                        )}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        {"is_verified" in r ? (
                          <span className={(r as { is_verified?: boolean }).is_verified ? "text-emerald-200" : "text-muted-foreground"}>
                            {(r as { is_verified?: boolean }).is_verified ? "Verified" : "Unverified"}
                          </span>
                        ) : (
                          <span className="text-muted-foreground">-</span>
                        )}
                        <span className="text-muted-foreground">•</span>
                        {"is_featured" in r ? (
                          <span className={(r as { is_featured?: boolean }).is_featured ? "text-primary" : "text-muted-foreground"}>
                            {(r as { is_featured?: boolean }).is_featured ? "Featured" : "Standard"}
                          </span>
                        ) : (
                          <span className="text-muted-foreground">-</span>
                        )}
                        <span className="text-muted-foreground">•</span>
                        {"status" in r ? (
                          <span className={String((r as { status?: string }).status ?? "") === "suspended" ? "text-rose-200" : "text-muted-foreground"}>
                            {(r as { status?: string }).status ?? "pending"}
                          </span>
                        ) : (
                          <span className="text-muted-foreground">-</span>
                        )}
                      </div>
                      {view === "trash" ? (
                        <div className="mt-1 text-xs text-muted-foreground">
                          {(() => {
                            const formatted = formatDeletedAt((r as { deleted_at?: unknown }).deleted_at);
                            return formatted ? `Deleted ${formatted}` : "Deleted";
                          })()}
                        </div>
                      ) : null}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <div className="flex justify-end gap-2">
                        {view === "trash" ? (
                          <form action={restoreStore}>
                            <input type="hidden" name="id" value={r.id} />
                            <Button type="submit" size="sm" variant="secondary">
                              Restore
                            </Button>
                          </form>
                        ) : (
                          <>
                            <form action={toggleVerified}>
                              <input type="hidden" name="id" value={r.id} />
                              <input
                                type="hidden"
                                name="current"
                                value={String("is_verified" in r ? Boolean((r as { is_verified?: boolean }).is_verified) : false)}
                              />
                              <Button type="submit" size="sm" variant="secondary">
                                {"is_verified" in r && (r as { is_verified?: boolean }).is_verified ? "Unverify" : "Verify"}
                              </Button>
                            </form>
                            <form action={toggleFeatured}>
                              <input type="hidden" name="id" value={r.id} />
                              <input
                                type="hidden"
                                name="current"
                                value={String("is_featured" in r ? Boolean((r as { is_featured?: boolean }).is_featured) : false)}
                              />
                              <Button type="submit" size="sm">
                                {"is_featured" in r && (r as { is_featured?: boolean }).is_featured ? "Unfeature" : "Feature"}
                              </Button>
                            </form>
                            <form action={toggleSuspended}>
                              <input type="hidden" name="id" value={r.id} />
                              <input type="hidden" name="current" value={String("status" in r ? (r as { status?: string }).status ?? "" : "")} />
                              <Button type="submit" size="sm" variant="ghost">
                                {"status" in r && (r as { status?: string }).status === "suspended" ? "Unsuspend" : "Suspend"}
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
                  <td colSpan={7} className="px-4 py-10 text-center text-muted-foreground">
                    No stores yet.
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
            <Link href={`/stores?cursor=${encodeURIComponent(nextCursor)}`}>Load more</Link>
          </Button>
        </div>
      ) : null}
    </PageFrame>
  );
}

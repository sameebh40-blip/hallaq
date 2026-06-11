import Link from "next/link";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type SearchParams = {
  q?: string;
  sort?: string;
  dir?: string;
  limit?: string;
  id?: string;
};

function safeInt(value: string | undefined, fallback: number) {
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? Math.min(Math.floor(n), 200) : fallback;
}

function isUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

function csvEscape(value: unknown) {
  if (value == null) return "";
  const s = typeof value === "string" ? value : JSON.stringify(value);
  if (/[",\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

const searchColumns: Record<string, string[]> = {
  profiles: ["full_name", "email", "phone", "role"],
  barbershops: ["name", "area", "address", "status"],
  barbers: ["display_name", "area", "specialty"],
  services: ["name_en", "name_ar", "name", "category"],
  products: ["name", "description"],
  reels: ["caption", "status", "location"],
  reviews: ["comment", "status"],
  notifications: ["title", "body", "type"],
  offers: ["title", "status"],
  awards: ["title", "status"],
  system_logs: ["page", "action", "severity", "error_message"],
  admin_audit_logs: ["action", "target_type"]
};

async function getClient() {
  try {
    return await createSupabaseAdminClient();
  } catch {
    return await createSupabaseServerClient();
  }
}

export default async function TablePage({
  params,
  searchParams
}: {
  params: Promise<{ table: string }>;
  searchParams?: Promise<SearchParams>;
}) {
  const { table } = await params;
  const sp = searchParams ? await searchParams : {};
  const q = (sp.q ?? "").trim();
  const sort = (sp.sort ?? "").trim();
  const dir = (sp.dir ?? "").trim().toLowerCase();
  const limit = safeInt(sp.limit, 50);
  const selectedId = (sp.id ?? "").trim();

  const supabase = await getClient();

  let query = supabase.from(table).select("*").limit(limit);

  if (sort) {
    query = query.order(sort, { ascending: dir !== "desc" });
  } else {
    query = query.order("created_at", { ascending: false });
  }

  if (q) {
    const cols = searchColumns[table] ?? [];
    if (cols.length) {
      const or = cols.map((c) => `${c}.ilike.%${q.replaceAll("%", "")}%`).join(",");
      query = query.or(or);
    } else if (isUuid(q)) {
      query = query.eq("id", q);
    }
  }

  const { data: rows, error } = await query;
  const list = (rows ?? []) as Array<Record<string, unknown>>;

  const { data: selectedRow, error: selectedError } =
    selectedId && isUuid(selectedId)
      ? await supabase.from(table).select("*").eq("id", selectedId).maybeSingle()
      : { data: null, error: null };

  async function updateRow(formData: FormData) {
    "use server";

    const t = String(formData.get("table") ?? "").trim();
    const id = String(formData.get("id") ?? "").trim();
    const patchRaw = String(formData.get("patch") ?? "").trim();
    if (!t || !id || !patchRaw) redirect(`/data/${t}`);

    let patch: Record<string, unknown>;
    try {
      patch = JSON.parse(patchRaw) as Record<string, unknown>;
    } catch {
      redirect(`/data/${t}?id=${id}&error=invalid_json`);
    }

    const client = await getClient();
    await client.from(t).update(patch).eq("id", id);

    try {
      const server = await createSupabaseServerClient();
      const { data: authData } = await server.auth.getUser();
      const actorId = authData.user?.id ?? null;
      await Promise.allSettled([
        server.from("admin_audit_logs").insert({
          admin_profile_id: actorId,
          action: "data_update",
          target_type: t,
          target_id: id,
          meta: { patch }
        }),
        server.from("admin_activity_logs").insert({
          actor_profile_id: actorId,
          action: "data_update",
          entity_type: t,
          entity_id: id,
          meta: { patch }
        })
      ]);
    } catch {}

    revalidatePath(`/data/${t}`);
    redirect(`/data/${t}?id=${id}`);
  }

  async function deleteRow(formData: FormData) {
    "use server";

    const t = String(formData.get("table") ?? "").trim();
    const id = String(formData.get("id") ?? "").trim();
    if (!t || !id) redirect(`/data/${t}`);
    const client = await getClient();
    await client.from(t).delete().eq("id", id);

    try {
      const server = await createSupabaseServerClient();
      const { data: authData } = await server.auth.getUser();
      const actorId = authData.user?.id ?? null;
      await Promise.allSettled([
        server.from("admin_audit_logs").insert({
          admin_profile_id: actorId,
          action: "data_delete",
          target_type: t,
          target_id: id,
          meta: {}
        }),
        server.from("admin_activity_logs").insert({
          actor_profile_id: actorId,
          action: "data_delete",
          entity_type: t,
          entity_id: id,
          meta: {}
        })
      ]);
    } catch {}

    revalidatePath(`/data/${t}`);
    redirect(`/data/${t}`);
  }

  return (
    <PageFrame
      title={`Data: ${table}`}
      subtitle="Search, view, edit via JSON patch, delete, and export CSV."
      actions={
        <div className="flex items-center gap-2">
          <Button asChild variant="ghost" size="sm">
            <Link href="/data">All tables</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href={`/data/${table}/export?q=${encodeURIComponent(q)}&sort=${encodeURIComponent(sort)}&dir=${encodeURIComponent(dir)}&limit=${encodeURIComponent(String(limit))}`}>
              Export CSV
            </Link>
          </Button>
          <Button asChild variant="secondary" size="sm">
            <Link href={`/data/${table}`}>Refresh</Link>
          </Button>
        </div>
      }
    >
      <LuxuryCard className="p-5">
        <form className="flex flex-col gap-3 md:flex-row md:items-center" action="">
          <input
            name="q"
            placeholder="Search…"
            defaultValue={q}
            className="h-11 w-full rounded-md border border-white/10 bg-white/5 px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
          />
          <input
            name="sort"
            placeholder="Sort column (optional)"
            defaultValue={sort}
            className="h-11 w-full rounded-md border border-white/10 bg-white/5 px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring md:max-w-[240px]"
          />
          <select
            name="dir"
            defaultValue={dir || "desc"}
            className="h-11 w-full rounded-md border border-white/10 bg-white/5 px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring md:max-w-[160px]"
          >
            <option value="desc">desc</option>
            <option value="asc">asc</option>
          </select>
          <input
            name="limit"
            placeholder="Limit"
            defaultValue={String(limit)}
            className="h-11 w-full rounded-md border border-white/10 bg-white/5 px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring md:max-w-[120px]"
          />
          <Button type="submit" className="h-11">
            Apply
          </Button>
        </form>
      </LuxuryCard>

      <div className="pt-4 grid grid-cols-1 gap-4 xl:grid-cols-[1fr,460px]">
        <LuxuryCard className="overflow-hidden">
            <div className="flex items-center justify-between gap-4 border-b border-white/10 px-4 py-3">
            <div className="text-sm font-medium">Rows</div>
            <div className="text-xs text-muted-foreground">{list.length}</div>
          </div>
          {error ? (
            <div className="px-4 py-6 text-sm text-rose-200">{error.message}</div>
          ) : list.length ? (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[920px] text-sm">
                <thead className="text-xs text-muted-foreground">
                  <tr className="border-b border-white/10">
                    <th className="px-4 py-3 text-left font-medium">ID</th>
                    <th className="px-4 py-3 text-left font-medium">Preview</th>
                    <th className="px-4 py-3 text-right font-medium">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-white/10">
                  {list.map((r) => {
                    const idValue = r.id == null ? "" : String(r.id);
                    const key = idValue || JSON.stringify(r);
                    return (
                    <tr key={key} className="hover:bg-white/5">
                      <td className="px-4 py-3 font-mono text-xs text-muted-foreground break-all">{idValue}</td>
                      <td className="px-4 py-3 text-xs text-muted-foreground break-all">
                        {csvEscape(Object.fromEntries(Object.entries(r).slice(0, 6)))}
                      </td>
                      <td className="px-4 py-3 text-right">
                        {idValue ? (
                          <Button asChild size="sm" variant="ghost">
                            <Link href={`/data/${table}?id=${encodeURIComponent(idValue)}`}>View</Link>
                          </Button>
                        ) : (
                          <span className="text-xs text-muted-foreground">—</span>
                        )}
                      </td>
                    </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="px-4 py-10 text-sm text-muted-foreground">No rows.</div>
          )}
        </LuxuryCard>

        <LuxuryCard className="p-5">
          <div className="flex flex-col gap-3">
            <div className="flex items-center justify-between gap-3">
              <div className="text-sm font-semibold">Row detail</div>
              {selectedId ? (
                <Button asChild size="sm" variant="ghost">
                  <Link href={`/data/${table}`}>Clear</Link>
                </Button>
              ) : null}
            </div>

            {selectedId ? (
              selectedError ? (
                <div className="text-sm text-rose-200">{selectedError.message}</div>
              ) : selectedRow ? (
                <>
                  <div className="rounded-lg border border-white/10 bg-white/5 p-3 text-xs text-muted-foreground break-all">
                    {JSON.stringify(selectedRow, null, 2)}
                  </div>

                  <div className="text-xs text-muted-foreground">JSON patch (update by id):</div>
                  <form action={updateRow} className="flex flex-col gap-2">
                    <input type="hidden" name="table" value={table} />
                    <input type="hidden" name="id" value={selectedId} />
                    <textarea
                      name="patch"
                      rows={6}
                      placeholder='{"status":"active"}'
                      className="w-full rounded-md border border-white/10 bg-white/5 px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
                    />
                    <Button type="submit" className="h-11" variant="secondary">
                      Save patch
                    </Button>
                  </form>

                  <form action={deleteRow} className="pt-3">
                    <input type="hidden" name="table" value={table} />
                    <input type="hidden" name="id" value={selectedId} />
                    <Button type="submit" className="h-11" variant="ghost">
                      Delete row
                    </Button>
                  </form>
                </>
              ) : (
                <div className="text-sm text-muted-foreground">Not found.</div>
              )
            ) : (
              <div className="text-sm text-muted-foreground">Select a row to view/edit.</div>
            )}
          </div>
        </LuxuryCard>
      </div>
    </PageFrame>
  );
}

import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { cn } from "@hallaq/ui/cn";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type ContentType = "shops" | "barbers" | "services" | "products" | "reels" | "offers" | "reviews" | "styles";

function typeFromParam(value: string | undefined): ContentType {
  const v = String(value ?? "").trim();
  if (v === "shops" || v === "barbers" || v === "services" || v === "products" || v === "reels" || v === "offers" || v === "reviews" || v === "styles") {
    return v;
  }
  return "services";
}

function statusForAction(action: string) {
  switch (action) {
    case "approve":
      return "approved";
    case "reject":
      return "rejected";
    case "hide":
      return "hidden";
    case "archive":
      return "archived";
    case "restore":
      return "approved";
    case "draft":
      return "draft";
    default:
      return null;
  }
}

export default async function AdminContentStatusPage({
  searchParams
}: {
  searchParams?: Promise<{ type?: string; q?: string; error?: string; status?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const type = typeFromParam(params?.type);
  const q = String(params?.q ?? "").trim();
  const statusFilter = String(params?.status ?? "").trim();
  const error = String(params?.error ?? "").trim();

  const supabase = await createSupabaseServerClient();

  async function updateStatus(formData: FormData) {
    "use server";

    const type = typeFromParam(String(formData.get("type") ?? ""));
    const id = String(formData.get("id") ?? "").trim();
    const action = String(formData.get("action") ?? "").trim();
    const nextStatus = statusForAction(action);
    const returnType = String(formData.get("return_type") ?? "").trim() || type;
    const returnQ = String(formData.get("return_q") ?? "").trim();
    const returnStatus = String(formData.get("return_status") ?? "").trim();

    if (!id || !nextStatus) redirect(`/admin/content-status?type=${encodeURIComponent(returnType)}&q=${encodeURIComponent(returnQ)}&status=${encodeURIComponent(returnStatus)}`);

    const supabase = await createSupabaseServerClient();

    const table =
      type === "shops"
        ? "barbershops"
        : type === "styles"
          ? "style_library"
          : type === "reels"
            ? "reels"
            : type;

    const { error } = await supabase.from(table).update({ status: nextStatus }).eq("id", id);
    if (error) {
      redirect(
        `/admin/content-status?type=${encodeURIComponent(returnType)}&q=${encodeURIComponent(returnQ)}&status=${encodeURIComponent(
          returnStatus
        )}&error=${encodeURIComponent(error.message)}`
      );
    }

    redirect(`/admin/content-status?type=${encodeURIComponent(returnType)}&q=${encodeURIComponent(returnQ)}&status=${encodeURIComponent(returnStatus)}`);
  }

  async function toggleActive(formData: FormData) {
    "use server";

    const type = typeFromParam(String(formData.get("type") ?? ""));
    const id = String(formData.get("id") ?? "").trim();
    const current = String(formData.get("current") ?? "") === "true";
    const returnType = String(formData.get("return_type") ?? "").trim() || type;
    const returnQ = String(formData.get("return_q") ?? "").trim();
    const returnStatus = String(formData.get("return_status") ?? "").trim();

    if (!id) redirect(`/admin/content-status?type=${encodeURIComponent(returnType)}&q=${encodeURIComponent(returnQ)}&status=${encodeURIComponent(returnStatus)}`);

    const supabase = await createSupabaseServerClient();

    const table =
      type === "shops"
        ? "barbershops"
        : type === "styles"
          ? "style_library"
          : type === "reels"
            ? "reels"
            : type;

    const { error } = await supabase.from(table).update({ is_active: !current }).eq("id", id);
    if (error) {
      redirect(
        `/admin/content-status?type=${encodeURIComponent(returnType)}&q=${encodeURIComponent(returnQ)}&status=${encodeURIComponent(
          returnStatus
        )}&error=${encodeURIComponent(error.message)}`
      );
    }

    redirect(`/admin/content-status?type=${encodeURIComponent(returnType)}&q=${encodeURIComponent(returnQ)}&status=${encodeURIComponent(returnStatus)}`);
  }

  const tabs: Array<{ key: ContentType; label: string }> = [
    { key: "shops", label: "Shops" },
    { key: "barbers", label: "Barbers" },
    { key: "services", label: "Services" },
    { key: "products", label: "Products" },
    { key: "reels", label: "Reels" },
    { key: "offers", label: "Offers" },
    { key: "reviews", label: "Reviews" },
    { key: "styles", label: "Styles" }
  ];

  const table =
    type === "shops"
      ? "barbershops"
      : type === "styles"
        ? "style_library"
        : type === "reels"
          ? "reels"
          : type;

  const select =
    type === "shops"
      ? "id, name, area, status, is_active, created_at"
      : type === "barbers"
        ? "id, display_name, shop_id, status, is_active, is_verified, created_at"
        : type === "services"
          ? "id, name_en, name_ar, shop_id, barber_id, status, is_active, created_at"
          : type === "products"
            ? "id, name, shop_id, status, is_active, active, created_at"
            : type === "offers"
              ? "id, title, shop_id, barber_id, status, is_active, active, created_at"
              : type === "reviews"
                ? "id, rating, target_type, target_id, status, is_active, created_at"
                : type === "styles"
                  ? "id, name_en, name_ar, category, status, is_active, created_at"
                  : "id, caption, status, deleted_at, created_at";

  type UntypedQuery = {
    select: (columns: string) => UntypedQuery;
    order: (column: string, opts: { ascending: boolean }) => UntypedQuery;
    limit: (n: number) => UntypedQuery;
    eq: (column: string, value: string) => UntypedQuery;
    ilike: (column: string, pattern: string) => UntypedQuery;
    or: (filters: string) => UntypedQuery;
  } & PromiseLike<{ data: unknown[] | null }>;

  const untyped = supabase as unknown as { from: (table: string) => UntypedQuery };
  let query = untyped
    .from(table)
    .select(select)
    .order("created_at", { ascending: false })
    .limit(200);

  if (statusFilter) query = query.eq("status", statusFilter);
  if (q) {
    const safe = q.replaceAll("%", "");
    if (type === "shops") query = query.ilike("name", `%${safe}%`);
    if (type === "barbers") query = query.ilike("display_name", `%${safe}%`);
    if (type === "services") query = query.or(`name_en.ilike.%${safe}%,name_ar.ilike.%${safe}%`);
    if (type === "products") query = query.ilike("name", `%${safe}%`);
    if (type === "offers") query = query.ilike("title", `%${safe}%`);
    if (type === "styles") query = query.or(`name_en.ilike.%${safe}%,name_ar.ilike.%${safe}%`);
    if (type === "reels") query = query.ilike("caption", `%${safe}%`);
  }

  const { data: rows } = (await query) as { data: unknown[] | null };

  return (
    <PageFrame
      title="Content Status"
      subtitle="Clients should only see approved + active content. Use these controls to update status and activity flags."
      actions={
        <div className="flex items-center gap-2">
          <form>
            <input type="hidden" name="type" value={type} />
            <input type="hidden" name="status" value={statusFilter} />
            <Input name="q" defaultValue={q} placeholder="Search…" className="h-9 w-[220px]" />
          </form>
          <Button asChild variant="outline" size="sm">
            <Link href={`/admin/content-status?type=${encodeURIComponent(type)}`}>Clear</Link>
          </Button>
        </div>
      }
    >
      <div className="flex flex-col gap-4">
        {error ? <div className="rounded-lg border border-rose-500/30 bg-rose-500/10 px-3 py-2 text-sm text-rose-700">{error}</div> : null}

        <div className="flex flex-wrap gap-2">
          {tabs.map((t) => {
            const active = t.key === type;
            return (
              <Link
                key={t.key}
                href={`/admin/content-status?type=${encodeURIComponent(t.key)}`}
                className={cn(
                  "rounded-full border px-3 py-2 text-sm font-semibold",
                  active ? "border-primary bg-primary/10" : "border-border hover:bg-secondary/40"
                )}
              >
                {t.label}
              </Link>
            );
          })}
        </div>

        <div className="flex flex-wrap gap-2">
          {["", "pending", "approved", "hidden", "archived", "rejected", "draft"].map((s) => {
            const label = s ? s : "All";
            const active = s === statusFilter;
            return (
              <Link
                key={`status:${label}`}
                href={`/admin/content-status?type=${encodeURIComponent(type)}&q=${encodeURIComponent(q)}&status=${encodeURIComponent(s)}`}
                className={cn(
                  "rounded-full border px-3 py-2 text-xs font-semibold",
                  active ? "border-primary bg-primary/10" : "border-border hover:bg-secondary/40"
                )}
              >
                {label}
              </Link>
            );
          })}
        </div>

        <div className="grid gap-3">
          {(Array.isArray(rows) ? rows : []).map((r) => {
            const row = r as Record<string, unknown>;
            const id = String(row.id ?? "");
            const status = String(row.status ?? "");
            const isActive = Boolean(row.is_active ?? row.active ?? true);
            const title =
              type === "shops"
                ? String(row.name ?? "Shop")
                : type === "barbers"
                  ? String(row.display_name ?? "Barber")
                  : type === "services"
                    ? String(row.name_en ?? row.name_ar ?? "Service")
                    : type === "products"
                      ? String(row.name ?? "Product")
                      : type === "offers"
                        ? String(row.title ?? "Offer")
                        : type === "reviews"
                          ? `Review ${Number(row.rating ?? 0)}/5`
                          : type === "styles"
                            ? String(row.name_en ?? row.name_ar ?? "Style")
                            : String(row.caption ?? "Reel");
            const meta =
              type === "shops"
                ? String(row.area ?? "")
                : type === "barbers"
                  ? String(row.shop_id ?? "")
                  : type === "services"
                    ? String(row.shop_id ?? row.barber_id ?? "")
                    : type === "products"
                      ? String(row.shop_id ?? "")
                      : type === "offers"
                        ? String(row.shop_id ?? row.barber_id ?? "")
                        : type === "reviews"
                          ? `${String(row.target_type ?? "")}:${String(row.target_id ?? "")}`
                          : type === "styles"
                            ? String(row.category ?? "")
                            : String(row.deleted_at ? "deleted" : "");

            return (
              <div key={id} className="rounded-xl border border-border bg-white p-4">
                <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
                  <div className="min-w-0">
                    <div className="truncate text-sm font-semibold text-[#111111]">{title}</div>
                    <div className="truncate pt-1 text-xs text-muted-foreground">
                      {id}
                      {meta ? ` • ${meta}` : ""}
                    </div>
                    <div className="pt-2 flex flex-wrap items-center gap-2 text-xs">
                      <span className={cn("rounded-full border px-2 py-1 font-semibold", status === "approved" ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-700" : "border-border bg-secondary/40 text-muted-foreground")}>
                        {status || "—"}
                      </span>
                      <span className={cn("rounded-full border px-2 py-1 font-semibold", isActive ? "border-primary/30 bg-primary/10 text-[#111111]" : "border-rose-500/30 bg-rose-500/10 text-rose-700")}>
                        {isActive ? "active" : "inactive"}
                      </span>
                    </div>
                  </div>

                  <div className="flex flex-wrap items-center gap-2">
                    <form action={toggleActive}>
                      <input type="hidden" name="type" value={type} />
                      <input type="hidden" name="id" value={id} />
                      <input type="hidden" name="current" value={String(isActive)} />
                      <input type="hidden" name="return_type" value={type} />
                      <input type="hidden" name="return_q" value={q} />
                      <input type="hidden" name="return_status" value={statusFilter} />
                      <Button type="submit" variant="outline" size="sm">
                        {isActive ? "Deactivate" : "Activate"}
                      </Button>
                    </form>

                    {[
                      { action: "approve", label: "Approve" },
                      { action: "reject", label: "Reject" },
                      { action: "hide", label: "Hide" },
                      { action: "archive", label: "Archive" },
                      { action: "restore", label: "Restore" },
                      { action: "draft", label: "Draft" }
                    ].map((a) => (
                      <form key={`${id}:${a.action}`} action={updateStatus}>
                        <input type="hidden" name="type" value={type} />
                        <input type="hidden" name="id" value={id} />
                        <input type="hidden" name="action" value={a.action} />
                        <input type="hidden" name="return_type" value={type} />
                        <input type="hidden" name="return_q" value={q} />
                        <input type="hidden" name="return_status" value={statusFilter} />
                        <Button type="submit" variant="secondary" size="sm">
                          {a.label}
                        </Button>
                      </form>
                    ))}
                  </div>
                </div>
              </div>
            );
          })}
          {!rows?.length ? <div className="text-sm text-muted-foreground">No content found.</div> : null}
        </div>
      </div>
    </PageFrame>
  );
}

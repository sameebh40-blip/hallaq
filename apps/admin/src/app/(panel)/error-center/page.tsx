import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type Status = "open" | "fixed" | "ignored";

type LogRow = {
  id: string;
  severity: "info" | "warning" | "error" | "critical";
  status: Status;
  role: string | null;
  page: string | null;
  action: string | null;
  platform: string | null;
  device: string | null;
  error_message: string | null;
  stack_trace: string | null;
  created_at: string;
  profiles?: { full_name: string | null; email: string | null } | null;
};

function severityClass(sev: string) {
  switch (sev) {
    case "info":
      return "border-blue-500/30 bg-blue-500/10 text-blue-100";
    case "warning":
      return "border-yellow-500/30 bg-yellow-500/10 text-yellow-100";
    case "critical":
      return "border-red-500/30 bg-red-500/10 text-red-100";
    case "error":
    default:
      return "border-orange-500/30 bg-orange-500/10 text-orange-100";
  }
}

function statusClass(status: Status) {
  if (status === "fixed") return "border-emerald-500/25 bg-emerald-500/10 text-emerald-200";
  if (status === "ignored") return "border-white/10 bg-white/5 text-muted-foreground";
  return "border-amber-500/25 bg-amber-500/10 text-amber-100";
}

export default async function ErrorCenterPage({
  searchParams
}: {
  searchParams?: Promise<{ status?: string; error?: string }>;
}) {
  const sp = (await searchParams) ?? {};
  const status = (sp.status ?? "open").trim();
  const statusFilter: Status = status === "fixed" ? "fixed" : status === "ignored" ? "ignored" : "open";

  const supabase = await createSupabaseServerClient();

  async function setStatus(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "").trim();
    const nextStatus = String(formData.get("status") ?? "").trim() as Status;
    if (!id) redirect(`/error-center?status=${encodeURIComponent(statusFilter)}`);
    if (nextStatus !== "open" && nextStatus !== "fixed" && nextStatus !== "ignored") {
      redirect(`/error-center?status=${encodeURIComponent(statusFilter)}`);
    }

    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("system_logs").update({ status: nextStatus }).eq("id", id);
    if (error) redirect(`/error-center?status=${encodeURIComponent(statusFilter)}&error=${encodeURIComponent(error.message)}`);
    redirect(`/error-center?status=${encodeURIComponent(statusFilter)}`);
  }

  let q = supabase
    .from("system_logs")
    .select(
      "id, severity, status, role, page, action, platform, device, error_message, stack_trace, created_at, profiles:user_id(full_name,email)"
    )
    .order("created_at", { ascending: false })
    .limit(200);

  q = q.eq("status", statusFilter);

  const { data: rows, error: selectError } = await q;
  const logs = (rows ?? []) as unknown as LogRow[];

  const errorMsg = (sp.error ?? "").trim();
  const selectErrorMsg = (selectError?.message ?? "").trim();

  return (
    <PageFrame
      title="Error Center"
      subtitle="Every app error (real Supabase system_logs) with workflows: fixed / ignored / reopened."
      actions={
        <div className="flex items-center gap-2">
          <Button asChild size="sm" variant={statusFilter === "open" ? "secondary" : "ghost"}>
            <a href="/error-center?status=open">Open</a>
          </Button>
          <Button asChild size="sm" variant={statusFilter === "fixed" ? "secondary" : "ghost"}>
            <a href="/error-center?status=fixed">Fixed</a>
          </Button>
          <Button asChild size="sm" variant={statusFilter === "ignored" ? "secondary" : "ghost"}>
            <a href="/error-center?status=ignored">Ignored</a>
          </Button>
        </div>
      }
    >
      {errorMsg || selectErrorMsg ? (
        <LuxuryCard className="mb-4 border border-rose-500/25 bg-rose-500/10 p-4 text-sm text-rose-200">
          {errorMsg ? <div className="break-words">{errorMsg}</div> : null}
          {selectErrorMsg ? <div className="break-words">{selectErrorMsg}</div> : null}
        </LuxuryCard>
      ) : null}

      {logs.length ? (
        <div className="flex flex-col gap-3">
          {logs.map((l) => (
            <LuxuryCard key={l.id} className="border border-white/10 bg-white/5 p-4">
              <div className="flex flex-col gap-2">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <span className={`rounded-full border px-2.5 py-1 text-xs font-semibold ${severityClass(l.severity)}`}>
                      {l.severity.toUpperCase()}
                    </span>
                    <span className={`rounded-full border px-2.5 py-1 text-xs font-semibold ${statusClass(l.status)}`}>
                      {l.status.toUpperCase()}
                    </span>
                    <span className="text-xs text-muted-foreground">{new Date(l.created_at).toLocaleString()}</span>
                  </div>
                  <div className="break-words text-xs text-muted-foreground">
                    {(l.profiles?.full_name ?? "").trim() || (l.profiles?.email ?? "").trim() || ""}
                  </div>
                </div>

                <div className="grid grid-cols-1 gap-2 text-xs md:grid-cols-4">
                  <div>
                    <div className="text-[11px] text-muted-foreground">Role</div>
                    <div className="font-medium">{(l.role ?? "").trim() || "-"}</div>
                  </div>
                  <div>
                    <div className="text-[11px] text-muted-foreground">Platform</div>
                    <div className="font-medium">{(l.platform ?? "").trim() || "-"}</div>
                  </div>
                  <div>
                    <div className="text-[11px] text-muted-foreground">Device</div>
                    <div className="font-medium">{(l.device ?? "").trim() || "-"}</div>
                  </div>
                  <div>
                    <div className="text-[11px] text-muted-foreground">Page</div>
                    <div className="break-words font-medium">{(l.page ?? "").trim() || "-"}</div>
                  </div>
                </div>

                <div className="break-words text-sm font-medium">{(l.error_message ?? "").trim() || "No message"}</div>
                {l.action ? <div className="text-xs text-muted-foreground">Action: {l.action}</div> : null}
                {l.stack_trace ? (
                  <pre className="max-h-[260px] whitespace-pre-wrap break-words overflow-auto rounded-lg border border-white/10 bg-black/30 p-3 text-[11px] text-muted-foreground">
                    {l.stack_trace}
                  </pre>
                ) : null}

                <div className="flex flex-wrap gap-2 pt-1">
                  {l.status !== "fixed" ? (
                    <form action={setStatus}>
                      <input type="hidden" name="id" value={l.id} />
                      <input type="hidden" name="status" value="fixed" />
                      <Button type="submit" size="sm" variant="secondary">
                        Mark Fixed
                      </Button>
                    </form>
                  ) : null}
                  {l.status !== "ignored" ? (
                    <form action={setStatus}>
                      <input type="hidden" name="id" value={l.id} />
                      <input type="hidden" name="status" value="ignored" />
                      <Button type="submit" size="sm" variant="ghost">
                        Ignore
                      </Button>
                    </form>
                  ) : null}
                  {l.status !== "open" ? (
                    <form action={setStatus}>
                      <input type="hidden" name="id" value={l.id} />
                      <input type="hidden" name="status" value="open" />
                      <Button type="submit" size="sm" variant="ghost">
                        Reopen
                      </Button>
                    </form>
                  ) : null}
                </div>
              </div>
            </LuxuryCard>
          ))}
        </div>
      ) : (
        <div className="text-sm text-muted-foreground">No errors found for this status.</div>
      )}
    </PageFrame>
  );
}

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type LogRow = {
  id: string;
  severity: "info" | "warning" | "error" | "critical";
  role: string | null;
  page: string | null;
  action: string | null;
  error_message: string | null;
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

export default async function SystemLogsPage() {
  const supabase = await createSupabaseServerClient();

  const { data: rows } = await supabase
    .from("system_logs")
    .select("id, severity, role, page, action, error_message, created_at, profiles:user_id(full_name,email)")
    .order("created_at", { ascending: false })
    .limit(200);

  const logs = (rows ?? []) as unknown as LogRow[];

  return (
    <PageFrame title="System Logs" subtitle="Auth, upload, booking, routing, reels, storage, payment, and map errors.">
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
                    <span className="text-xs text-muted-foreground">
                      {new Date(l.created_at).toLocaleString()}
                    </span>
                  </div>
                  <div className="text-xs text-muted-foreground">
                    {(l.profiles?.full_name ?? "").trim() || (l.profiles?.email ?? "").trim() || ""}
                  </div>
                </div>

                <div className="grid grid-cols-1 gap-2 text-xs md:grid-cols-3">
                  <div>
                    <div className="text-[11px] text-muted-foreground">Role</div>
                    <div className="font-medium">{(l.role ?? "").trim() || "-"}</div>
                  </div>
                  <div>
                    <div className="text-[11px] text-muted-foreground">Page</div>
                    <div className="font-medium">{(l.page ?? "").trim() || "-"}</div>
                  </div>
                  <div>
                    <div className="text-[11px] text-muted-foreground">Action</div>
                    <div className="font-medium">{(l.action ?? "").trim() || "-"}</div>
                  </div>
                </div>

                <div className="text-sm font-medium">{(l.error_message ?? "").trim() || "No message"}</div>
              </div>
            </LuxuryCard>
          ))}
        </div>
      ) : (
        <div className="text-sm text-muted-foreground">No logs yet.</div>
      )}
    </PageFrame>
  );
}

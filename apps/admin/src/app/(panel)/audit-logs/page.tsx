import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type AuditRow = {
  id: string;
  action: string;
  target_type: string | null;
  target_id: string | null;
  created_at: string;
  profiles?: { full_name: string | null; email: string | null } | null;
};

export default async function AdminAuditLogsPage() {
  const supabase = await createSupabaseServerClient();

  const { data: rows } = await supabase
    .from("admin_audit_logs")
    .select("id, action, target_type, target_id, created_at, profiles:admin_profile_id(full_name,email)")
    .order("created_at", { ascending: false })
    .limit(200);

  const logs = (rows ?? []) as unknown as AuditRow[];

  return (
    <PageFrame title="Admin Audit Logs" subtitle="Every admin action is recorded here.">
      {logs.length ? (
        <div className="flex flex-col gap-3">
          {logs.map((l) => (
            <LuxuryCard key={l.id} className="border border-white/10 bg-white/5 p-4">
              <div className="flex flex-col gap-2">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="text-sm font-semibold">{l.action}</div>
                  <div className="text-xs text-muted-foreground">{new Date(l.created_at).toLocaleString()}</div>
                </div>
                <div className="grid grid-cols-1 gap-2 text-xs md:grid-cols-3">
                  <div>
                    <div className="text-[11px] text-muted-foreground">Actor</div>
                    <div className="font-medium">
                      {(l.profiles?.full_name ?? "").trim() || (l.profiles?.email ?? "").trim() || "-"}
                    </div>
                  </div>
                  <div>
                    <div className="text-[11px] text-muted-foreground">Entity</div>
                    <div className="font-medium">
                      {(l.target_type ?? "").trim() || "-"}
                      {l.target_id ? ` • ${l.target_id}` : ""}
                    </div>
                  </div>
                  <div>
                    <div className="text-[11px] text-muted-foreground">Log ID</div>
                    <div className="font-medium">{l.id}</div>
                  </div>
                </div>
              </div>
            </LuxuryCard>
          ))}
        </div>
      ) : (
        <div className="text-sm text-muted-foreground">No audit logs yet.</div>
      )}
    </PageFrame>
  );
}

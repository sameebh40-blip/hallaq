import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type AuditRow = {
  id: string;
  category: string;
  status: "ok" | "warning" | "broken" | string;
  detail: string;
  meta: Record<string, unknown> | null;
};

function statusClass(status: string) {
  if (status === "ok") return "border-emerald-500/25 bg-emerald-500/10 text-emerald-200";
  if (status === "warning") return "border-amber-500/25 bg-amber-500/10 text-amber-100";
  return "border-rose-500/25 bg-rose-500/10 text-rose-200";
}

export default async function SecurityCenterPage() {
  const supabase = await createSupabaseServerClient();
  const { data: rows, error } = await supabase.rpc("admin_security_audit");
  const items = (rows ?? []) as unknown as AuditRow[];

  return (
    <PageFrame title="Security Center" subtitle="RLS + policy checks with fix recommendations (via admin RPC).">
      {error ? (
        <LuxuryCard className="mb-4 border border-rose-500/25 bg-rose-500/10 p-4 text-sm text-rose-200">{error.message}</LuxuryCard>
      ) : null}

      {items.length ? (
        <div className="flex flex-col gap-3">
          {items.map((i) => (
            <LuxuryCard key={i.id} className="border border-white/10 bg-white/5 p-4">
              <div className="flex flex-col gap-2">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="text-sm font-semibold">{i.category}</div>
                  <span className={`rounded-full border px-2.5 py-1 text-xs font-semibold ${statusClass(i.status)}`}>
                    {String(i.status).toUpperCase()}
                  </span>
                </div>
                <div className="text-sm">{i.detail}</div>
                {i.meta ? (
                  <pre className="max-h-[280px] overflow-auto rounded-lg border border-white/10 bg-black/30 p-3 text-[11px] text-muted-foreground">
                    {JSON.stringify(i.meta, null, 2)}
                  </pre>
                ) : null}
              </div>
            </LuxuryCard>
          ))}
        </div>
      ) : (
        <div className="text-sm text-muted-foreground">No security issues detected.</div>
      )}
    </PageFrame>
  );
}


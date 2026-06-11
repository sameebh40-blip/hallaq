import { checkSupabaseConnection } from "@hallaq/supabase/health";
import { getSupabaseEnv } from "@hallaq/supabase/env";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

export const dynamic = "force-dynamic";

export default async function HealthPage() {
  const env = getSupabaseEnv();
  const status = await checkSupabaseConnection();

  return (
    <main className="mx-auto flex min-h-dvh max-w-lg flex-col justify-center px-4 py-12">
      <LuxuryCard className="p-6">
        <div className="flex flex-col gap-3">
          <div className="text-lg font-semibold">Health</div>
          <div className="text-sm text-muted-foreground">Supabase connectivity and configuration.</div>
          <div className="rounded-md border border-white/10 bg-white/5 p-3 text-sm">
            <div>Configured: {env.isConfigured ? "Yes" : "No"}</div>
            <div>Status: {status.ok ? "OK" : status.reason}</div>
          </div>
        </div>
      </LuxuryCard>
    </main>
  );
}


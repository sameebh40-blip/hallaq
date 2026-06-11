import { checkSupabaseConnection } from "@hallaq/supabase/health";
import { getSupabaseEnv } from "@hallaq/supabase/env";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

export const dynamic = "force-dynamic";

export default async function HealthPage() {
  const env = getSupabaseEnv();
  const status = await checkSupabaseConnection();
  let storageStatus: string = "Unknown";
  let serviceRoleKeyStatus: string = process.env.SUPABASE_SERVICE_ROLE_KEY ? "Loaded" : "Missing";
  try {
    const { createSupabaseAdminClient } = await import("@hallaq/supabase/admin");
    const admin = await createSupabaseAdminClient();
    serviceRoleKeyStatus = "Loaded";
    const { error } = await admin.storage.getBucket("reels");
    if (!error) {
      storageStatus = "Storage OK";
    } else {
      const { error: createError } = await admin.storage.createBucket("reels", { public: true });
      storageStatus = createError ? `Storage error: ${error.message}` : "Storage OK";
    }
  } catch (e) {
    storageStatus = e instanceof Error ? e.message : "Storage unavailable";
  }

  return (
    <main className="mx-auto flex min-h-dvh max-w-lg flex-col justify-center px-4 py-12">
      <LuxuryCard className="p-6">
        <div className="flex flex-col gap-3">
          <div className="text-lg font-semibold">Health</div>
          <div className="text-sm text-muted-foreground">Supabase connectivity and configuration.</div>
          <div className="rounded-md border border-white/10 bg-white/5 p-3 text-sm">
            <div>Configured: {env.isConfigured ? "Yes" : "No"}</div>
            <div>Status: {status.ok ? "OK" : status.reason}</div>
            <div>Service role key: {serviceRoleKeyStatus}</div>
            <div>{storageStatus}</div>
          </div>
          <div className="flex items-center justify-end">
            <Button asChild variant="ghost" size="sm">
              <a href="/bootstrap-admin">Bootstrap</a>
            </Button>
          </div>
        </div>
      </LuxuryCard>
    </main>
  );
}

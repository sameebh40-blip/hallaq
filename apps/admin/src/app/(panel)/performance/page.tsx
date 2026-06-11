import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

function formatBytes(bytes: number) {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  let v = bytes;
  let i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i += 1;
  }
  return `${v.toFixed(i === 0 ? 0 : 1)} ${units[i]}`;
}

type TableSizeRow = { table_name: string; size_bytes: number; row_estimate: number };

export default async function PerformancePage() {
  const supabase = await createSupabaseServerClient();

  const t0 = Date.now();
  await supabase.from("profiles").select("id").limit(1);
  const apiMs = Date.now() - t0;

  const { data: tableSizesRaw } = await supabase.rpc("admin_list_table_sizes", { p_limit: 30 });
  const tableSizes = (tableSizesRaw ?? []) as unknown as TableSizeRow[];

  const { data: perfEvents } = await supabase
    .from("analytics_events")
    .select("event_name, meta, created_at")
    .in("event_name", ["page_load", "slow_query", "slow_api", "image_load", "reel_load", "booking_load", "realtime_channels"])
    .order("created_at", { ascending: false })
    .limit(500);

  const slowEvents = (perfEvents ?? []).filter((e) => {
    const meta = (e.meta ?? {}) as Record<string, unknown>;
    const ms = Number(meta.ms ?? meta.duration_ms ?? meta.load_ms ?? 0);
    return Number.isFinite(ms) && ms > 800;
  });

  const heavyImages = (perfEvents ?? []).filter((e) => {
    if (e.event_name !== "image_load") return false;
    const meta = (e.meta ?? {}) as Record<string, unknown>;
    const kb = Number(meta.kb ?? meta.size_kb ?? 0);
    return Number.isFinite(kb) && kb > 500;
  });

  const longVideos = (perfEvents ?? []).filter((e) => {
    const meta = (e.meta ?? {}) as Record<string, unknown>;
    const sec = Number(meta.seconds ?? meta.duration_sec ?? 0);
    return Number.isFinite(sec) && sec > 30;
  });

  const tooManyRealtime = (perfEvents ?? []).filter((e) => {
    if (e.event_name !== "realtime_channels") return false;
    const meta = (e.meta ?? {}) as Record<string, unknown>;
    const channels = Number(meta.channels ?? 0);
    const subscriptions = Number(meta.subscriptions ?? 0);
    return (Number.isFinite(channels) && channels > 3) || (Number.isFinite(subscriptions) && subscriptions > 20);
  });

  return (
    <PageFrame
      title="Performance Center"
      subtitle="Live performance indicators. Data comes from real Supabase queries and analytics_events (if instrumented)."
    >
      <div className="grid grid-cols-1 gap-4">
        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="text-sm font-semibold">API Response Time</div>
          <div className="pt-1 text-2xl font-semibold tracking-tight">{apiMs} ms</div>
          <div className="pt-2 text-xs text-muted-foreground">Measured via a live profiles query from the admin server.</div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="text-sm font-semibold">Warnings</div>
          <div className="pt-2 grid grid-cols-1 gap-2 text-sm md:grid-cols-4">
            <div className="rounded-lg border border-white/10 bg-black/20 px-3 py-2">
              <div className="text-[11px] text-muted-foreground">Slow events (&gt; 800ms)</div>
              <div className="font-semibold">{slowEvents.length.toLocaleString()}</div>
            </div>
            <div className="rounded-lg border border-white/10 bg-black/20 px-3 py-2">
              <div className="text-[11px] text-muted-foreground">Heavy images (&gt; 500KB)</div>
              <div className="font-semibold">{heavyImages.length.toLocaleString()}</div>
            </div>
            <div className="rounded-lg border border-white/10 bg-black/20 px-3 py-2">
              <div className="text-[11px] text-muted-foreground">Long videos (&gt; 30s)</div>
              <div className="font-semibold">{longVideos.length.toLocaleString()}</div>
            </div>
            <div className="rounded-lg border border-white/10 bg-black/20 px-3 py-2">
              <div className="text-[11px] text-muted-foreground">Realtime overload</div>
              <div className="font-semibold">{tooManyRealtime.length.toLocaleString()}</div>
            </div>
          </div>
          <div className="pt-2 text-xs text-muted-foreground">
            To populate these, send timings into analytics_events with meta.ms/meta.kb/meta.seconds.
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="flex items-center justify-between">
            <div className="text-sm font-semibold">Largest Tables</div>
            <div className="text-xs text-muted-foreground">Top {tableSizes.length}</div>
          </div>
          {tableSizes.length ? (
            <div className="pt-3 grid grid-cols-1 gap-2 text-sm">
              {tableSizes.map((t) => (
                <div key={t.table_name} className="flex items-center justify-between gap-3 rounded-lg border border-white/10 bg-black/20 px-3 py-2">
                  <div className="font-medium">{t.table_name}</div>
                  <div className="text-xs text-muted-foreground">
                    {formatBytes(Number(t.size_bytes ?? 0))} • ~{Number(t.row_estimate ?? 0).toLocaleString()} rows
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="pt-3 text-sm text-muted-foreground">Table sizes unavailable (requires admin RPC).</div>
          )}
        </LuxuryCard>
      </div>
    </PageFrame>
  );
}

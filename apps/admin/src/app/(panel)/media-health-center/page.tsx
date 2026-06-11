import Link from "next/link";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type ScanRow = {
  asset_key: string;
  asset_url: string | null;
  bucket: string | null;
  path: string | null;
  is_active: boolean;
  updated_at: string;
};

type Issue = {
  asset_key: string;
  kind: "missing_file" | "broken_url" | "missing_url";
  detail: string;
};

async function headCheck(url: string) {
  try {
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), 5000);
    const res = await fetch(url, { method: "HEAD", redirect: "follow", signal: controller.signal });
    clearTimeout(t);
    return { ok: res.ok, status: res.status };
  } catch {
    return { ok: false, status: 0 };
  }
}

export default async function MediaHealthCenterPage() {
  const supabase = await createSupabaseServerClient();
  const { data: authData } = await supabase.auth.getUser();
  const userId = authData.user?.id ?? null;
  const profileRes = userId ? await supabase.from("profiles").select("role").eq("id", userId).maybeSingle() : { data: null, error: null };
  const role = profileRes.data?.role ?? null;

  const isAdmin = role === "admin";
  if (!isAdmin) {
    return (
      <PageFrame title="Media Health Center" subtitle="Admin-only media diagnostics.">
        <LuxuryCard className="border border-rose-500/25 bg-rose-500/10 p-4 text-sm text-rose-200">Not authorized.</LuxuryCard>
      </PageFrame>
    );
  }

  const admin = await createSupabaseAdminClient();

  async function clearBrandAsset(formData: FormData) {
    "use server";
    const assetKey = String(formData.get("asset_key") ?? "").trim();
    if (!assetKey) return;
    const admin = await createSupabaseAdminClient();
    await admin.from("brand_assets").update({ asset_url: null, bucket: null, path: null, is_active: false, updated_at: new Date().toISOString() }).eq("asset_key", assetKey);
  }

  const { data } = await admin
    .from("brand_assets")
    .select("asset_key, asset_url, bucket, path, is_active, updated_at")
    .order("asset_key", { ascending: true });

  const rows = (data ?? []) as ScanRow[];
  const issues: Issue[] = [];

  const candidates = rows.filter((r) => r.bucket === "brand-assets" && r.path);
  const sample = candidates.slice(0, 40);

  for (const r of sample) {
    if (!r.asset_url) {
      issues.push({ asset_key: r.asset_key, kind: "missing_url", detail: "No asset_url stored." });
      continue;
    }

    if (r.bucket && r.path) {
      const signed = await admin.storage.from(r.bucket).createSignedUrl(r.path, 60);
      if (signed.error) {
        issues.push({ asset_key: r.asset_key, kind: "missing_file", detail: signed.error.message });
        continue;
      }
    }

    const head = await headCheck(r.asset_url);
    if (!head.ok) {
      issues.push({ asset_key: r.asset_key, kind: "broken_url", detail: head.status ? `HTTP ${head.status}` : "Request failed" });
    }
  }

  const issueByKey = new Map<string, Issue[]>();
  for (const i of issues) {
    const list = issueByKey.get(i.asset_key) ?? [];
    list.push(i);
    issueByKey.set(i.asset_key, list);
  }

  return (
    <PageFrame
      title="Media Health Center"
      subtitle="Scans brand-assets storage references for missing files and broken URLs."
      actions={
        <div className="flex flex-wrap items-center gap-2">
          <Button asChild size="sm" variant="secondary">
            <Link href="/brand-assets">Brand Assets</Link>
          </Button>
          <Button asChild size="sm" variant="ghost">
            <Link href="/system-health">System Health</Link>
          </Button>
        </div>
      }
    >
      <LuxuryCard className="border border-white/10 bg-white/5 p-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-col gap-1">
            <div className="text-sm font-semibold">Brand Assets Scan</div>
            <div className="text-xs text-muted-foreground">Sampled {sample.length.toLocaleString()} assets</div>
          </div>
          <div className="text-xs text-muted-foreground">{issues.length.toLocaleString()} issues</div>
        </div>
      </LuxuryCard>

      <div className="mt-4 grid grid-cols-1 gap-3">
        {!issues.length ? (
          <LuxuryCard className="border border-emerald-500/25 bg-emerald-500/10 p-4 text-sm text-emerald-200">No issues detected in sampled assets.</LuxuryCard>
        ) : null}

        {rows
          .filter((r) => issueByKey.has(r.asset_key))
          .map((r) => {
            const list = issueByKey.get(r.asset_key) ?? [];
            return (
              <LuxuryCard key={r.asset_key} className="border border-white/10 bg-white/5 p-4">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="flex flex-col gap-1">
                    <div className="text-sm font-semibold">{r.asset_key}</div>
                    <div className="text-xs text-muted-foreground">{list.map((i) => i.kind).join(", ")}</div>
                  </div>
                  <div className="flex flex-wrap items-center gap-2">
                    <Button asChild size="sm" variant="secondary">
                      <Link href={`/brand-assets#${encodeURIComponent(r.asset_key)}`}>Open</Link>
                    </Button>
                    <form action={clearBrandAsset}>
                      <input type="hidden" name="asset_key" value={r.asset_key} />
                      <Button type="submit" size="sm" variant="ghost">
                        Clear
                      </Button>
                    </form>
                  </div>
                </div>
                <div className="mt-3 grid grid-cols-1 gap-2">
                  {list.map((i, idx) => (
                    <div key={`${i.kind}-${idx}`} className="rounded-lg border border-white/10 bg-black/20 px-3 py-2 text-xs text-muted-foreground">
                      {i.kind}: {i.detail}
                    </div>
                  ))}
                </div>
              </LuxuryCard>
            );
          })}
      </div>
    </PageFrame>
  );
}


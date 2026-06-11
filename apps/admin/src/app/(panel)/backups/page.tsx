import { redirect } from "next/navigation";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";
import { RestoreButton } from "@/app/(panel)/backups/restore-button";

export const dynamic = "force-dynamic";

type BackupRow = {
  id: string;
  backup_type: "database" | "storage" | "full";
  status: "queued" | "running" | "succeeded" | "failed";
  file_url: string | null;
  size_mb: number | null;
  created_at: string;
  error_message: string | null;
};

type RestoreRow = {
  id: string;
  status: "queued" | "running" | "succeeded" | "failed";
  created_at: string;
  finished_at: string | null;
  error_message: string | null;
  backup_log_id: string;
};

function statusClass(status: string) {
  switch (status) {
    case "succeeded":
      return "border-emerald-500/30 bg-emerald-500/10 text-emerald-100";
    case "failed":
      return "border-red-500/30 bg-red-500/10 text-red-100";
    case "running":
      return "border-blue-500/30 bg-blue-500/10 text-blue-100";
    case "queued":
    default:
      return "border-white/10 bg-white/5 text-muted-foreground";
  }
}

export default async function BackupsPage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) redirect("/auth/sign-in?next=/backups");

  const [{ data: rows }, { data: restoreRows }] = await Promise.all([
    supabase.from("backup_logs").select("*").order("created_at", { ascending: false }).limit(50),
    supabase.from("restore_jobs").select("id, status, created_at, finished_at, error_message, backup_log_id").order("created_at", { ascending: false }).limit(20)
  ]);
  const backups = (rows ?? []) as BackupRow[];
  const last = backups.find((b) => b.status === "succeeded") ?? backups[0] ?? null;
  const lastRestore = (restoreRows ?? [])[0] as RestoreRow | undefined;

  async function createBackup(formData: FormData) {
    "use server";

    const backupType = String(formData.get("backup_type") ?? "").trim() as BackupRow["backup_type"];
    if (backupType !== "database" && backupType !== "storage" && backupType !== "full") redirect("/backups");

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const actorId = user?.id ?? null;
    if (!user) redirect("/auth/sign-in?next=/backups");

    const { data: inserted, error: insertError } = await supabase
      .from("backup_logs")
      .insert({
        backup_type: backupType,
        status: "running",
        created_by: actorId
      })
      .select("id")
      .maybeSingle();
    if (insertError || !inserted?.id) redirect("/backups");

    const backupLogId = inserted.id as string;
    let admin: Awaited<ReturnType<typeof createSupabaseAdminClient>>;
    try {
      admin = await createSupabaseAdminClient();
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Backup failed.";
      await supabase.from("backup_logs").update({ status: "failed", error_message: msg }).eq("id", backupLogId);
      redirect("/backups");
    }

    const tables = [
      "profiles",
      "barbershops",
      "barbers",
      "services",
      "products",
      "bookings",
      "reviews",
      "reels",
      "portfolio_items",
      "offers",
      "payments",
      "notifications",
      "admin_settings"
    ] as const;

    const dumpTable = async (table: (typeof tables)[number]) => {
      const pageSize = 1000;
      const maxRows = 50000;
      const rows: unknown[] = [];
      let truncated = false;
      for (let from = 0; from < maxRows; from += pageSize) {
        const { data, error } = await admin.from(table).select("*").range(from, from + pageSize - 1);
        if (error) throw new Error(`${table}: ${error.message}`);
        rows.push(...(data ?? []));
        if ((data?.length ?? 0) < pageSize) break;
        if (rows.length >= maxRows) {
          truncated = true;
          break;
        }
      }
      return { rows, truncated };
    };

    const listBucket = async (bucket: string) => {
      const maxEntries = 20000;
      const entries: Array<{ bucket: string; path: string; metadata: unknown }> = [];
      const queue: string[] = [""];
      const seen = new Set<string>();
      while (queue.length && entries.length < maxEntries) {
        const prefix = queue.shift() ?? "";
        if (seen.has(prefix)) continue;
        seen.add(prefix);
        const { data, error } = await admin.storage.from(bucket).list(prefix, { limit: 1000 });
        if (error) throw new Error(`${bucket}: ${error.message}`);
        for (const item of data ?? []) {
          const anyItem = item as unknown as { name?: string; id?: string | null; metadata?: unknown; updated_at?: string | null };
          const name = String(anyItem.name ?? "").trim();
          if (!name) continue;
          const fullPath = prefix ? `${prefix}/${name}` : name;
          const isFolder = !anyItem.id && !anyItem.updated_at && anyItem.metadata == null;
          if (isFolder) {
            queue.push(fullPath);
            continue;
          }
          entries.push({ bucket, path: fullPath, metadata: anyItem.metadata ?? null });
          if (entries.length >= maxEntries) break;
        }
      }
      return { entries, truncated: entries.length >= maxEntries };
    };

    try {
      const now = new Date().toISOString().replaceAll(":", "-");
      const bucket = "backups";
      const out: Record<string, unknown> = { version: 1, created_at: new Date().toISOString(), type: backupType };
      if (backupType === "database" || backupType === "full") {
        const db: Record<string, unknown> = {};
        for (const t of tables) {
          db[t] = await dumpTable(t);
        }
        out.database = db;
      }
      if (backupType === "storage" || backupType === "full") {
        const buckets = ["avatars", "shop-images", "barber-images", "reels-media", "reels", "portfolio"];
        const storage: Record<string, unknown> = {};
        for (const b of buckets) {
          storage[b] = await listBucket(b);
        }
        out.storage = storage;
      }

      const body = JSON.stringify(out);
      const objectPath = `${backupType}/${now}.json`;
      const blob = new Blob([body], { type: "application/json" });
      const { error: uploadError } = await admin.storage.from(bucket).upload(objectPath, blob, {
        contentType: "application/json",
        upsert: false
      });
      if (uploadError) throw new Error(uploadError.message);

      const sizeMb = Number((Buffer.byteLength(body, "utf8") / (1024 * 1024)).toFixed(2));
      const { data: signed } = await admin.storage.from(bucket).createSignedUrl(objectPath, 60 * 60 * 24 * 30);
      const fileUrl = signed?.signedUrl ?? null;

      await supabase
        .from("backup_logs")
        .update({ status: "succeeded", file_url: fileUrl, object_path: objectPath, size_mb: sizeMb, error_message: null })
        .eq("id", backupLogId);
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Backup failed.";
      await supabase.from("backup_logs").update({ status: "failed", error_message: msg }).eq("id", backupLogId);
    }

    await Promise.allSettled([
      supabase.from("admin_activity_logs").insert({
        actor_profile_id: actorId,
        action: "backup_created",
        entity_type: "backup",
        entity_id: backupLogId,
        meta: { backupType, backupLogId }
      }),
      supabase.from("admin_audit_logs").insert({
        admin_profile_id: actorId,
        action: "backup_created",
        target_type: "backup",
        target_id: backupLogId,
        meta: { backupType, backupLogId }
      })
    ]);

    redirect("/backups");
  }

  return (
    <PageFrame
      title="Backups"
      subtitle="Backup status, history, and restore safety."
      actions={
        <div className="flex items-center gap-2">
          <Button asChild variant="secondary">
            <a href="/backups/report" target="_blank" rel="noreferrer">
              Download Backup Report
            </a>
          </Button>
        </div>
      }
    >
      <div className="grid grid-cols-1 gap-3 md:grid-cols-5">
        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="text-xs text-muted-foreground">Last backup date</div>
          <div className="pt-1 text-sm font-semibold">{last ? new Date(last.created_at).toLocaleString() : "-"}</div>
        </LuxuryCard>
        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="text-xs text-muted-foreground">Backup status</div>
          <div className="pt-1 text-sm font-semibold">{last?.status ?? "-"}</div>
        </LuxuryCard>
        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="text-xs text-muted-foreground">Backup size</div>
          <div className="pt-1 text-sm font-semibold">{typeof last?.size_mb === "number" ? `${last.size_mb} MB` : "-"}</div>
        </LuxuryCard>
        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="text-xs text-muted-foreground">Backup type</div>
          <div className="pt-1 text-sm font-semibold">{last?.backup_type ?? "-"}</div>
        </LuxuryCard>
        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="text-xs text-muted-foreground">Restore status</div>
          <div className="pt-1 text-sm font-semibold">{lastRestore?.status ?? "-"}</div>
        </LuxuryCard>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-2 md:grid-cols-3">
        <form action={createBackup}>
          <input type="hidden" name="backup_type" value="database" />
          <Button type="submit" className="h-11 w-full">
            Create Database Backup Now
          </Button>
        </form>
        <form action={createBackup}>
          <input type="hidden" name="backup_type" value="storage" />
          <Button type="submit" className="h-11 w-full" variant="secondary">
            Create Storage Backup Now
          </Button>
        </form>
        <form action={createBackup}>
          <input type="hidden" name="backup_type" value="full" />
          <Button type="submit" className="h-11 w-full" variant="secondary">
            Create Full Backup Now
          </Button>
        </form>
      </div>

      <div className="pt-6">
        <div className="text-sm font-semibold">Backup history</div>
        <div className="pt-2">
          {backups.length ? (
            <div className="flex flex-col gap-2">
              {backups.map((b) => (
                <LuxuryCard key={b.id} className="border border-white/10 bg-white/5 p-4">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <div className="flex items-center gap-2">
                      <span className={`rounded-full border px-2.5 py-1 text-xs font-semibold ${statusClass(b.status)}`}>
                        {b.status.toUpperCase()}
                      </span>
                      <span className="text-xs text-muted-foreground">{new Date(b.created_at).toLocaleString()}</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="text-xs text-muted-foreground">{b.backup_type}</div>
                      {b.status === "succeeded" ? <RestoreButton backupLogId={b.id} /> : null}
                    </div>
                  </div>
                  {b.error_message ? <div className="pt-2 text-xs text-red-200">{b.error_message}</div> : null}
                  {b.file_url ? (
                    <div className="pt-2 text-xs">
                      <a className="underline" href={b.file_url} target="_blank" rel="noreferrer">
                        File URL
                      </a>
                    </div>
                  ) : null}
                </LuxuryCard>
              ))}
            </div>
          ) : (
            <div className="text-sm text-muted-foreground">No backups yet.</div>
          )}
        </div>
      </div>
    </PageFrame>
  );
}

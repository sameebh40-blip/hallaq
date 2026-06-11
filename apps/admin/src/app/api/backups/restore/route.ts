import { NextResponse } from "next/server";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";

export const dynamic = "force-dynamic";

function parseBackupObjectPath(fileUrl: string) {
  const raw = String(fileUrl ?? "").trim();
  if (!raw) return null;
  if (raw.startsWith("backups:")) {
    const v = raw.slice("backups:".length).replace(/^\/+/, "");
    return v || null;
  }
  if (raw.startsWith("http://") || raw.startsWith("https://")) {
    try {
      const url = new URL(raw);
      const idx = url.pathname.indexOf("/backups/");
      if (idx >= 0) {
        const path = url.pathname.slice(idx + "/backups/".length);
        return decodeURIComponent(path.replace(/^\/+/, "")) || null;
      }
    } catch {
      return null;
    }
  }
  return null;
}

async function upsertInChunks(
  admin: Awaited<ReturnType<typeof createSupabaseAdminClient>>,
  table: string,
  rows: unknown[],
  onConflict: string
) {
  const chunkSize = 250;
  for (let i = 0; i < rows.length; i += chunkSize) {
    const chunk = rows.slice(i, i + chunkSize) as Record<string, unknown>[];
    const { error } = await admin.from(table).upsert(chunk, { onConflict });
    if (error) throw new Error(`${table}: ${error.message}`);
  }
}

export async function POST(req: Request) {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  let body: { backup_log_id?: string; confirm?: string } | null = null;
  try {
    body = (await req.json()) as { backup_log_id?: string; confirm?: string };
  } catch {
    return NextResponse.json({ error: "invalid_json" }, { status: 400 });
  }

  const backupLogId = String(body?.backup_log_id ?? "").trim();
  const confirm = String(body?.confirm ?? "").trim();
  if (!backupLogId) return NextResponse.json({ error: "invalid_backup_log_id" }, { status: 400 });
  if (confirm !== "RESTORE") return NextResponse.json({ error: "confirm_required" }, { status: 400 });

  const { data: restoreJob, error: insertError } = await supabase
    .from("restore_jobs")
    .insert({
      backup_log_id: backupLogId,
      status: "running",
      requested_by: user.id
    })
    .select("id")
    .maybeSingle();

  await Promise.allSettled([
    supabase.from("admin_activity_logs").insert({
      actor_profile_id: user.id,
      action: "restore_requested",
      entity_type: "backup",
      entity_id: backupLogId,
      meta: {}
    }),
    supabase.from("admin_audit_logs").insert({
      admin_profile_id: user.id,
      action: "restore_requested",
      target_type: "backup",
      target_id: backupLogId,
      meta: {}
    })
  ]);

  if (insertError || !restoreJob?.id) return NextResponse.json({ error: insertError?.message ?? "restore_job_failed" }, { status: 500 });

  const restoreJobId = restoreJob.id as string;

  try {
    const admin = await createSupabaseAdminClient();
    const { data: backup } = await supabase
      .from("backup_logs")
      .select("id, backup_type, status, file_url, object_path")
      .eq("id", backupLogId)
      .maybeSingle();

    const backupStatus = (backup as unknown as { status?: string | null }).status ?? null;
    const backupType = (backup as unknown as { backup_type?: string | null }).backup_type ?? null;
    const fileUrl = (backup as unknown as { file_url?: string | null }).file_url ?? null;
    const storedObjectPath = (backup as unknown as { object_path?: string | null }).object_path ?? null;

    if (backupStatus !== "succeeded" || !fileUrl) throw new Error("Selected backup is not ready to restore.");

    const objectPath = storedObjectPath || parseBackupObjectPath(fileUrl);
    if (!objectPath) throw new Error("Could not resolve backup object path.");

    const { data: blob, error: downloadError } = await admin.storage.from("backups").download(objectPath);
    if (downloadError || !blob) throw new Error(downloadError?.message ?? "Failed to download backup file.");

    const text = Buffer.from(await blob.arrayBuffer()).toString("utf8");
    const parsed = JSON.parse(text) as Record<string, unknown>;
    const db = parsed.database as Record<string, { rows?: unknown[] }> | undefined;

    if (backupType === "storage") {
      throw new Error("Storage-only restore is not supported by this in-app restore runner.");
    }
    if (!db || typeof db !== "object") {
      throw new Error("Backup file does not contain database data.");
    }

    const tableOrder = [
      "profiles",
      "barbershops",
      "barbers",
      "services",
      "products",
      "bookings",
      "payments",
      "reviews",
      "reels",
      "portfolio_items",
      "offers",
      "notifications",
      "admin_settings"
    ];

    const conflictKey: Record<string, string> = {
      admin_settings: "key"
    };

    for (const table of tableOrder) {
      const rows = (db[table]?.rows ?? []) as unknown[];
      if (!Array.isArray(rows) || rows.length === 0) continue;
      await upsertInChunks(admin, table, rows, conflictKey[table] ?? "id");
    }

    await supabase
      .from("restore_jobs")
      .update({ status: "succeeded", finished_at: new Date().toISOString(), error_message: null })
      .eq("id", restoreJobId);

    return NextResponse.json({ ok: true });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Restore failed.";
    await supabase
      .from("restore_jobs")
      .update({ status: "failed", finished_at: new Date().toISOString(), error_message: msg })
      .eq("id", restoreJobId);
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}

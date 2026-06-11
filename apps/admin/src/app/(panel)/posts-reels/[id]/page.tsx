import Link from "next/link";
import { notFound, redirect } from "next/navigation";

import { randomUUID } from "crypto";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";

import { MediaFileInput } from "@/components/media-file-input";
import { PageFrame } from "@/components/page-frame";
import { buildPreparedUploadPath, prepareImageFileForUpload, removeStorageObjectIfPresent } from "@/lib/media/prepare-image-upload";

export const dynamic = "force-dynamic";

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong.";
  if (m.toLowerCase().includes("bucket not found")) {
    return "Storage bucket not found. Run the storage migrations in Supabase to create the buckets.";
  }
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as an admin account.";
  }
  return m;
}

function parseStoragePublicUrl(url: string): { bucket: string; path: string } | null {
  try {
    const u = new URL(url);
    const marker = "/storage/v1/object/public/";
    const idx = u.pathname.indexOf(marker);
    if (idx === -1) return null;
    const rest = u.pathname.slice(idx + marker.length);
    const [bucket, ...pathParts] = rest.split("/").filter(Boolean);
    const path = pathParts.join("/");
    if (!bucket || !path) return null;
    return { bucket, path };
  } catch {
    return null;
  }
}

export default async function ReelDetailsPage({
  params,
  searchParams
}: {
  params: Promise<{ id: string }>;
  searchParams?: Promise<{ error?: string }>;
}) {
  const { id: reelId } = await params;
  const sp = searchParams ? await searchParams : undefined;
  const errorMessage = userFacingDbError((sp?.error ?? "").trim());
  const supabase = await createSupabaseServerClient();

  const { data: reel } = await supabase
    .from("posts")
    .select(
      "id, barber_id, shop_id, media_type, media_url, media_path, thumbnail_url, thumbnail_path, caption, location, status, is_featured, is_sponsored, created_at, deleted_at"
    )
    .eq("id", reelId)
    .maybeSingle();

  if (!reel) notFound();

  async function updateReel(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const caption = String(formData.get("caption") ?? "").trim();
    const location = String(formData.get("location") ?? "").trim();
    const status = String(formData.get("status") ?? "").trim();
    const rejectionReason = String(formData.get("rejection_reason") ?? "").trim();
    const thumbnailFile = formData.get("thumbnail_file");

    if (!id || !["draft", "pending", "approved", "hidden", "archived", "rejected"].includes(status)) redirect(`/posts-reels/${reelId}`);

    const currentReel = reel;
    if (!currentReel) redirect(`/posts-reels/${reelId}`);

    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;
    const existing = await supabase.from("posts").select("barber_id, shop_id").eq("id", id).maybeSingle();
    const authorType = existing.data?.barber_id ? "barbers" : "shops";
    const authorId = (existing.data?.barber_id ?? existing.data?.shop_id ?? "").trim();
    if (!authorId) redirect(`/posts-reels/${reelId}?error=${encodeURIComponent("Missing author.")}`);

    let thumbnailPath: string | null | undefined = undefined;
    if (thumbnailFile instanceof File && thumbnailFile.size > 0) {
      if (!(thumbnailFile.type ?? "").startsWith("image/")) redirect(`/posts-reels/${reelId}`);
      const preparedThumb = await prepareImageFileForUpload(thumbnailFile);
      const objectPath = buildPreparedUploadPath(
        `${authorType}/${authorId}/thumb-${randomUUID()}`,
        preparedThumb.fileName,
        preparedThumb.contentType
      );
      const admin = await createSupabaseAdminClient();
      const { error: uploadError } = await admin.storage
        .from("reels")
        .upload(objectPath, preparedThumb.bytes, { contentType: preparedThumb.contentType || "image/webp", upsert: true });
      if (uploadError) redirect(`/posts-reels/${reelId}?error=${encodeURIComponent(userFacingDbError(uploadError.message))}`);
      thumbnailPath = objectPath;
    }

    const statusPatch: Record<string, unknown> = {};
    if (status === "approved") {
      statusPatch.approved_by = actorId;
      statusPatch.approved_at = new Date().toISOString();
      statusPatch.rejected_by = null;
      statusPatch.rejected_at = null;
      statusPatch.rejection_reason = null;
    } else if (status === "rejected") {
      statusPatch.rejected_by = actorId;
      statusPatch.rejected_at = new Date().toISOString();
      statusPatch.rejection_reason = rejectionReason || null;
      statusPatch.approved_by = null;
      statusPatch.approved_at = null;
    } else {
      statusPatch.approved_by = null;
      statusPatch.approved_at = null;
      statusPatch.rejected_by = null;
      statusPatch.rejected_at = null;
      statusPatch.rejection_reason = null;
    }

    const { error: updateError } = await supabase
      .from("posts")
      .update({
        caption: caption || null,
        location: location || null,
        status,
        ...statusPatch,
        ...(thumbnailPath !== undefined ? { thumbnail_path: thumbnailPath, thumbnail_url: null } : {}),
      })
      .eq("id", id);
    if (updateError) redirect(`/posts-reels/${reelId}?error=${encodeURIComponent(userFacingDbError(updateError.message))}`);

    if (thumbnailPath !== undefined && thumbnailPath !== currentReel.thumbnail_path) {
      try {
        const admin = await createSupabaseAdminClient();
        await removeStorageObjectIfPresent(admin.storage, "reels", currentReel.thumbnail_path);
      } catch {}
    }

    redirect(`/posts-reels/${id}`);
  }

  async function deleteReel(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;
    const { error } = await supabase.from("posts").update({ deleted_at: new Date().toISOString() }).eq("id", id);
    if (error) redirect(`/posts-reels/${reelId}?error=${encodeURIComponent(userFacingDbError(error.message))}`);
    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "reel_soft_deleted",
      entity_type: "reel",
      entity_id: id,
      meta: {}
    });
    if (logError) redirect(`/posts-reels/${reelId}?error=${encodeURIComponent(userFacingDbError(logError.message))}`);
    redirect("/posts-reels?status=all");
  }

  async function restoreReel(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;
    const { error } = await supabase.from("posts").update({ deleted_at: null }).eq("id", id);
    if (error) redirect(`/posts-reels/${reelId}?error=${encodeURIComponent(userFacingDbError(error.message))}`);
    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "reel_restored",
      entity_type: "reel",
      entity_id: id,
      meta: {}
    });
    if (logError) redirect(`/posts-reels/${reelId}?error=${encodeURIComponent(userFacingDbError(logError.message))}`);
    redirect(`/posts-reels/${id}`);
  }

  async function permanentlyDeleteReel(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const { data: existing } = await supabase
      .from("posts")
      .select("media_url, media_path, thumbnail_url, thumbnail_path")
      .eq("id", id)
      .maybeSingle();
    const refs = [existing?.media_path, existing?.thumbnail_path, existing?.media_url, existing?.thumbnail_url].filter(Boolean) as string[];
    const admin = await createSupabaseAdminClient();
    for (const v of refs) {
      const ref = v.startsWith("http://") || v.startsWith("https://") ? parseStoragePublicUrl(v) : null;
      if (ref) {
        await admin.storage.from(ref.bucket).remove([ref.path]);
        continue;
      }
      for (const bucket of ["reels", "reels-media", "post-media"] as const) {
        await admin.storage.from(bucket).remove([v]);
      }
    }

    const { error: delError } = await supabase.from("posts").delete().eq("id", id);
    if (delError) redirect(`/posts-reels/${reelId}?error=${encodeURIComponent(userFacingDbError(delError.message))}`);
    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "reel_permanently_deleted",
      entity_type: "reel",
      entity_id: id,
      meta: {}
    });
    if (logError) redirect(`/posts-reels/${reelId}?error=${encodeURIComponent(userFacingDbError(logError.message))}`);

    redirect("/posts-reels?status=all");
  }

  return (
    <PageFrame
      title="Reel"
      subtitle="Edit reel fields."
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/posts-reels?status=all">Back</Link>
        </Button>
      }
    >
      {sp?.error ? (
        <div className="mb-4 rounded-xl border border-rose-500/20 bg-rose-500/10 px-4 py-3 text-sm text-rose-100">
          {errorMessage}
        </div>
      ) : null}
      <form action={updateReel} className="grid gap-4" encType="multipart/form-data">
        <input type="hidden" name="id" value={reel.id} />
        <div className="grid gap-2">
          <Label htmlFor="caption">Caption</Label>
          <Input id="caption" name="caption" defaultValue={reel.caption ?? ""} />
        </div>
        <div className="grid gap-2">
          <Label>Thumbnail</Label>
          <div className="rounded-lg border border-white/10 bg-white/5 p-3 text-xs text-muted-foreground break-all">
            {(reel.thumbnail_url ?? "").trim() || "—"}
          </div>
          <MediaFileInput name="thumbnail_file" accept="image/*" />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="location">Location</Label>
          <Input id="location" name="location" defaultValue={reel.location ?? ""} />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="status">Status</Label>
          <select
            id="status"
            name="status"
            defaultValue={reel.status ?? "pending"}
            className="flex h-10 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
          >
            <option value="draft">draft</option>
            <option value="pending">pending</option>
            <option value="approved">approved</option>
            <option value="hidden">hidden</option>
            <option value="archived">archived</option>
            <option value="rejected">rejected</option>
          </select>
        </div>
        <div className="grid gap-2">
          <Label htmlFor="rejection_reason">Rejection reason</Label>
          <Input id="rejection_reason" name="rejection_reason" placeholder="Optional" />
        </div>
        <div className="flex items-center justify-between gap-2 pt-2">
          <div className="text-xs text-muted-foreground">
            <div>id: {reel.id}</div>
            <div>author: {reel.barber_id ? `barber ${reel.barber_id}` : `shop ${reel.shop_id}`}</div>
            <div>media: {reel.media_type}</div>
            {reel.deleted_at ? (
              <div>deleted: {Intl.DateTimeFormat("en", { dateStyle: "medium" }).format(new Date(reel.deleted_at))}</div>
            ) : null}
          </div>
          <div className="flex items-center gap-2">
            {reel.deleted_at ? (
              <>
                <Button type="submit" variant="secondary" formAction={restoreReel}>
                  Restore
                </Button>
                <Button type="submit" variant="ghost" formAction={permanentlyDeleteReel}>
                  Permanently delete
                </Button>
              </>
            ) : (
              <Button type="submit" variant="ghost" formAction={deleteReel}>
                Delete
              </Button>
            )}
            <Button type="submit">Save</Button>
          </div>
        </div>
      </form>
    </PageFrame>
  );
}

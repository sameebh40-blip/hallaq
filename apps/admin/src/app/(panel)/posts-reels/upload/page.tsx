import Link from "next/link";
import { redirect } from "next/navigation";

import { randomUUID } from "crypto";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";

import { MediaFileInput } from "@/components/media-file-input";
import { PageFrame } from "@/components/page-frame";
import { buildPreparedUploadPath, prepareImageFileForUpload } from "@/lib/media/prepare-image-upload";
import { MAX_ADMIN_VIDEO_BYTES } from "@/lib/media/upload-constraints";
import { transcodeVideoToMp4_720p } from "@/lib/video/transcode-to-mp4";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

function isNextRedirect(error: unknown) {
  if (!error || typeof error !== "object") return false;
  const digest = "digest" in error ? (error as { digest?: unknown }).digest : undefined;
  if (typeof digest === "string" && digest.startsWith("NEXT_REDIRECT")) return true;
  const message = "message" in error ? (error as { message?: unknown }).message : undefined;
  return typeof message === "string" && message.toUpperCase().includes("NEXT_REDIRECT");
}

export default async function UploadReelPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const rawError = (params?.error ?? "").trim();
  const normalizedError = rawError.toLowerCase();
  const error =
    normalizedError.includes("bucket not found") || normalizedError.includes("storage bucket") || normalizedError.includes("no such bucket")
      ? "Storage bucket 'reels' not found. Run the latest Supabase migrations, then refresh this page."
      : normalizedError.includes("ffmpeg_not_available")
        ? "FFmpeg is not available on the admin server to compress this media. Install FFmpeg (or set FFMPEG_PATH) or upload a smaller file."
      : rawError;
  const showBucketFix = error.includes("reels") && error.includes("not found");

  const supabase = await createSupabaseServerClient();
  const { data: authUser } = await supabase.auth.getUser();
  const { data: currentProfile } = authUser.user
    ? await supabase.from("profiles").select("id, role").eq("id", authUser.user.id).maybeSingle()
    : { data: null };
  const supabaseHost = (() => {
    try {
      const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
      if (!url) return null;
      return new URL(url).host;
    } catch {
      return null;
    }
  })();

  const isSignedIn = Boolean(authUser.user);
  const isAdmin = currentProfile?.role === "admin";
  let hasServiceRoleKey = Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY);
  if (!hasServiceRoleKey) {
    try {
      await createSupabaseAdminClient();
      hasServiceRoleKey = true;
    } catch {
      hasServiceRoleKey = false;
    }
  }
  const [{ data: shops }, { data: barbers }] = await Promise.all([
    supabase.from("barbershops").select("id, name").order("created_at", { ascending: false }).limit(200),
    supabase.from("barbers").select("id, display_name").order("created_at", { ascending: false }).limit(200)
  ]);

  async function createReel(formData: FormData) {
    "use server";

    const authorType = String(formData.get("author_type") ?? "");
    const authorIdRaw = String(formData.get("author_id") ?? "").trim();
    const shopId = String(formData.get("shop_id") ?? "").trim();
    const barberId = String(formData.get("barber_id") ?? "").trim();
    const authorId = authorType === "shop" ? shopId || authorIdRaw : barberId || authorIdRaw;
    const mediaType = String(formData.get("media_type") ?? "video");
    const file = formData.get("file");
    const thumbnailFile = formData.get("thumbnail_file");
    const caption = String(formData.get("caption") ?? "").trim();
    const location = String(formData.get("location") ?? "").trim();

    if (!authorId || !(file instanceof File) || !["barber", "shop"].includes(authorType) || !["video", "image"].includes(mediaType)) {
      redirect(`/posts-reels/upload?error=${encodeURIComponent("Missing author or media file.")}`);
    }

    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;
    if (!actorId) {
      redirect(
        `/posts-reels/upload?error=${encodeURIComponent(
          "Not signed in. Please sign in again and retry the upload."
        )}`
      );
    }

    const { data: profile } = await supabase.from("profiles").select("role").eq("id", actorId).maybeSingle();
    const isAdminActor = profile?.role === "admin";
    if (!isAdminActor) {
      redirect(`/posts-reels/upload?error=${encodeURIComponent("Permission denied. Your profile is not an admin.")}`);
    }

    const ext = file.name.includes(".") ? file.name.split(".").pop() : undefined;
    const safeExt = ext ? `.${ext.toLowerCase()}` : "";
    const basePath = `${authorType === "shop" ? "shops" : "barbers"}/${authorId}/${randomUUID()}`;
    let objectPath = `${basePath}${safeExt}`;
    let bytes: Uint8Array = new Uint8Array(await file.arrayBuffer());
    let contentType = file.type;
    if (mediaType === "video") {
      bytes = await transcodeVideoToMp4_720p(bytes);
      if (bytes.byteLength > MAX_ADMIN_VIDEO_BYTES) {
        redirect(`/posts-reels/upload?error=${encodeURIComponent("Video is still too large after compression. Please choose a shorter video.")}`);
      }
      objectPath = `${basePath}.mp4`;
      contentType = "video/mp4";
    } else {
      const prepared = await prepareImageFileForUpload(file);
      bytes = prepared.bytes;
      contentType = prepared.contentType;
      objectPath = buildPreparedUploadPath(basePath, prepared.fileName, prepared.contentType);
    }

    let mediaPath: string | null = null;
    let thumbnailPath: string | null = null;
    let mediaUrl: string | null = null;
    let thumbnailUrl: string | null = null;
    let admin: Awaited<ReturnType<typeof createSupabaseAdminClient>> | null = null;
    try {
      admin = await createSupabaseAdminClient();
      const { error: getBucketError } = await admin.storage.getBucket("reels");
      if (getBucketError) redirect(`/posts-reels/upload?error=${encodeURIComponent(getBucketError.message)}`);

      const { error: uploadError } = await admin.storage
        .from("reels")
        .upload(objectPath, bytes, { contentType, upsert: true });
      if (uploadError) redirect(`/posts-reels/upload?error=${encodeURIComponent(uploadError.message)}`);

      mediaPath = objectPath;
      mediaUrl = admin.storage.from("reels").getPublicUrl(objectPath).data.publicUrl;

      if (mediaType === "image") {
        thumbnailPath = objectPath;
        thumbnailUrl = mediaUrl;
      } else if (thumbnailFile instanceof File && thumbnailFile.size > 0) {
        if (!(thumbnailFile.type ?? "").startsWith("image/")) {
          redirect(`/posts-reels/upload?error=${encodeURIComponent("Thumbnail must be an image.")}`);
        }
        const preparedThumb = await prepareImageFileForUpload(thumbnailFile);
        const thumbPath = buildPreparedUploadPath(
          `${authorType === "shop" ? "shops" : "barbers"}/${authorId}/thumb-${randomUUID()}`,
          preparedThumb.fileName,
          preparedThumb.contentType
        );
        const { error: thumbUploadError } = await admin.storage
          .from("reels")
          .upload(thumbPath, preparedThumb.bytes, { contentType: preparedThumb.contentType, upsert: true });
        if (thumbUploadError) redirect(`/posts-reels/upload?error=${encodeURIComponent(thumbUploadError.message)}`);
        thumbnailPath = thumbPath;
        thumbnailUrl = admin.storage.from("reels").getPublicUrl(thumbPath).data.publicUrl;
      }
    } catch (e) {
      if (isNextRedirect(e)) throw e;
      const message = e instanceof Error ? e.message : "Could not prepare this upload.";
      redirect(
        `/posts-reels/upload?error=${encodeURIComponent(
          `Upload blocked. Set SUPABASE_SERVICE_ROLE_KEY in apps/admin/.env.local or fix Storage policies. (${message})`
        )}`
      );
    }

    if (!mediaPath) redirect(`/posts-reels/upload?error=${encodeURIComponent("Could not prepare this upload.")}`);

    const payload: Record<string, unknown> = {
      media_type: mediaType,
      media_path: mediaPath,
      media_bucket: "reels",
      media_url: mediaUrl,
      ...(mediaType === "video" ? { video_url: mediaUrl } : {}),
      ...(mediaType === "image" ? { image_url: mediaUrl } : {}),
      thumbnail_path: thumbnailPath,
      thumbnail_bucket: "reels",
      thumbnail_url: thumbnailUrl,
      caption: caption || null,
      location: location || null,
      status: "approved",
      is_active: true,
      approved_by: actorId,
      approved_at: new Date().toISOString(),
    };

    if (authorType === "barber") payload.barber_id = authorId;
    if (authorType === "shop") payload.shop_id = authorId;

    try {
      const { data: inserted, error: insertError } = await supabase.from("posts").insert(payload).select("id").single();
      if (insertError) redirect(`/posts-reels/upload?error=${encodeURIComponent(insertError.message)}`);

      const { error: logError } = await supabase.from("admin_activity_logs").insert({
        actor_profile_id: actorId,
        action: "reel_uploaded",
        entity_type: "reel",
        entity_id: inserted?.id ?? null,
        meta: { author_type: authorType },
      });
      if (logError) redirect(`/posts-reels/upload?error=${encodeURIComponent(logError.message)}`);
    } catch (e) {
      if (isNextRedirect(e)) throw e;
      const message = e instanceof Error ? e.message : "Database write failed.";
      redirect(`/posts-reels/upload?error=${encodeURIComponent(message)}`);
    }

    redirect("/posts-reels?status=approved");
  }

  return (
    <PageFrame
      title="Upload Reel"
      subtitle="Upload image/video to Supabase Storage and publish to Explore."
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/posts-reels">Back</Link>
        </Button>
      }
    >
      {error ? (
        <div className="mb-4 grid gap-3 rounded-xl border border-rose-500/20 bg-rose-500/10 px-4 py-3 text-sm text-rose-100">
          <div>{error}</div>
          {showBucketFix ? (
            <div className="rounded-lg border border-rose-500/20 bg-black/20 px-3 py-2 text-xs text-rose-50/90">
              Run: supabase/migrations/0024_storage_buckets_bootstrap.sql
            </div>
          ) : null}
        </div>
      ) : null}
      {!isSignedIn || !isAdmin ? (
        <div className="mb-4 grid gap-1 rounded-xl border border-amber-500/20 bg-amber-500/10 px-4 py-3 text-sm text-amber-50">
          <div className="font-medium">Auth check</div>
          <div>Signed in: {isSignedIn ? "Yes" : "No"}</div>
          <div>Admin role: {isAdmin ? "Yes" : "No"}</div>
          <div>Service role key: {hasServiceRoleKey ? "Configured" : "Missing"}</div>
          {supabaseHost ? <div className="text-xs text-amber-50/80">Supabase: {supabaseHost}</div> : null}
        </div>
      ) : null}
      <form action={createReel} className="grid gap-4" encType="multipart/form-data">
        <div className="grid gap-2">
          <Label htmlFor="author_type">Author type</Label>
          <select
            id="author_type"
            name="author_type"
            defaultValue="shop"
            className="flex h-10 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
          >
            <option value="shop">Shop</option>
            <option value="barber">Barber</option>
          </select>
        </div>
        <div className="grid gap-2">
          <Label>Author</Label>
          {shops?.length ? (
            <select
              id="shop_id"
              name="shop_id"
              className="flex h-10 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
            >
              <option value="">Select a shop…</option>
              {shops.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name} • {s.id}
                </option>
              ))}
            </select>
          ) : null}

          {barbers?.length ? (
            <select
              id="barber_id"
              name="barber_id"
              className="flex h-10 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
            >
              <option value="">Select a barber…</option>
              {barbers.map((b) => (
                <option key={b.id} value={b.id}>
                  {b.display_name} • {b.id}
                </option>
              ))}
            </select>
          ) : null}

          <Input id="author_id" name="author_id" placeholder="Or paste UUID (barbershops.id / barbers.id)" />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="media_type">Media type</Label>
          <select
            id="media_type"
            name="media_type"
            defaultValue="video"
            className="flex h-10 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
          >
            <option value="video">Video</option>
            <option value="image">Image</option>
          </select>
        </div>
        <div className="grid gap-2">
          <Label>Media file</Label>
          <MediaFileInput name="file" accept="image/*,video/*" />
        </div>
        <div className="grid gap-2">
          <Label>Thumbnail (for video)</Label>
          <MediaFileInput name="thumbnail_file" accept="image/*" />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="caption">Caption</Label>
          <Input id="caption" name="caption" placeholder="Caption..." />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="location">Location</Label>
          <Input id="location" name="location" placeholder="Manama / Seef / ..." />
        </div>
        <div className="flex items-center justify-end gap-2 pt-2">
          <Button asChild variant="ghost">
            <Link href="/posts-reels">Cancel</Link>
          </Button>
          <Button type="submit">Upload</Button>
        </div>
      </form>
    </PageFrame>
  );
}

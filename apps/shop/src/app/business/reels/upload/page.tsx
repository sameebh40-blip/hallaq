import Link from "next/link";
import { redirect } from "next/navigation";

import { randomUUID } from "crypto";

import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { BusinessPageHeader } from "@/components/business/page-header";
import { MediaFileInput } from "@/components/media-file-input";
import { getMyShopContext } from "@/lib/my-shop-context";
import { createAppSupabaseServerClient } from "@/lib/supabase";
import { transcodeVideoToMp4_720p } from "@/lib/video/transcode-to-mp4";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export default async function BusinessReelsUploadPage() {
  const supabase = await createAppSupabaseServerClient();
  const ctx = await getMyShopContext(supabase);

  const shopId = ctx.shop?.id ?? null;
  if (!shopId) return <div className="text-sm text-muted-foreground">No shop assigned to this account.</div>;

  async function createPost(formData: FormData) {
    "use server";

    const MAX_IMAGE_BYTES = 15 * 1024 * 1024;
    const MAX_VIDEO_BYTES = 150 * 1024 * 1024;
    const mediaType = String(formData.get("media_type") ?? "image");
    const file = formData.get("file");
    const thumbnailFile = formData.get("thumbnail_file");
    const caption = String(formData.get("caption") ?? "").trim();
    const location = String(formData.get("location") ?? "").trim();

    if (!(file instanceof File) || !["image", "video"].includes(mediaType)) redirect("/business/reels/upload");
    if (mediaType === "image" && file.size > MAX_IMAGE_BYTES)
      redirect(`/business/reels/upload?error=${encodeURIComponent("Image is too large.")}`);
    if (mediaType === "video" && file.size > MAX_VIDEO_BYTES)
      redirect(`/business/reels/upload?error=${encodeURIComponent("Video is too large (max 150MB).")}`);
    if (mediaType === "video" && !(file.type ?? "").startsWith("video/"))
      redirect(`/business/reels/upload?error=${encodeURIComponent("Invalid video file.")}`);

    const supabase = await createAppSupabaseServerClient();
    const ctx = await getMyShopContext(supabase);
    if (!ctx.shop?.id) redirect("/business/reels/upload");

    const ext = file.name.includes(".") ? file.name.split(".").pop() : undefined;
    const safeExt = ext ? `.${ext.toLowerCase()}` : "";
    const basePath = `shops/${ctx.shop.id}/${randomUUID()}`;
    let objectPath = `${basePath}${safeExt}`;
    let bytes = new Uint8Array(await file.arrayBuffer());
    let contentType = file.type;
    if (mediaType === "video") {
      bytes = await transcodeVideoToMp4_720p(bytes, 20);
      if (bytes.byteLength > MAX_VIDEO_BYTES) redirect(`/business/reels/upload?error=${encodeURIComponent("Video is too large (max 150MB).")}`);
      objectPath = `${basePath}.mp4`;
      contentType = "video/mp4";
    }

    const { error: uploadError } = await supabase.storage.from("reels").upload(objectPath, bytes, { contentType, upsert: true });
    if (uploadError) redirect(`/business/reels/upload?error=${encodeURIComponent(uploadError.message)}`);

    const mediaPath = objectPath;
    const mediaUrl = supabase.storage.from("reels").getPublicUrl(mediaPath).data.publicUrl;
    let thumbnailPath: string | null = mediaType === "image" ? objectPath : null;
    let thumbnailUrl: string | null = mediaType === "image" ? mediaUrl : null;

    if (mediaType === "video" && thumbnailFile instanceof File && thumbnailFile.size > 0) {
      if (!(thumbnailFile.type ?? "").startsWith("image/")) redirect("/business/reels/upload");
      if (thumbnailFile.size > MAX_IMAGE_BYTES) redirect(`/business/reels/upload?error=${encodeURIComponent("Thumbnail is too large.")}`);
      const thumbExt = thumbnailFile.name.includes(".") ? thumbnailFile.name.split(".").pop() : undefined;
      const safeThumbExt = thumbExt ? `.${thumbExt.toLowerCase()}` : "";
      const thumbPath = `shops/${ctx.shop.id}/thumb-${randomUUID()}${safeThumbExt}`;
      const thumbBytes = new Uint8Array(await thumbnailFile.arrayBuffer());
      const { error: thumbUploadError } = await supabase.storage.from("reels").upload(thumbPath, thumbBytes, { contentType: thumbnailFile.type, upsert: true });
      if (thumbUploadError) redirect(`/business/reels/upload?error=${encodeURIComponent(thumbUploadError.message)}`);
      thumbnailPath = thumbPath;
      thumbnailUrl = supabase.storage.from("reels").getPublicUrl(thumbPath).data.publicUrl;
    }

    const { error: insertError } = await supabase.from("posts").insert({
      shop_id: ctx.shop.id,
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
      approved_by: null,
      approved_at: null,
      rejected_by: null,
      rejected_at: null,
      rejection_reason: null
    });
    if (insertError) redirect(`/business/reels/upload?error=${encodeURIComponent(insertError.message)}`);

    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;
    if (actorId) {
      await supabase.from("audit_events").insert({
        actor_profile_id: actorId,
        action: "reel_uploaded",
        entity_type: "reel",
        entity_id: null,
        meta: { shop_id: ctx.shop.id, media_type: mediaType }
      });
    }

    redirect("/business/reels");
  }

  return (
    <div className="grid gap-4">
      <BusinessPageHeader
        title="Upload Reel"
        subtitle="Post a new image or video reel. It will appear in the customer feed after refresh."
        actions={
          <Button asChild variant="ghost" size="sm">
            <Link href="/business/reels">Back</Link>
          </Button>
        }
      />

      <LuxuryCard className="p-5">
        <form action={createPost} className="grid gap-4" encType="multipart/form-data">
          <div className="grid gap-2">
            <Label htmlFor="media_type">Media type</Label>
            <select id="media_type" name="media_type" defaultValue="image" className="h-10 rounded-md border border-white/10 bg-white/5 px-3 text-sm">
              <option value="image">image</option>
              <option value="video">video</option>
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
              <Link href="/business/reels">Cancel</Link>
            </Button>
            <Button type="submit">Upload</Button>
          </div>
        </form>
      </LuxuryCard>
    </div>
  );
}

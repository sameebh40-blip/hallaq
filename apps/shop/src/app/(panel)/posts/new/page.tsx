import Link from "next/link";
import { redirect } from "next/navigation";

import { randomUUID } from "crypto";

import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";

import { MediaFileInput } from "@/components/media-file-input";
import { getMyShop } from "@/lib/my-shop";
import { createAppSupabaseServerClient } from "@/lib/supabase";
import { transcodeVideoToMp4_720p } from "@/lib/video/transcode-to-mp4";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export default async function NewPostPage() {
  const supabase = await createAppSupabaseServerClient();
  const shop = await getMyShop(supabase);

  if (!shop) {
    return <div className="text-sm text-muted-foreground">No shop assigned to this account.</div>;
  }

  async function createPost(formData: FormData) {
    "use server";

    const MAX_IMAGE_BYTES = 15 * 1024 * 1024;
    const MAX_VIDEO_BYTES = 150 * 1024 * 1024;
    const mediaType = String(formData.get("media_type") ?? "image");
    const file = formData.get("file");
    const thumbnailFile = formData.get("thumbnail_file");
    const caption = String(formData.get("caption") ?? "").trim();
    const location = String(formData.get("location") ?? "").trim();

    if (!(file instanceof File) || !["image", "video"].includes(mediaType)) redirect("/posts/new");
    if (mediaType === "image" && file.size > MAX_IMAGE_BYTES)
      redirect(`/posts/new?error=${encodeURIComponent("Image is too large.")}`);
    if (mediaType === "video" && file.size > MAX_VIDEO_BYTES)
      redirect(`/posts/new?error=${encodeURIComponent("Video is too large (max 150MB).")}`);
    if (mediaType === "video" && !(file.type ?? "").startsWith("video/")) redirect(`/posts/new?error=${encodeURIComponent("Invalid video file.")}`);

    const supabase = await createAppSupabaseServerClient();
    const shop = await getMyShop(supabase);
    if (!shop) redirect("/posts/new");
    const ext = file.name.includes(".") ? file.name.split(".").pop() : undefined;
    const safeExt = ext ? `.${ext.toLowerCase()}` : "";
    const basePath = `shops/${shop.id}/${randomUUID()}`;
    let objectPath = `${basePath}${safeExt}`;
    let bytes = new Uint8Array(await file.arrayBuffer());
    let contentType = file.type;
    if (mediaType === "video") {
      bytes = await transcodeVideoToMp4_720p(bytes, 20);
      if (bytes.byteLength > MAX_VIDEO_BYTES)
        redirect(`/posts/new?error=${encodeURIComponent("Video is too large (max 150MB).")}`);
      objectPath = `${basePath}.mp4`;
      contentType = "video/mp4";
    }

    const { error: uploadError } = await supabase.storage
      .from("reels")
      .upload(objectPath, bytes, { contentType, upsert: true });
    if (uploadError) redirect(`/posts/new?error=${encodeURIComponent(uploadError.message)}`);

    const mediaPath = objectPath;
    const mediaUrl = supabase.storage.from("reels").getPublicUrl(mediaPath).data.publicUrl;
    let thumbnailPath: string | null = mediaType === "image" ? objectPath : null;
    let thumbnailUrl: string | null = mediaType === "image" ? mediaUrl : null;

    if (mediaType === "video" && thumbnailFile instanceof File && thumbnailFile.size > 0) {
      if (!(thumbnailFile.type ?? "").startsWith("image/")) redirect("/posts/new");
      if (thumbnailFile.size > MAX_IMAGE_BYTES)
        redirect(`/posts/new?error=${encodeURIComponent("Thumbnail is too large.")}`);
      const thumbExt = thumbnailFile.name.includes(".") ? thumbnailFile.name.split(".").pop() : undefined;
      const safeThumbExt = thumbExt ? `.${thumbExt.toLowerCase()}` : "";
      const thumbPath = `shops/${shop.id}/thumb-${randomUUID()}${safeThumbExt}`;
      const thumbBytes = new Uint8Array(await thumbnailFile.arrayBuffer());
      const { error: thumbUploadError } = await supabase.storage
        .from("reels")
        .upload(thumbPath, thumbBytes, { contentType: thumbnailFile.type, upsert: true });
      if (thumbUploadError) redirect(`/posts/new?error=${encodeURIComponent(thumbUploadError.message)}`);
      thumbnailPath = thumbPath;
      thumbnailUrl = supabase.storage.from("reels").getPublicUrl(thumbPath).data.publicUrl;
    }

    const { error: insertError } = await supabase.from("posts").insert({
      shop_id: shop.id,
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
      rejection_reason: null,
    });
    if (insertError) redirect(`/posts/new?error=${encodeURIComponent(insertError.message)}`);

    redirect("/posts");
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-4">
        <div className="text-lg font-semibold">Create post</div>
        <Button asChild variant="ghost" size="sm">
          <Link href="/posts">Back</Link>
        </Button>
      </div>

      <form action={createPost} className="grid gap-4" encType="multipart/form-data">
        <div className="grid gap-2">
          <Label htmlFor="media_type">Media type</Label>
          <select
            id="media_type"
            name="media_type"
            defaultValue="image"
            className="flex h-10 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
          >
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
            <Link href="/posts">Cancel</Link>
          </Button>
          <Button type="submit">Create</Button>
        </div>
      </form>
    </div>
  );
}

import Link from "next/link";
import { notFound, redirect } from "next/navigation";

import { randomUUID } from "crypto";

import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";

import { MediaFileInput } from "@/components/media-file-input";
import { getMyShop } from "@/lib/my-shop";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

export default async function ShopPostDetailsPage({ params }: { params: Promise<{ id: string }> }) {
  const { id: postId } = await params;
  const supabase = await createAppSupabaseServerClient();
  const shop = await getMyShop(supabase);

  if (!shop) {
    return <div className="text-sm text-muted-foreground">No shop assigned to this account.</div>;
  }

  const { data: reel } = await supabase
    .from("posts")
    .select("id, shop_id, media_type, media_url, media_path, thumbnail_url, thumbnail_path, caption, location, status, created_at")
    .eq("id", postId)
    .is("deleted_at", null)
    .maybeSingle();

  if (!reel || reel.shop_id !== shop.id) notFound();

  async function save(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const caption = String(formData.get("caption") ?? "").trim();
    const location = String(formData.get("location") ?? "").trim();
    const thumbnailFile = formData.get("thumbnail_file");

    const supabase = await createAppSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    let thumbnailPath: string | null | undefined = undefined;
    let thumbnailUrl: string | null | undefined = undefined;
    if (thumbnailFile instanceof File && thumbnailFile.size > 0) {
      if (!(thumbnailFile.type ?? "").startsWith("image/")) redirect(`/posts/${id}`);
      const shop = await getMyShop(supabase);
      if (!shop) redirect(`/posts/${id}`);
      const ext = thumbnailFile.name.includes(".") ? thumbnailFile.name.split(".").pop() : undefined;
      const safeExt = ext ? `.${ext.toLowerCase()}` : "";
      const objectPath = `shops/${shop.id}/thumbnails/${id}/${randomUUID()}${safeExt}`;
      const bytes = new Uint8Array(await thumbnailFile.arrayBuffer());
      const { error: uploadError } = await supabase.storage
        .from("reels")
        .upload(objectPath, bytes, { contentType: thumbnailFile.type || "image/jpeg", upsert: true });
      if (uploadError) redirect(`/posts/${id}?error=${encodeURIComponent(uploadError.message)}`);
      thumbnailPath = objectPath;
      thumbnailUrl = objectPath;
    }

    const { error: updateError } = await supabase
      .from("posts")
      .update({
        caption: caption || null,
        location: location || null,
        status: "approved",
        ...(thumbnailPath !== undefined ? { thumbnail_path: thumbnailPath, thumbnail_url: thumbnailUrl ?? null } : {}),
      })
      .eq("id", id);
    if (updateError) redirect(`/posts/${id}?error=${encodeURIComponent(updateError.message)}`);
    if (actorId) {
      await supabase.from("audit_events").insert({
        actor_profile_id: actorId,
        action: "reel_updated",
        entity_type: "reel",
        entity_id: id,
        meta: { status: "approved" }
      });
    }

    redirect(`/posts/${id}`);
  }

  async function deletePost(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const supabase = await createAppSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;
    await supabase.from("posts").update({ deleted_at: new Date().toISOString() }).eq("id", id);
    if (actorId) {
      await supabase.from("audit_events").insert({
        actor_profile_id: actorId,
        action: "reel_soft_deleted",
        entity_type: "reel",
        entity_id: id,
        meta: {}
      });
    }
    redirect("/posts");
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-4">
        <div className="text-lg font-semibold">Edit post</div>
        <Button asChild variant="ghost" size="sm">
          <Link href="/posts">Back</Link>
        </Button>
      </div>

      <form action={save} className="grid gap-4" encType="multipart/form-data">
        <input type="hidden" name="id" value={reel.id} />
        <div className="grid gap-2">
          <Label>Media</Label>
          <div className="rounded-lg border border-white/10 bg-white/5 p-3 text-xs text-muted-foreground">
            {reel.media_type} • {(reel.media_path ?? reel.media_url ?? "").trim()}
          </div>
        </div>
        <div className="grid gap-2">
          <Label>Thumbnail</Label>
          <div className="rounded-lg border border-white/10 bg-white/5 p-3 text-xs text-muted-foreground">
            {(reel.thumbnail_path ?? reel.thumbnail_url ?? "").trim() || "—"}
          </div>
          <MediaFileInput name="thumbnail_file" accept="image/*" />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="caption">Caption</Label>
          <Input id="caption" name="caption" defaultValue={reel.caption ?? ""} />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="location">Location</Label>
          <Input id="location" name="location" defaultValue={reel.location ?? ""} />
        </div>
        <div className="flex items-center justify-between gap-2 pt-2">
          <div className="text-xs text-muted-foreground">status: {reel.status}</div>
          <div className="flex items-center gap-2">
            <Button type="submit" variant="ghost" formAction={deletePost}>
              Delete
            </Button>
            <Button type="submit">Save</Button>
          </div>
        </div>
      </form>
    </div>
  );
}

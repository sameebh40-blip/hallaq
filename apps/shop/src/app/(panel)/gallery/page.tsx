import Link from "next/link";
import { redirect } from "next/navigation";
import { randomUUID } from "crypto";

import { parsePublicStorageUrl, signedOrUrl } from "@hallaq/supabase/storage";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";

import { MediaFileInput } from "@/components/media-file-input";
import { SafeImage } from "@/components/safe-image";
import { getMyShop } from "@/lib/my-shop";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong.";
  if (m.toLowerCase().includes("bucket not found")) {
    return "Storage bucket not found. Run the storage migrations in Supabase to create the buckets.";
  }
  if (m.toLowerCase().includes("column") && m.toLowerCase().includes("does not exist")) {
    return "Your Supabase database schema is missing required columns. Apply the Supabase migrations then try again.";
  }
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as the shop owner account.";
  }
  return m;
}

export default async function ShopGalleryPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((params?.error ?? "").trim());

  const supabase = await createAppSupabaseServerClient();
  const shop = await getMyShop(supabase);

  if (!shop) {
    return <div className="text-sm text-muted-foreground">No shop assigned to this account.</div>;
  }

  const { data: items } = await supabase
    .from("portfolio_items")
    .select("id, owner_type, owner_id, media_type, media_url, media_path, thumbnail_url, thumbnail_path, caption, created_at")
    .eq("owner_type", "shop")
    .eq("owner_id", shop.id)
    .order("created_at", { ascending: false })
    .limit(100);

  const signedItems = await Promise.all(
    (items ?? []).map(async (it) => {
      const thumb = await signedOrUrl(supabase, "portfolio", it.thumbnail_path ?? it.thumbnail_url);
      const media = await signedOrUrl(supabase, "portfolio", it.media_path ?? it.media_url);
      return { ...it, signedThumb: thumb, signedMedia: media };
    })
  );

  async function upload(formData: FormData) {
    "use server";

    const caption = String(formData.get("caption") ?? "").trim();
    const file = formData.get("file");

    if (!(file instanceof File) || file.size === 0) redirect("/gallery");
    if (!(file.type ?? "").startsWith("image/")) {
      redirect(`/gallery?error=${encodeURIComponent("Only images are supported for the gallery.")}`);
    }

    const supabase = await createAppSupabaseServerClient();
    const shop = await getMyShop(supabase);
    if (!shop) redirect(`/gallery?error=${encodeURIComponent("No shop assigned to this account.")}`);

    const ext = file.name.includes(".") ? file.name.split(".").pop() : undefined;
    const safeExt = ext ? `.${ext.toLowerCase()}` : "";
    const objectPath = `shops/${shop.id}/${randomUUID()}${safeExt}`;
    const bytes = new Uint8Array(await file.arrayBuffer());

    const { error: uploadError } = await supabase.storage
      .from("portfolio")
      .upload(objectPath, bytes, { contentType: file.type || "image/jpeg", upsert: true });
    if (uploadError) redirect(`/gallery?error=${encodeURIComponent(uploadError.message)}`);

    const { error: insertError } = await supabase.from("portfolio_items").insert({
      owner_type: "shop",
      owner_id: shop.id,
      media_type: "image",
      media_path: objectPath,
      media_url: objectPath,
      thumbnail_path: null,
      thumbnail_url: null,
      caption: caption || null,
    });

    if (insertError) redirect(`/gallery?error=${encodeURIComponent(insertError.message)}`);
    redirect("/gallery");
  }

  async function remove(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "").trim();
    const mediaPath = String(formData.get("media_path") ?? "").trim();
    const mediaUrl = String(formData.get("media_url") ?? "").trim();
    if (!id) redirect("/gallery");

    const supabase = await createAppSupabaseServerClient();
    const shop = await getMyShop(supabase);
    if (!shop) redirect(`/gallery?error=${encodeURIComponent("No shop assigned to this account.")}`);

    const { error: delError } = await supabase
      .from("portfolio_items")
      .delete()
      .eq("id", id)
      .eq("owner_type", "shop")
      .eq("owner_id", shop.id);

    if (delError) redirect(`/gallery?error=${encodeURIComponent(delError.message)}`);

    const objectPath = mediaPath || (() => {
      const ref = parsePublicStorageUrl(mediaUrl);
      return ref && ref.bucket === "portfolio" ? ref.path : "";
    })();
    if (objectPath) {
      await supabase.storage.from("portfolio").remove([objectPath]);
    }

    redirect("/gallery");
  }

  return (
    <div className="flex flex-col gap-5">
      <div className="flex items-center justify-between gap-4">
        <div className="text-lg font-semibold">Gallery</div>
        <Button asChild variant="ghost" size="sm">
          <Link href="/profile">Profile</Link>
        </Button>
      </div>

      {params?.error ? (
        <div className="rounded-xl border border-rose-500/20 bg-rose-500/10 px-4 py-3 text-sm text-rose-100">{error}</div>
      ) : null}

      <form action={upload} className="grid gap-4" encType="multipart/form-data">
        <div className="grid gap-2">
          <Label>Image</Label>
          <MediaFileInput name="file" accept="image/*" />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="caption">Caption (optional)</Label>
          <Input id="caption" name="caption" placeholder="New cut, interior, team, ..." />
        </div>
        <div className="flex items-center justify-end gap-2">
          <Button type="submit">Upload</Button>
        </div>
      </form>

      <div className="grid gap-3">
        <div className="text-sm font-medium">Current gallery</div>
        {signedItems.length ? (
          <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
            {signedItems.map((it) => (
              <div key={it.id} className="overflow-hidden rounded-xl border border-white/10 bg-white/5">
                <div className="aspect-video w-full overflow-hidden bg-black/20">
                  <SafeImage
                    src={it.signedThumb ?? it.signedMedia}
                    fallbackKey="empty_state_image"
                    sizes="(max-width: 768px) 100vw, 33vw"
                    className="h-full w-full object-cover"
                  />
                </div>
                <div className="grid gap-2 p-3">
                  <div className="text-xs text-muted-foreground">{(it.caption ?? "").trim() || "—"}</div>
                  <form action={remove}>
                    <input type="hidden" name="id" value={it.id} />
                    <input type="hidden" name="media_path" value={it.media_path ?? ""} />
                    <input type="hidden" name="media_url" value={it.media_url ?? ""} />
                    <Button type="submit" variant="ghost" size="sm">
                      Delete
                    </Button>
                  </form>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="rounded-xl border border-white/10 bg-white/5 p-4 text-sm text-muted-foreground">No gallery images yet.</div>
        )}
      </div>
    </div>
  );
}

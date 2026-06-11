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

type PortfolioItemRow = {
  id: string;
  owner_type: string;
  owner_id: string;
  media_url: string;
  media_path?: string | null;
  caption: string | null;
  created_at: string;
};

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong.";
  if (m.toLowerCase().includes("bucket not found")) {
    return "Storage bucket not found. Run the storage migrations in Supabase to create the buckets.";
  }
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as the shop owner account.";
  }
  return m;
}

export default async function BarberPortfolioPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string; barber?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((params?.error ?? "").trim());

  const supabase = await createAppSupabaseServerClient();
  const shop = await getMyShop(supabase);
  if (!shop) return <div className="text-sm text-muted-foreground">No shop assigned to this account.</div>;

  const { data: barbers } = await supabase
    .from("barbers")
    .select("id, display_name")
    .eq("shop_id", shop.id)
    .order("display_name", { ascending: true })
    .limit(200);

  const selectedBarberId = (params?.barber ?? "").trim() || (barbers?.[0]?.id ?? "");

  const { data: items } = selectedBarberId
    ? await supabase
        .from("portfolio_items")
        .select("id, owner_type, owner_id, media_url, media_path, caption, created_at")
        .eq("owner_type", "barber")
        .eq("owner_id", selectedBarberId)
        .order("created_at", { ascending: false })
        .limit(100)
    : { data: [] as PortfolioItemRow[] };

  const signedItems = await Promise.all(
    (items ?? []).map(async (it) => {
      const media = await signedOrUrl(supabase, "portfolio", it.media_path ?? it.media_url);
      return { ...it, signedMedia: media };
    })
  );

  async function upload(formData: FormData) {
    "use server";

    const barberId = String(formData.get("barber_id") ?? "").trim();
    const caption = String(formData.get("caption") ?? "").trim();
    const file = formData.get("file");

    if (!barberId) redirect("/barber-portfolio");
    if (!(file instanceof File) || file.size === 0) redirect(`/barber-portfolio?barber=${encodeURIComponent(barberId)}`);
    if (!(file.type ?? "").startsWith("image/")) {
      redirect(`/barber-portfolio?barber=${encodeURIComponent(barberId)}&error=${encodeURIComponent("Only images are supported.")}`);
    }

    const supabase = await createAppSupabaseServerClient();
    const shop = await getMyShop(supabase);
    if (!shop) redirect(`/barber-portfolio?error=${encodeURIComponent("No shop assigned to this account.")}`);

    const ext = file.name.includes(".") ? file.name.split(".").pop() : undefined;
    const safeExt = ext ? `.${ext.toLowerCase()}` : "";
    const objectPath = `barbers/${barberId}/${randomUUID()}${safeExt}`;
    const bytes = new Uint8Array(await file.arrayBuffer());

    const { error: uploadError } = await supabase.storage
      .from("portfolio")
      .upload(objectPath, bytes, { contentType: file.type || "image/jpeg", upsert: true });
    if (uploadError) {
      redirect(`/barber-portfolio?barber=${encodeURIComponent(barberId)}&error=${encodeURIComponent(uploadError.message)}`);
    }

    const { error: insertError } = await supabase.from("portfolio_items").insert({
      owner_type: "barber",
      owner_id: barberId,
      media_type: "image",
      media_path: objectPath,
      media_url: objectPath,
      caption: caption || null
    });

    if (insertError) {
      redirect(`/barber-portfolio?barber=${encodeURIComponent(barberId)}&error=${encodeURIComponent(insertError.message)}`);
    }
    redirect(`/barber-portfolio?barber=${encodeURIComponent(barberId)}`);
  }

  async function remove(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "").trim();
    const barberId = String(formData.get("barber_id") ?? "").trim();
    const mediaPath = String(formData.get("media_path") ?? "").trim();
    const mediaUrl = String(formData.get("media_url") ?? "").trim();
    if (!id || !barberId) redirect("/barber-portfolio");

    const supabase = await createAppSupabaseServerClient();
    const shop = await getMyShop(supabase);
    if (!shop) redirect(`/barber-portfolio?error=${encodeURIComponent("No shop assigned to this account.")}`);

    const { error: delError } = await supabase
      .from("portfolio_items")
      .delete()
      .eq("id", id)
      .eq("owner_type", "barber")
      .eq("owner_id", barberId);

    if (delError) {
      redirect(`/barber-portfolio?barber=${encodeURIComponent(barberId)}&error=${encodeURIComponent(delError.message)}`);
    }

    const objectPath = mediaPath || (() => {
      const ref = parsePublicStorageUrl(mediaUrl);
      return ref && ref.bucket === "portfolio" ? ref.path : "";
    })();
    if (objectPath) {
      await supabase.storage.from("portfolio").remove([objectPath]);
    }

    redirect(`/barber-portfolio?barber=${encodeURIComponent(barberId)}`);
  }

  return (
    <div className="flex flex-col gap-5">
      {params?.error ? (
        <div className="rounded-md border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</div>
      ) : null}

      <div className="flex flex-wrap items-end gap-3">
        <form method="get" className="grid gap-2">
          <Label htmlFor="barber">Barber</Label>
          <div className="flex gap-2">
            <select
              id="barber"
              name="barber"
              className="h-10 rounded-md border border-white/10 bg-transparent px-3 text-sm"
              defaultValue={selectedBarberId}
            >
              {(barbers ?? []).map((b) => (
                <option key={b.id} value={b.id}>
                  {b.display_name}
                </option>
              ))}
            </select>
            <Button type="submit" variant="secondary">
              Load
            </Button>
          </div>
        </form>
      </div>

      <form action={upload} className="grid gap-4 md:grid-cols-3">
        <input type="hidden" name="barber_id" value={selectedBarberId} />
        <div className="grid gap-2 md:col-span-2">
          <Label htmlFor="caption">Caption</Label>
          <Input id="caption" name="caption" placeholder="Fade / Beard / VIP..." />
        </div>
        <div className="grid gap-2 md:col-span-3">
          <Label>Image</Label>
          <MediaFileInput name="file" accept="image/*" />
        </div>
        <div className="flex justify-end md:col-span-3">
          <Button type="submit" variant="secondary">
            Upload
          </Button>
        </div>
      </form>

      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        {signedItems.length ? (
          signedItems.map((it) => (
            <div key={it.id} className="overflow-hidden rounded-md border border-white/10">
              <SafeImage
                src={it.signedMedia}
                fallbackKey="empty_state_image"
                width={600}
                height={360}
                className="h-36 w-full object-cover"
              />
              <div className="flex items-center justify-between gap-2 p-3">
                <div className="truncate text-xs text-muted-foreground">{it.caption ?? ""}</div>
                <form action={remove}>
                  <input type="hidden" name="id" value={it.id} />
                  <input type="hidden" name="barber_id" value={selectedBarberId} />
                  <input type="hidden" name="media_path" value={it.media_path ?? ""} />
                  <input type="hidden" name="media_url" value={it.media_url} />
                  <Button type="submit" size="sm" variant="ghost">
                    Delete
                  </Button>
                </form>
              </div>
            </div>
          ))
        ) : (
          <div className="col-span-2 rounded-md border border-white/10 p-6 text-sm text-muted-foreground md:col-span-4">
            No portfolio items yet.
          </div>
        )}
      </div>
    </div>
  );
}

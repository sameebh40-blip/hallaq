import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { randomUUID } from "crypto";
import Image from "next/image";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { signedOrUrl } from "@hallaq/supabase/storage";
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
  if (m.toLowerCase().includes("column") && m.toLowerCase().includes("does not exist")) {
    return "Your Supabase database schema is missing required columns. Apply the Supabase migrations then try again.";
  }
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as an admin user (profiles.role = 'admin').";
  }
  return m;
}

export default async function BarberDetailsPage({
  params,
  searchParams
}: {
  params: Promise<{ id: string }>;
  searchParams?: Promise<{ error?: string }>;
}) {
  const { id: barberId } = await params;
  const qp = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((qp?.error ?? "").trim());
  const supabase = await createSupabaseServerClient();

  const { data: barber } = await supabase
    .from("barbers")
    .select(
      "id, profile_id, display_name, bio, area, shop_id, status, is_independent, is_verified, is_hallaq_certified, created_at, deleted_at, avatar_url, cover_url, avatar_path, cover_path"
    )
    .eq("id", barberId)
    .maybeSingle();

  if (!barber) notFound();

  const { data: shops } = await supabase
    .from("barbershops")
    .select("id, name")
    .order("created_at", { ascending: false })
    .limit(500);

  const signedAvatar = await signedOrUrl(supabase, "barber-images", barber.avatar_path ?? barber.avatar_url);
  const signedCover = await signedOrUrl(supabase, "barber-images", barber.cover_path ?? barber.cover_url);

  async function updateBarber(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const displayName = String(formData.get("display_name") ?? "").trim();
    const bio = String(formData.get("bio") ?? "").trim();
    const area = String(formData.get("area") ?? "").trim();
    const shopIdSelect = String(formData.get("shop_id_select") ?? "").trim();
    const shopIdManual = String(formData.get("shop_id") ?? "").trim();
    const shopId = shopIdSelect || shopIdManual;
    const avatarFile = formData.get("avatar_file");
    const coverFile = formData.get("cover_file");

    if (!id || !displayName) redirect(`/barbers/${barberId}`);

    const currentBarber = barber;
    if (!currentBarber) redirect(`/barbers/${barberId}`);

    const supabase = await createSupabaseServerClient();
    const updates: Record<string, string | null | boolean> = {
      display_name: displayName,
      bio: bio || null,
      area: area || null,
      shop_id: shopId || null,
      is_independent: !shopId
    };
    const admin = await createSupabaseServerClient();

    const uploadImage = async (file: File, kind: "avatar" | "cover") => {
      const prepared = await prepareImageFileForUpload(file);
      const objectPath = buildPreparedUploadPath(`barbers/${id}/${kind}-${randomUUID()}`, prepared.fileName, prepared.contentType);
      const { error: uploadError } = await admin.storage.from("barber-images").upload(objectPath, prepared.bytes, {
        contentType: prepared.contentType || undefined,
        upsert: false
      });
      if (uploadError) throw new Error(uploadError.message);
      return objectPath;
    };

    try {
      if (avatarFile instanceof File && avatarFile.size > 0) {
        updates.avatar_path = await uploadImage(avatarFile, "avatar");
        updates.avatar_url = null;
      }
      if (coverFile instanceof File && coverFile.size > 0) {
        updates.cover_path = await uploadImage(coverFile, "cover");
        updates.cover_url = null;
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Could not prepare the selected images.";
      redirect(`/barbers/${id}?error=${encodeURIComponent(userFacingDbError(msg))}`);
    }

    const { error: updateError } = await supabase.from("barbers").update(updates).eq("id", id);
    if (updateError) redirect(`/barbers/${id}?error=${encodeURIComponent(userFacingDbError(updateError.message))}`);

    try {
      if (updates.avatar_path && updates.avatar_path !== currentBarber.avatar_path) {
        await removeStorageObjectIfPresent(admin.storage, "barber-images", currentBarber.avatar_path);
      }
      if (updates.cover_path && updates.cover_path !== currentBarber.cover_path) {
        await removeStorageObjectIfPresent(admin.storage, "barber-images", currentBarber.cover_path);
      }
    } catch {}

    redirect(`/barbers/${id}`);
  }

  async function deleteBarber(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;
    const { error } = await supabase.from("barbers").update({ deleted_at: new Date().toISOString() }).eq("id", id);
    if (error) redirect(`/barbers/${barberId}?error=${encodeURIComponent(userFacingDbError(error.message))}`);
    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "barber_soft_deleted",
      entity_type: "barber",
      entity_id: id,
      meta: {}
    });
    if (logError) redirect(`/barbers/${barberId}?error=${encodeURIComponent(userFacingDbError(logError.message))}`);
    redirect("/barbers");
  }

  async function restoreBarber(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;
    const { error } = await supabase.from("barbers").update({ deleted_at: null }).eq("id", id);
    if (error) redirect(`/barbers/${barberId}?error=${encodeURIComponent(userFacingDbError(error.message))}`);
    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "barber_restored",
      entity_type: "barber",
      entity_id: id,
      meta: {}
    });
    if (logError) redirect(`/barbers/${barberId}?error=${encodeURIComponent(userFacingDbError(logError.message))}`);
    redirect(`/barbers/${id}`);
  }

  return (
    <PageFrame
      title={barber.display_name ?? "Barber"}
      subtitle="Edit barber profile fields."
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/barbers">Back</Link>
        </Button>
      }
    >
      {qp?.error ? (
        <div className="mb-4 rounded-xl border border-rose-500/20 bg-rose-500/10 px-4 py-3 text-sm text-rose-100">{error}</div>
      ) : null}
      <form action={updateBarber} className="grid gap-4" encType="multipart/form-data">
        <input type="hidden" name="id" value={barber.id} />
        <div className="grid gap-2">
          <Label htmlFor="display_name">Display name</Label>
          <Input id="display_name" name="display_name" defaultValue={barber.display_name ?? ""} required />
        </div>
        <div className="grid gap-2">
          <Label>Avatar</Label>
          {signedAvatar ? (
            <div className="relative h-20 w-20 overflow-hidden rounded-xl border border-white/10 bg-white/5">
              <Image src={signedAvatar} alt="" fill unoptimized className="object-cover" />
            </div>
          ) : null}
          <MediaFileInput name="avatar_file" accept="image/*" />
        </div>
        <div className="grid gap-2">
          <Label>Cover</Label>
          {signedCover ? (
            <div className="relative aspect-[16/9] w-full overflow-hidden rounded-xl border border-white/10 bg-white/5">
              <Image src={signedCover} alt="" fill unoptimized className="object-cover" />
            </div>
          ) : null}
          <MediaFileInput name="cover_file" accept="image/*" />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="bio">Bio</Label>
          <Input id="bio" name="bio" defaultValue={barber.bio ?? ""} />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="area">Area</Label>
          <Input id="area" name="area" defaultValue={barber.area ?? ""} />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="shop_id">Shop id</Label>
          {shops?.length ? (
            <select
              id="shop_id_select"
              name="shop_id_select"
              defaultValue={barber.shop_id ?? ""}
              className="flex h-10 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
            >
              <option value="">Independent</option>
              {shops.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
          ) : null}
          <Label htmlFor="shop_id">Or paste shop id</Label>
          <Input id="shop_id" name="shop_id" defaultValue={barber.shop_id ?? ""} />
        </div>
        <div className="flex items-center justify-between gap-2 pt-2">
          <div className="text-xs text-muted-foreground">
            <div>id: {barber.id}</div>
            <div>profile: {barber.profile_id}</div>
            <div>status: {barber.status}</div>
            {barber.deleted_at ? (
              <div>deleted: {Intl.DateTimeFormat("en", { dateStyle: "medium" }).format(new Date(barber.deleted_at))}</div>
            ) : null}
          </div>
          <div className="flex items-center gap-2">
            {barber.deleted_at ? (
              <Button type="submit" variant="secondary" formAction={restoreBarber}>
                Restore
              </Button>
            ) : (
              <Button type="submit" variant="ghost" formAction={deleteBarber}>
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

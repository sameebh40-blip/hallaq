import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { randomUUID } from "crypto";
import Image from "next/image";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { signedOrUrl } from "@hallaq/supabase/storage";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";

import { MediaFileInput } from "@/components/media-file-input";
import { PageFrame } from "@/components/page-frame";
import { logAdminSyncError } from "@/lib/admin-sync-logging";
import { buildPreparedUploadPath, prepareImageFileForUpload, removeStorageObjectIfPresent } from "@/lib/media/prepare-image-upload";
import { normalizeManagedProfileRole, promoteProfileToShopOwner } from "@/lib/profile-role-sync";
import { barberHasBookings, deleteShopMemberships, upsertShopMembership } from "@/lib/shop-memberships";

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
  if (m === "use_transfer_ownership") return "To change the owner, use the “Transfer ownership” form.";
  if (m === "confirmation_required") return "Confirmation required.";
  if (m === "new_owner_required") return "Please enter the new owner profile id.";
  if (m === "shop_owner_has_barber_link") return "New owner is linked as a barber. Remove their barber link before transferring ownership.";
  if (m === "owner_cannot_be_barber") return "A shop owner cannot be a barber.";
  if (m === "role_conflict_barber") return "This user cannot become a shop owner while they are linked as a barber.";
  if (m === "role_conflict_shop_owner") return "This user cannot become a barber while they are linked as a shop owner.";
  if (m === "barber_has_bookings" || m === "BOOKING_BARBER_IMMUTABLE") {
    return "This barber already has bookings or booking history, so the barber link cannot be removed or converted to owner/customer.";
  }
  return m;
}

export default async function StoreDetailsPage({
  params,
  searchParams
}: {
  params: Promise<{ id: string }>;
  searchParams?: Promise<{ error?: string }>;
}) {
  const { id: storeId } = await params;
  const sp = searchParams ? await searchParams : undefined;
  const rawError = (sp?.error ?? "").trim();
  const error = rawError ? userFacingDbError(rawError) : "";
  const supabase = await createSupabaseServerClient();

  const { data: shop } = await supabase
    .from("barbershops")
    .select(
      "id, owner_profile_id, name, description, area, address, phone, whatsapp, instagram, status, is_verified, is_featured, created_at, deleted_at, logo_url, cover_url, logo_path, cover_path"
    )
    .eq("id", storeId)
    .maybeSingle();

  if (!shop) notFound();

  const signedLogo = await signedOrUrl(supabase, "shop-images", shop.logo_path ?? shop.logo_url);
  const signedCover = await signedOrUrl(supabase, "shop-images", shop.cover_path ?? shop.cover_url);

  async function updateStore(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const ownerProfileId = String(formData.get("owner_profile_id") ?? "").trim();
    const name = String(formData.get("name") ?? "").trim();
    const description = String(formData.get("description") ?? "").trim();
    const area = String(formData.get("area") ?? "").trim();
    const address = String(formData.get("address") ?? "").trim();
    const phone = String(formData.get("phone") ?? "").trim();
    const whatsapp = String(formData.get("whatsapp") ?? "").trim();
    const instagram = String(formData.get("instagram") ?? "").trim();
    const logoFile = formData.get("logo_file");
    const coverFile = formData.get("cover_file");

    if (!id || !name) redirect(`/stores/${storeId}`);

    const currentShop = shop;
    if (!currentShop) redirect(`/stores/${storeId}`);

    const supabase = await createSupabaseServerClient();
    const admin = await createSupabaseAdminClient();

    if (ownerProfileId && ownerProfileId !== String(currentShop.owner_profile_id ?? "").trim()) {
      redirect(`/stores/${storeId}?error=${encodeURIComponent("use_transfer_ownership")}`);
    }

    const updates: Record<string, string | null> = {
      owner_profile_id: ownerProfileId || null,
      name,
      description: description || null,
      area: area || null,
      address: address || null,
      phone: phone || null,
      whatsapp: whatsapp || null,
      instagram: instagram || null
    };

    const uploadImage = async (file: File, kind: "logo" | "cover") => {
      const prepared = await prepareImageFileForUpload(file);
      const objectPath = buildPreparedUploadPath(`shops/${id}/${kind}-${randomUUID()}`, prepared.fileName, prepared.contentType);
      const { error: uploadError } = await admin.storage.from("shop-images").upload(objectPath, prepared.bytes, {
        contentType: prepared.contentType || undefined,
        upsert: false
      });
      if (uploadError) throw new Error(uploadError.message);
      return objectPath;
    };

    try {
      if (logoFile instanceof File && logoFile.size > 0) {
        updates.logo_path = await uploadImage(logoFile, "logo");
        updates.logo_url = null;
      }
      if (coverFile instanceof File && coverFile.size > 0) {
        updates.cover_path = await uploadImage(coverFile, "cover");
        updates.cover_url = null;
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Could not prepare the selected images.";
      redirect(`/stores/${id}?error=${encodeURIComponent(userFacingDbError(msg))}`);
    }

    const { error: updateError } = await supabase.from("barbershops").update(updates).eq("id", id);
    if (updateError) redirect(`/stores/${storeId}?error=${encodeURIComponent(userFacingDbError(updateError.message))}`);

    try {
      if (updates.logo_path && updates.logo_path !== shop.logo_path) {
        await removeStorageObjectIfPresent(admin.storage, "shop-images", shop.logo_path);
      }
      if (updates.cover_path && updates.cover_path !== shop.cover_path) {
        await removeStorageObjectIfPresent(admin.storage, "shop-images", shop.cover_path);
      }
    } catch {}

    redirect(`/stores/${id}`);
  }

  async function transferOwnership(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "").trim();
    const newOwnerProfileId = String(formData.get("new_owner_profile_id") ?? "").trim();
    const confirm = String(formData.get("confirm") ?? "").trim();

    if (!id) redirect(`/stores/${storeId}`);
    if (!newOwnerProfileId) redirect(`/stores/${storeId}?error=${encodeURIComponent("new_owner_required")}`);
    if (confirm !== "CONFIRM") redirect(`/stores/${storeId}?error=${encodeURIComponent("confirmation_required")}`);

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const actorId = user?.id ?? null;

    const admin = await createSupabaseAdminClient();

    const { data: currentShop, error: shopError } = await admin
      .from("barbershops")
      .select("id, owner_profile_id")
      .eq("id", id)
      .maybeSingle();
    if (shopError) redirect(`/stores/${storeId}?error=${encodeURIComponent(shopError.message)}`);
    if (!currentShop?.id) redirect(`/stores/${storeId}?error=${encodeURIComponent("shop_not_found")}`);

    const oldOwnerProfileId = String((currentShop as { owner_profile_id?: unknown }).owner_profile_id ?? "").trim() || null;

    if (await barberHasBookings(admin, newOwnerProfileId)) {
      redirect(`/stores/${storeId}?error=${encodeURIComponent("barber_has_bookings")}`);
    }
    await deleteShopMemberships(admin, { profileId: newOwnerProfileId, membershipRole: "barber" });
    const { error: barberDeleteError } = await admin.from("barbers").delete().eq("profile_id", newOwnerProfileId);
    if (barberDeleteError) redirect(`/stores/${storeId}?error=${encodeURIComponent(barberDeleteError.message)}`);

    const { error: transferError } = await admin.from("barbershops").update({ owner_profile_id: newOwnerProfileId }).eq("id", id);
    if (transferError) redirect(`/stores/${storeId}?error=${encodeURIComponent(transferError.message)}`);

    try {
      await promoteProfileToShopOwner(admin, newOwnerProfileId);
      await upsertShopMembership(admin, { profileId: newOwnerProfileId, shopId: id, membershipRole: "owner" });
      if (oldOwnerProfileId && oldOwnerProfileId !== newOwnerProfileId) {
        await deleteShopMemberships(admin, { profileId: oldOwnerProfileId, membershipRole: "owner", shopId: id });
      }

      if (oldOwnerProfileId) {
        await normalizeManagedProfileRole(admin, oldOwnerProfileId);
      }
    } catch (e) {
      const message = e instanceof Error ? e.message : "ownership_sync_failed";
      await logAdminSyncError(admin, {
        actorId,
        page: `/stores/${storeId}`,
        action: "transfer_store_ownership_sync",
        error: message,
        meta: { shop_id: id, old_owner_profile_id: oldOwnerProfileId, new_owner_profile_id: newOwnerProfileId }
      });
      redirect(`/stores/${storeId}?error=${encodeURIComponent(message)}`);
    }

    await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "store_ownership_transferred",
      entity_type: "shop",
      entity_id: id,
      meta: { oldOwnerProfileId, newOwnerProfileId }
    });

    redirect(`/stores/${id}`);
  }

  async function deleteStore(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;
    const { error: delError } = await supabase.from("barbershops").update({ deleted_at: new Date().toISOString() }).eq("id", id);
    if (delError) redirect(`/stores/${storeId}?error=${encodeURIComponent(delError.message)}`);
    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "store_soft_deleted",
      entity_type: "shop",
      entity_id: id,
      meta: {}
    });
    if (logError) redirect(`/stores/${storeId}?error=${encodeURIComponent(logError.message)}`);
    redirect("/stores");
  }

  async function restoreStore(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;
    const { error: restoreError } = await supabase.from("barbershops").update({ deleted_at: null }).eq("id", id);
    if (restoreError) redirect(`/stores/${storeId}?error=${encodeURIComponent(restoreError.message)}`);
    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "store_restored",
      entity_type: "shop",
      entity_id: id,
      meta: {}
    });
    if (logError) redirect(`/stores/${storeId}?error=${encodeURIComponent(logError.message)}`);
    redirect(`/stores/${id}`);
  }

  return (
    <PageFrame
      title={shop.name ?? "Store"}
      subtitle="Edit store profile fields."
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/stores">Back</Link>
        </Button>
      }
    >
      {rawError ? (
        <div className="mb-4 rounded-xl border border-rose-500/20 bg-rose-500/10 px-4 py-3 text-sm text-rose-100">
          {error}
        </div>
      ) : null}
      <form action={transferOwnership} className="mb-4 grid gap-3 rounded-xl border border-white/10 bg-white/5 p-4">
        <input type="hidden" name="id" value={shop.id} />
        <div className="text-sm font-semibold">Transfer ownership</div>
        <div className="grid gap-2 md:grid-cols-3">
          <Input name="new_owner_profile_id" placeholder="New owner profile id (uuid)" className="h-11 bg-white/5" />
          <Input name="confirm" placeholder="Type CONFIRM" className="h-11 bg-white/5" />
          <Button type="submit" variant="secondary" className="h-11">
            Transfer
          </Button>
        </div>
      </form>
      <form action={updateStore} className="grid gap-4" encType="multipart/form-data">
        <input type="hidden" name="id" value={shop.id} />
        <div className="grid gap-2">
          <Label htmlFor="owner_profile_id">Owner profile id</Label>
          <Input id="owner_profile_id" name="owner_profile_id" defaultValue={shop.owner_profile_id ?? ""} readOnly />
        </div>
        <div className="grid gap-2">
          <Label>Logo</Label>
          {signedLogo ? (
            <div className="relative h-20 w-20 overflow-hidden rounded-xl border border-white/10 bg-white/5">
              <Image src={signedLogo} alt="" fill unoptimized className="object-cover" />
            </div>
          ) : null}
          <MediaFileInput name="logo_file" accept="image/*" />
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
          <Label htmlFor="name">Name</Label>
          <Input id="name" name="name" defaultValue={shop.name ?? ""} required />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="description">Description</Label>
          <Input id="description" name="description" defaultValue={shop.description ?? ""} />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="area">Area</Label>
          <Input id="area" name="area" defaultValue={shop.area ?? ""} />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="address">Address</Label>
          <Input id="address" name="address" defaultValue={shop.address ?? ""} />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="phone">Phone</Label>
          <Input id="phone" name="phone" defaultValue={shop.phone ?? ""} />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="whatsapp">WhatsApp</Label>
          <Input id="whatsapp" name="whatsapp" defaultValue={shop.whatsapp ?? ""} />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="instagram">Instagram</Label>
          <Input id="instagram" name="instagram" defaultValue={shop.instagram ?? ""} />
        </div>
        <div className="flex items-center justify-between gap-2 pt-2">
          <div className="text-xs text-muted-foreground">
            <div>id: {shop.id}</div>
            <div>owner: {shop.owner_profile_id}</div>
            <div>status: {shop.status}</div>
            {shop.deleted_at ? <div>deleted: {Intl.DateTimeFormat("en", { dateStyle: "medium" }).format(new Date(shop.deleted_at))}</div> : null}
          </div>
          <div className="flex items-center gap-2">
            {shop.deleted_at ? (
              <Button type="submit" variant="secondary" formAction={restoreStore}>
                Restore
              </Button>
            ) : (
              <Button type="submit" variant="ghost" formAction={deleteStore}>
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

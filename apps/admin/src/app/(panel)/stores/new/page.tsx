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
import { logAdminSyncError } from "@/lib/admin-sync-logging";
import { buildPreparedUploadPath, prepareImageFileForUpload } from "@/lib/media/prepare-image-upload";
import { promoteProfileToShopOwner } from "@/lib/profile-role-sync";
import { getOrCreatePrimaryBranchId, upsertShopMembership } from "@/lib/shop-memberships";

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

export default async function NewStorePage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((params?.error ?? "").trim());

  const supabase = await createSupabaseServerClient();
  const { data: ownersRaw } = await supabase
    .from("profiles")
    .select("id, full_name, email, role, status, created_at")
    .eq("role", "shop_owner")
    .eq("status", "active")
    .order("created_at", { ascending: false })
    .limit(200);
  const owners = (ownersRaw ?? []) as Array<Record<string, unknown>>;

  const { data: barbers } = await supabase
    .from("barbers")
    .select("id, display_name, shop_id, created_at")
    .order("created_at", { ascending: false })
    .limit(200);

  async function createStore(formData: FormData) {
    "use server";

    const ownerIdSelect = String(formData.get("owner_profile_select") ?? "").trim();
    const ownerIdManual = String(formData.get("owner_profile_id") ?? "").trim();
    const ownerProfileId = ownerIdSelect || ownerIdManual;
    const name = String(formData.get("name") ?? "").trim();
    const area = String(formData.get("area") ?? "").trim();
    const address = String(formData.get("address") ?? "").trim();
    const phone = String(formData.get("phone") ?? "").trim();
    const whatsapp = String(formData.get("whatsapp") ?? "").trim();
    const instagram = String(formData.get("instagram") ?? "").trim();
    const description = String(formData.get("description") ?? "").trim();
    const isVerified = String(formData.get("is_verified") ?? "") === "on";
    const isFeatured = String(formData.get("is_featured") ?? "") === "on";
    const status = String(formData.get("status") ?? "approved").trim() || "approved";
    const barberIds = formData
      .getAll("barber_ids")
      .map((v) => String(v ?? "").trim())
      .filter(Boolean);

    const logoFile = formData.get("logo_file");
    const coverFile = formData.get("cover_file");

    if (!ownerProfileId || !name) {
      redirect(`/stores/new?error=${encodeURIComponent("Owner profile id and name are required.")}`);
    }

    const admin = await createSupabaseAdminClient();
    const { data: created, error: insertError } = await admin
      .from("barbershops")
      .insert({
        owner_profile_id: ownerProfileId,
        name,
        description: description || null,
        area: area || null,
        address: address || null,
        phone: phone || null,
        whatsapp: whatsapp || null,
        instagram: instagram || null,
        status,
        is_verified: isVerified,
        is_featured: isFeatured,
      })
      .select("id")
      .single();

    if (insertError) redirect(`/stores/new?error=${encodeURIComponent(userFacingDbError(insertError.message))}`);

    const shopId = created?.id ?? "";
    if (!shopId) redirect(`/stores/new?error=${encodeURIComponent("Failed to create store.")}`);

    try {
      await promoteProfileToShopOwner(admin, ownerProfileId);
      await upsertShopMembership(admin, { profileId: ownerProfileId, shopId, membershipRole: "owner" });
    } catch (e) {
      const message = e instanceof Error ? e.message : "membership_sync_failed";
      await logAdminSyncError(admin, {
        page: "/stores/new",
        action: "create_store_owner_sync",
        error: message,
        meta: { shop_id: shopId, owner_profile_id: ownerProfileId }
      });
      redirect(`/stores/new?error=${encodeURIComponent(userFacingDbError(message))}`);
    }

    const uploadImage = async (file: File, kind: "logo" | "cover") => {
      const prepared = await prepareImageFileForUpload(file);
      const objectPath = buildPreparedUploadPath(`shops/${shopId}/${kind}-${randomUUID()}`, prepared.fileName, prepared.contentType);
      const { error: uploadError } = await admin.storage.from("shop-images").upload(objectPath, prepared.bytes, {
        contentType: prepared.contentType || undefined,
        upsert: false,
      });
      if (uploadError) throw new Error(uploadError.message);
      return objectPath;
    };

    try {
      const updates: Record<string, string | null> = {};
      if (logoFile instanceof File && logoFile.size > 0) {
        const path = await uploadImage(logoFile, "logo");
        updates.logo_path = path;
        updates.logo_url = null;
      }
      if (coverFile instanceof File && coverFile.size > 0) {
        const path = await uploadImage(coverFile, "cover");
        updates.cover_path = path;
        updates.cover_url = null;
      }

      if (Object.keys(updates).length) {
        const { error: updateError } = await admin.from("barbershops").update(updates).eq("id", shopId);
        if (updateError) throw new Error(updateError.message);
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Could not prepare the selected images.";
      redirect(`/stores/new?error=${encodeURIComponent(userFacingDbError(msg))}`);
    }

    if (barberIds.length) {
      const branchId = await getOrCreatePrimaryBranchId(admin, shopId);
      if (!branchId) redirect(`/stores/new?error=${encodeURIComponent("Failed to resolve a branch for the new store.")}`);

      const { error: assignError } = await admin.from("barbers").update({ shop_id: shopId, branch_id: branchId }).in("id", barberIds);
      if (assignError) redirect(`/stores/new?error=${encodeURIComponent(userFacingDbError(assignError.message))}`);

      try {
        for (const barberId of barberIds) {
          const { data: barberRow, error: barberRowError } = await admin.from("barbers").select("profile_id").eq("id", barberId).maybeSingle();
          if (barberRowError) throw new Error(barberRowError.message);
          const profileId = String((barberRow as { profile_id?: unknown } | null)?.profile_id ?? "").trim();
          if (!profileId) continue;
          await upsertShopMembership(admin, { profileId, shopId, branchId, membershipRole: "barber" });
        }
      } catch (e) {
        const message = e instanceof Error ? e.message : "membership_sync_failed";
        await logAdminSyncError(admin, {
          page: "/stores/new",
          action: "create_store_barber_sync",
          error: message,
          meta: { shop_id: shopId, branch_id: branchId, barber_ids: barberIds }
        });
        redirect(`/stores/new?error=${encodeURIComponent(userFacingDbError(message))}`);
      }
    }

    redirect(`/stores?created=${encodeURIComponent(shopId)}`);
  }

  return (
    <PageFrame
      title="Create Store"
      subtitle="Creates a barbershop, uploads images, and optionally assigns barbers."
      actions={
        <div className="flex items-center gap-2">
          <Button asChild variant="ghost" size="sm">
            <Link href="/stores">Back</Link>
          </Button>
          <Button asChild variant="secondary" size="sm">
            <Link href="/barbers/new">Create Barber</Link>
          </Button>
        </div>
      }
    >
      {params?.error ? (
        <div className="mb-4 rounded-xl border border-rose-500/20 bg-rose-500/10 px-4 py-3 text-sm text-rose-100">
          {error}
        </div>
      ) : null}
      <form action={createStore} className="grid gap-4" encType="multipart/form-data">
        <div className="grid gap-2">
          <Label>Owner</Label>
          {owners?.length ? (
            <select
              id="owner_profile_select"
              name="owner_profile_select"
              defaultValue=""
              className="flex h-10 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
            >
              <option value="">Select an owner…</option>
              {owners.map((o) => {
                const row = o as {
                  id: string;
                  full_name?: string | null;
                  role?: string | null;
                  email?: string | null;
                };
                return (
                  <option key={row.id} value={row.id}>
                    {(row.full_name ?? "User").trim() || "User"} • {row.role ?? "customer"} • {(row.email ?? "").trim() || row.id}
                  </option>
                );
              })}
            </select>
          ) : null}

          <Label htmlFor="owner_profile_id">Or paste owner profile id</Label>
          <Input id="owner_profile_id" name="owner_profile_id" placeholder="UUID from profiles.id" required />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="name">Name</Label>
          <Input id="name" name="name" placeholder="Shop name" required />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="area">Area</Label>
          <Input id="area" name="area" placeholder="Manama / Seef / ..." />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="address">Address</Label>
          <Input id="address" name="address" placeholder="Street, building, ..." />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="phone">Phone</Label>
          <Input id="phone" name="phone" placeholder="+973 ..." />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="whatsapp">WhatsApp</Label>
          <Input id="whatsapp" name="whatsapp" placeholder="+973 ..." />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="instagram">Instagram</Label>
          <Input id="instagram" name="instagram" placeholder="@handle" />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="description">Description</Label>
          <textarea
            id="description"
            name="description"
            placeholder="Short description…"
            className="min-h-24 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
          />
        </div>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
          <div className="grid gap-2">
            <Label htmlFor="status">Status</Label>
            <select
              id="status"
              name="status"
              defaultValue="approved"
              className="flex h-10 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
            >
              <option value="approved">Approved</option>
              <option value="pending">Pending</option>
              <option value="suspended">Suspended</option>
            </select>
          </div>
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" name="is_verified" defaultChecked />
            Verified
          </label>
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" name="is_featured" />
            Featured
          </label>
        </div>
        <div className="grid gap-4 md:grid-cols-2">
          <div className="grid gap-2">
            <Label>Logo image</Label>
            <MediaFileInput name="logo_file" accept="image/*" />
          </div>
          <div className="grid gap-2">
            <Label>Cover image (banner)</Label>
            <MediaFileInput name="cover_file" accept="image/*" />
          </div>
        </div>
        <div className="grid gap-2">
          <Label>Assign barbers (optional)</Label>
          {barbers?.length ? (
            <select
              name="barber_ids"
              multiple
              className="min-h-40 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
            >
              {barbers.map((b) => (
                <option key={b.id} value={b.id} disabled={Boolean(b.shop_id)}>
                  {(b.display_name ?? "Barber").trim() || "Barber"} {b.shop_id ? "• already assigned" : ""}
                </option>
              ))}
            </select>
          ) : (
            <div className="text-sm text-muted-foreground">No barbers found yet. You can add barbers first, then assign.</div>
          )}
          <div className="text-xs text-muted-foreground">
            Tip: Hold Ctrl (Windows) / Cmd (Mac) to select multiple.
          </div>
        </div>
        <div className="flex items-center justify-end gap-2 pt-2">
          <Button asChild variant="ghost">
            <Link href="/stores">Cancel</Link>
          </Button>
          <Button type="submit">Create</Button>
        </div>
      </form>
    </PageFrame>
  );
}

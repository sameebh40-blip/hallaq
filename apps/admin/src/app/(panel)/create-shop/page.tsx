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
import { upsertShopMembership } from "@/lib/shop-memberships";

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
  if (m === "ffmpeg_not_available") {
    return "FFmpeg is not available on the admin server to compress this media. Install FFmpeg (or set FFMPEG_PATH) or upload a smaller file.";
  }
  if (m === "role_change_not_allowed") {
    return "Shop creation tried to change the owner role directly. The system now promotes owners through shop creation automatically.";
  }
  return m;
}

function toNullableNumber(v: string) {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

export default async function AdminCreateShopPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((params?.error ?? "").trim());

  async function createShop(formData: FormData) {
    "use server";

    const ownerFullName = String(formData.get("owner_full_name") ?? "").trim();
    const ownerEmail = String(formData.get("owner_email") ?? "").trim().toLowerCase();
    const ownerPassword = String(formData.get("owner_password") ?? "");
    const ownerPhone = String(formData.get("owner_phone") ?? "").trim();

    const shopName = String(formData.get("shop_name") ?? "").trim();
    const shopNameAr = String(formData.get("shop_name_ar") ?? "").trim();
    const shopPhone = String(formData.get("shop_phone") ?? "").trim();
    const whatsapp = String(formData.get("whatsapp") ?? "").trim();
    const area = String(formData.get("area") ?? "").trim();
    const address = String(formData.get("address") ?? "").trim();
    const lat = toNullableNumber(String(formData.get("lat") ?? "").trim());
    const lng = toNullableNumber(String(formData.get("lng") ?? "").trim());
    const googleMapsUrl = String(formData.get("google_maps_url") ?? "").trim();
    const instagram = String(formData.get("instagram") ?? "").trim();
    const tiktok = String(formData.get("tiktok") ?? "").trim();
    const description = String(formData.get("description") ?? "").trim();
    const category = String(formData.get("category") ?? "").trim();

    const status = String(formData.get("status") ?? "approved").trim() || "approved";
    const isActive = String(formData.get("is_active") ?? "") === "on";
    const isVerified = String(formData.get("is_verified") ?? "") === "on";
    const homeService = String(formData.get("home_service") ?? "") === "on";
    const commissionRateRaw = String(formData.get("commission_rate") ?? "").trim();
    const commissionRate = commissionRateRaw ? toNullableNumber(commissionRateRaw) : null;
    const subscriptionPlan = String(formData.get("subscription_plan") ?? "").trim();

    const defaultStartTime = String(formData.get("default_start_time") ?? "09:00").trim() || "09:00";
    const defaultEndTime = String(formData.get("default_end_time") ?? "21:00").trim() || "21:00";

    const logoFile = formData.get("logo_file");
    const coverFile = formData.get("cover_file");

    if (!ownerFullName || !ownerEmail || !ownerPassword || !shopName) {
      redirect(`/create-shop?error=${encodeURIComponent("Owner name, email, password, and shop name are required.")}`);
    }

    const adminSession = await createSupabaseServerClient();
    const { data: actorData } = await adminSession.auth.getUser();
    const actorId = actorData.user?.id ?? null;

    const admin = await createSupabaseAdminClient();
    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email: ownerEmail,
      password: ownerPassword,
      email_confirm: true,
      user_metadata: { full_name: ownerFullName }
    });
    if (createError) redirect(`/create-shop?error=${encodeURIComponent(userFacingDbError(createError.message))}`);

    const ownerId = created.user?.id ?? "";
    if (!ownerId) redirect(`/create-shop?error=${encodeURIComponent("Failed to create auth user.")}`);

    const { error: profileError } = await admin.from("profiles").upsert({
      id: ownerId,
      email: ownerEmail,
      full_name: ownerFullName,
      phone: ownerPhone || null,
      role: "customer",
      status: "active",
      must_change_password: true
    });
    if (profileError) redirect(`/create-shop?error=${encodeURIComponent(userFacingDbError(profileError.message))}`);

    const { data: createdShop, error: shopError } = await admin
      .from("barbershops")
      .insert({
        owner_profile_id: ownerId,
        name: shopName,
        name_ar: shopNameAr || null,
        description: description || null,
        area: area || null,
        address: address || null,
        lat,
        lng,
        phone: shopPhone || null,
        whatsapp: whatsapp || null,
        instagram: instagram || null,
        tiktok: tiktok || null,
        google_maps_url: googleMapsUrl || null,
        category: category || null,
        commission_rate: commissionRate,
        subscription_plan: subscriptionPlan || null,
        status,
        is_active: isActive,
        is_verified: isVerified,
        home_service: homeService
      })
      .select("id")
      .single();
    if (shopError) redirect(`/create-shop?error=${encodeURIComponent(userFacingDbError(shopError.message))}`);

    const shopId = createdShop?.id ?? "";
    if (!shopId) redirect(`/create-shop?error=${encodeURIComponent("Failed to create shop.")}`);

    try {
      await promoteProfileToShopOwner(admin, ownerId);
      await upsertShopMembership(admin, { profileId: ownerId, shopId, membershipRole: "owner" });
    } catch (e) {
      const msg = e instanceof Error ? e.message : "membership_sync_failed";
      await logAdminSyncError(admin, {
        actorId,
        page: "/create-shop",
        action: "create_shop_membership_sync",
        error: msg,
        meta: { shop_id: shopId, owner_profile_id: ownerId }
      });
      redirect(`/create-shop?error=${encodeURIComponent(userFacingDbError(msg))}`);
    }

    const uploadImage = async (file: File, kind: "logo" | "cover") => {
      const prepared = await prepareImageFileForUpload(file);
      const objectPath = buildPreparedUploadPath(`shops/${shopId}/${kind}-${randomUUID()}`, prepared.fileName, prepared.contentType);
      const { error: uploadError } = await admin.storage.from("shop-images").upload(objectPath, prepared.bytes, {
        contentType: prepared.contentType || undefined,
        upsert: false
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
      redirect(`/create-shop?error=${encodeURIComponent(userFacingDbError(msg))}`);
    }

    const { data: existingHours, error: hoursCheckError } = await admin
      .from("shop_working_hours")
      .select("id")
      .eq("shop_id", shopId)
      .limit(1);
    if (hoursCheckError) redirect(`/create-shop?error=${encodeURIComponent(userFacingDbError(hoursCheckError.message))}`);

    if ((existingHours?.length ?? 0) === 0) {
      const rows = Array.from({ length: 7 }).map((_, weekday) => ({
        shop_id: shopId,
        weekday,
        start_time: defaultStartTime,
        end_time: defaultEndTime,
        enabled: true
      }));
      const { error: hoursInsertError } = await admin.from("shop_working_hours").insert(rows);
      if (hoursInsertError) redirect(`/create-shop?error=${encodeURIComponent(userFacingDbError(hoursInsertError.message))}`);
    }

    await admin.from("notifications").insert({
      profile_id: ownerId,
      type: "system",
      title: "Your shop account has been created.",
      body: "Please change your password on first login."
    });

    if (actorId) {
      await adminSession.from("audit_events").insert({
        actor_profile_id: actorId,
        action: "admin_create_shop_owner",
        entity_type: "barbershop",
        entity_id: shopId,
        meta: { owner_profile_id: ownerId }
      });
    }

    redirect(`/stores?created=${encodeURIComponent(shopId)}`);
  }

  return (
    <PageFrame
      title="Create Shop"
      subtitle="Creates a shop owner auth account + profile + shop. Password is temporary and must be changed on first login."
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/stores">Back</Link>
        </Button>
      }
    >
      {params?.error ? (
        <div className="mb-4 rounded-xl border border-rose-500/20 bg-rose-500/10 px-4 py-3 text-sm text-rose-100">
          {error}
        </div>
      ) : null}

      <form action={createShop} className="grid gap-6" encType="multipart/form-data">
        <div className="grid gap-3">
          <div className="text-sm font-semibold">Owner account</div>
          <div className="grid gap-2">
            <Label htmlFor="owner_full_name">Owner full name</Label>
            <Input id="owner_full_name" name="owner_full_name" required />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="owner_email">Owner email</Label>
            <Input id="owner_email" name="owner_email" type="email" required />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="owner_password">Temporary password</Label>
            <Input id="owner_password" name="owner_password" type="password" required />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="owner_phone">Owner phone</Label>
            <Input id="owner_phone" name="owner_phone" placeholder="+973 ..." />
          </div>
        </div>

        <div className="grid gap-3">
          <div className="text-sm font-semibold">Shop details</div>
          <div className="grid gap-2">
            <Label htmlFor="shop_name">Shop name</Label>
            <Input id="shop_name" name="shop_name" required />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="shop_name_ar">Shop Arabic name (optional)</Label>
            <Input id="shop_name_ar" name="shop_name_ar" />
          </div>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div className="grid gap-2">
              <Label htmlFor="shop_phone">Shop phone</Label>
              <Input id="shop_phone" name="shop_phone" placeholder="+973 ..." />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="whatsapp">WhatsApp</Label>
              <Input id="whatsapp" name="whatsapp" placeholder="+973 ..." />
            </div>
          </div>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div className="grid gap-2">
              <Label htmlFor="area">Area</Label>
              <Input id="area" name="area" placeholder="Manama / Seef / ..." />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="category">Category</Label>
              <Input id="category" name="category" placeholder="Barbershop / Salon / ..." />
            </div>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="address">Address</Label>
            <Input id="address" name="address" />
          </div>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div className="grid gap-2">
              <Label htmlFor="lat">Latitude</Label>
              <Input id="lat" name="lat" inputMode="decimal" placeholder="26.2285" />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="lng">Longitude</Label>
              <Input id="lng" name="lng" inputMode="decimal" placeholder="50.5860" />
            </div>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="google_maps_url">Google Maps link</Label>
            <Input id="google_maps_url" name="google_maps_url" placeholder="https://maps.google.com/..." />
          </div>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div className="grid gap-2">
              <Label htmlFor="instagram">Instagram</Label>
              <Input id="instagram" name="instagram" placeholder="@handle" />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="tiktok">TikTok</Label>
              <Input id="tiktok" name="tiktok" placeholder="@handle" />
            </div>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="description">Description</Label>
            <textarea
              id="description"
              name="description"
              className="min-h-24 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
            />
          </div>
        </div>

        <div className="grid gap-3">
          <div className="text-sm font-semibold">Status</div>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
            <div className="grid gap-2">
              <Label htmlFor="status">Verification status</Label>
              <select
                id="status"
                name="status"
                defaultValue="approved"
                className="flex h-10 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
              >
                <option value="approved">Approved</option>
                <option value="pending">Pending</option>
                <option value="hidden">Hidden</option>
              </select>
            </div>
            <label className="flex items-center gap-2 text-sm">
              <input type="checkbox" name="is_verified" defaultChecked />
              Verified
            </label>
            <label className="flex items-center gap-2 text-sm">
              <input type="checkbox" name="is_active" defaultChecked />
              Open/Active
            </label>
          </div>
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" name="home_service" />
            Home service available
          </label>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div className="grid gap-2">
              <Label htmlFor="commission_rate">Commission rate (optional)</Label>
              <Input id="commission_rate" name="commission_rate" inputMode="decimal" placeholder="15" />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="subscription_plan">Subscription plan (optional)</Label>
              <Input id="subscription_plan" name="subscription_plan" placeholder="basic / pro / ..." />
            </div>
          </div>
        </div>

        <div className="grid gap-3">
          <div className="text-sm font-semibold">Working hours (default)</div>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div className="grid gap-2">
              <Label htmlFor="default_start_time">Start time</Label>
              <Input id="default_start_time" name="default_start_time" type="time" defaultValue="09:00" />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="default_end_time">End time</Label>
              <Input id="default_end_time" name="default_end_time" type="time" defaultValue="21:00" />
            </div>
          </div>
        </div>

        <div className="grid gap-3">
          <div className="text-sm font-semibold">Media</div>
          <div className="grid gap-4 md:grid-cols-2">
            <div className="grid gap-2">
              <Label>Shop logo</Label>
              <MediaFileInput name="logo_file" accept="image/*" />
            </div>
            <div className="grid gap-2">
              <Label>Shop banner</Label>
              <MediaFileInput name="cover_file" accept="image/*" />
            </div>
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

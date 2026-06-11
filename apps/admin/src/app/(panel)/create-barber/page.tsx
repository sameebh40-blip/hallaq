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
  if (m === "ffmpeg_not_available") {
    return "FFmpeg is not available on the admin server to compress this media. Install FFmpeg (or set FFMPEG_PATH) or upload a smaller file.";
  }
  if (m === "role_change_not_allowed") {
    return "Barber creation tried to change the user role directly. The system now promotes barbers through the barber record automatically.";
  }
  return m;
}

function parseSpecialties(raw: string) {
  const parts = raw
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  const unique = Array.from(new Set(parts));
  return unique;
}

function toNullableNumber(v: string) {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

export default async function AdminCreateBarberPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((params?.error ?? "").trim());

  const supabase = await createSupabaseServerClient();
  const { data: shops } = await supabase.from("barbershops").select("id, name").order("created_at", { ascending: false }).limit(250);
  const { data: services } = await supabase
    .from("services")
    .select("id, name_en, name_ar, shop_id, is_active, status, deleted_at")
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(500);

  async function createBarber(formData: FormData) {
    "use server";

    const fullName = String(formData.get("full_name") ?? "").trim();
    const email = String(formData.get("email") ?? "").trim().toLowerCase();
    const password = String(formData.get("password") ?? "");
    const phone = String(formData.get("phone") ?? "").trim();

    const bio = String(formData.get("bio") ?? "").trim();
    const area = String(formData.get("area") ?? "").trim();
    const experienceYearsRaw = String(formData.get("experience_years") ?? "").trim();
    const experienceYears = experienceYearsRaw ? Math.floor(Number(experienceYearsRaw)) : null;
    const specialtiesRaw = String(formData.get("specialties") ?? "").trim();
    const specialties = specialtiesRaw ? parseSpecialties(specialtiesRaw) : [];

    const shopId = String(formData.get("shop_id") ?? "").trim();
    const isIndependent = String(formData.get("is_independent") ?? "") === "on";

    const status = String(formData.get("status") ?? "approved").trim() || "approved";
    const isActive = String(formData.get("is_active") ?? "") === "on";
    const isVerified = String(formData.get("is_verified") ?? "") === "on";
    const commissionRateRaw = String(formData.get("commission_rate") ?? "").trim();
    const commissionRate = commissionRateRaw ? toNullableNumber(commissionRateRaw) : null;
    const instagram = String(formData.get("instagram") ?? "").trim();
    const tiktok = String(formData.get("tiktok") ?? "").trim();
    const serviceIds = formData
      .getAll("service_ids")
      .map((v) => String(v ?? "").trim())
      .filter(Boolean);

    const defaultStartTime = String(formData.get("default_start_time") ?? "09:00").trim() || "09:00";
    const defaultEndTime = String(formData.get("default_end_time") ?? "21:00").trim() || "21:00";

    const avatarFile = formData.get("avatar_file");
    const coverFile = formData.get("cover_file");

    if (!fullName || !email || !password) {
      redirect(`/create-barber?error=${encodeURIComponent("Name, email, and temporary password are required.")}`);
    }

    const adminSession = await createSupabaseServerClient();
    const { data: actorData } = await adminSession.auth.getUser();
    const actorId = actorData.user?.id ?? null;

    const admin = await createSupabaseAdminClient();
    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName }
    });
    if (createError) redirect(`/create-barber?error=${encodeURIComponent(userFacingDbError(createError.message))}`);

    const profileId = created.user?.id ?? "";
    if (!profileId) redirect(`/create-barber?error=${encodeURIComponent("Failed to create auth user.")}`);

    const { error: profileError } = await admin.from("profiles").upsert({
      id: profileId,
      email,
      full_name: fullName,
      phone: phone || null,
      role: "customer",
      status: "active",
      must_change_password: true
    });
    if (profileError) redirect(`/create-barber?error=${encodeURIComponent(userFacingDbError(profileError.message))}`);

    const effectiveShopId = isIndependent ? null : shopId || null;
    const effectiveBranchId = effectiveShopId ? await getOrCreatePrimaryBranchId(admin, effectiveShopId) : null;

    if (effectiveShopId && !effectiveBranchId) {
      redirect(`/create-barber?error=${encodeURIComponent("Failed to resolve a branch for the selected shop.")}`);
    }

    const { data: createdBarber, error: barberError } = await admin
      .from("barbers")
      .insert({
        profile_id: profileId,
        display_name: fullName,
        bio: bio || null,
        area: area || null,
        specialties,
        experience_years: experienceYears,
        shop_id: effectiveShopId,
        branch_id: effectiveBranchId,
        is_independent: !effectiveShopId,
        status,
        is_active: isActive,
        is_verified: isVerified,
        commission_rate: commissionRate,
        instagram: instagram || null,
        tiktok: tiktok || null,
        deleted_at: null
      })
      .select("id")
      .single();
    if (barberError) redirect(`/create-barber?error=${encodeURIComponent(userFacingDbError(barberError.message))}`);

    const barberId = createdBarber?.id ?? "";
    if (!barberId) redirect(`/create-barber?error=${encodeURIComponent("Failed to create barber.")}`);

    if (effectiveShopId) {
      try {
        await upsertShopMembership(admin, {
          profileId,
          shopId: effectiveShopId,
          branchId: effectiveBranchId,
          membershipRole: "barber"
        });
      } catch (e) {
        const msg = e instanceof Error ? e.message : "membership_sync_failed";
        await logAdminSyncError(admin, {
          actorId,
          page: "/create-barber",
          action: "create_barber_membership_sync",
          error: msg,
          meta: { barber_profile_id: profileId, shop_id: effectiveShopId, branch_id: effectiveBranchId }
        });
        redirect(`/create-barber?error=${encodeURIComponent(userFacingDbError(msg))}`);
      }
    }

    const uploadImage = async (file: File, kind: "avatar" | "cover") => {
      const prepared = await prepareImageFileForUpload(file);
      const objectPath = buildPreparedUploadPath(`barbers/${barberId}/${kind}-${randomUUID()}`, prepared.fileName, prepared.contentType);
      const { error: uploadError } = await admin.storage.from("barber-images").upload(objectPath, prepared.bytes, {
        contentType: prepared.contentType || undefined,
        upsert: false
      });
      if (uploadError) throw new Error(uploadError.message);
      return objectPath;
    };

    try {
      const updates: Record<string, string | null> = {};
      if (avatarFile instanceof File && avatarFile.size > 0) {
        const path = await uploadImage(avatarFile, "avatar");
        updates.avatar_path = path;
        updates.avatar_url = null;
      }
      if (coverFile instanceof File && coverFile.size > 0) {
        const path = await uploadImage(coverFile, "cover");
        updates.cover_path = path;
        updates.cover_url = null;
      }

      if (Object.keys(updates).length) {
        const { error: updateError } = await admin.from("barbers").update(updates).eq("id", barberId);
        if (updateError) throw new Error(updateError.message);
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Could not prepare the selected images.";
      redirect(`/create-barber?error=${encodeURIComponent(userFacingDbError(msg))}`);
    }

    const { data: existingHours, error: hoursCheckError } = await admin
      .from("barber_working_hours")
      .select("id")
      .eq("barber_id", barberId)
      .limit(1);
    if (hoursCheckError) redirect(`/create-barber?error=${encodeURIComponent(userFacingDbError(hoursCheckError.message))}`);

    if ((existingHours?.length ?? 0) === 0) {
      const rows = Array.from({ length: 7 }).map((_, weekday) => ({
        barber_id: barberId,
        weekday,
        start_time: defaultStartTime,
        end_time: defaultEndTime,
        enabled: true
      }));
      const { error: hoursInsertError } = await admin.from("barber_working_hours").insert(rows);
      if (hoursInsertError) redirect(`/create-barber?error=${encodeURIComponent(userFacingDbError(hoursInsertError.message))}`);
    }

    if (effectiveShopId && serviceIds.length) {
      const { data: allowed, error: allowedError } = await admin
        .from("services")
        .select("id")
        .eq("shop_id", effectiveShopId)
        .in("id", serviceIds)
        .is("deleted_at", null)
        .limit(1000);
      if (allowedError) redirect(`/create-barber?error=${encodeURIComponent(userFacingDbError(allowedError.message))}`);

      const rows = (allowed ?? []).map((s) => ({ service_id: s.id, barber_id: barberId }));
      if (rows.length) {
        const { error: mapError } = await admin.from("service_barbers").insert(rows);
        if (mapError) redirect(`/create-barber?error=${encodeURIComponent(userFacingDbError(mapError.message))}`);
      }
    }

    await admin.from("notifications").insert({
      profile_id: profileId,
      type: "system",
      title: "Your barber account has been created.",
      body: "Please change your password on first login."
    });

    if (actorId) {
      await adminSession.from("audit_events").insert({
        actor_profile_id: actorId,
        action: "admin_create_barber",
        entity_type: "barber",
        entity_id: barberId,
        meta: { profile_id: profileId, shop_id: effectiveShopId }
      });
    }

    redirect(`/barbers?created=${encodeURIComponent(barberId)}`);
  }

  return (
    <PageFrame
      title="Create Barber"
      subtitle="Creates a barber auth account + profile + barber record. Password is temporary and must be changed on first login."
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/barbers">Back</Link>
        </Button>
      }
    >
      {params?.error ? (
        <div className="mb-4 rounded-xl border border-rose-500/20 bg-rose-500/10 px-4 py-3 text-sm text-rose-100">
          {error}
        </div>
      ) : null}

      <form action={createBarber} className="grid gap-6" encType="multipart/form-data">
        <div className="grid gap-3">
          <div className="text-sm font-semibold">Barber account</div>
          <div className="grid gap-2">
            <Label htmlFor="full_name">Full name</Label>
            <Input id="full_name" name="full_name" required />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="email">Email</Label>
            <Input id="email" name="email" type="email" required />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="password">Temporary password</Label>
            <Input id="password" name="password" type="password" required />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="phone">Phone</Label>
            <Input id="phone" name="phone" placeholder="+973 ..." />
          </div>
        </div>

        <div className="grid gap-3">
          <div className="text-sm font-semibold">Profile details</div>
          <div className="grid gap-2">
            <Label htmlFor="bio">Bio</Label>
            <textarea
              id="bio"
              name="bio"
              className="min-h-24 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
            />
          </div>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div className="grid gap-2">
              <Label htmlFor="area">Area</Label>
              <Input id="area" name="area" />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="experience_years">Experience years</Label>
              <Input id="experience_years" name="experience_years" inputMode="numeric" placeholder="5" />
            </div>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="specialties">Specialties (comma-separated)</Label>
            <Input id="specialties" name="specialties" placeholder="Fade, Beard, ..." />
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
        </div>

        <div className="grid gap-3">
          <div className="text-sm font-semibold">Shop assignment</div>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div className="grid gap-2">
              <Label htmlFor="shop_id">Assign to shop (optional)</Label>
              {shops?.length ? (
                <select
                  id="shop_id"
                  name="shop_id"
                  defaultValue=""
                  className="flex h-10 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
                >
                  <option value="">No shop</option>
                  {shops.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.name}
                    </option>
                  ))}
                </select>
              ) : (
                <div className="text-sm text-muted-foreground">No shops found yet.</div>
              )}
            </div>
            <label className="flex items-center gap-2 pt-8 text-sm">
              <input type="checkbox" name="is_independent" />
              Independent barber
            </label>
          </div>
        </div>

        <div className="grid gap-3">
          <div className="text-sm font-semibold">Services assigned</div>
          {services?.length ? (
            <select
              name="service_ids"
              multiple
              className="min-h-40 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
            >
              {services.map((s) => {
                const shopName = (shops ?? []).find((sh) => sh.id === s.shop_id)?.name ?? "Shop";
                const label = (s.name_en ?? s.name_ar ?? "Service").trim() || "Service";
                return (
                  <option key={s.id} value={s.id}>
                    {label} • {shopName}
                  </option>
                );
              })}
            </select>
          ) : (
            <div className="text-sm text-muted-foreground">No services found yet.</div>
          )}
          <div className="text-xs text-muted-foreground">Service assignment is applied only when a shop is selected.</div>
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
              Active
            </label>
          </div>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div className="grid gap-2">
              <Label htmlFor="commission_rate">Commission rate (optional)</Label>
              <Input id="commission_rate" name="commission_rate" inputMode="decimal" placeholder="15" />
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
              <Label>Avatar</Label>
              <MediaFileInput name="avatar_file" accept="image/*" />
            </div>
            <div className="grid gap-2">
              <Label>Cover</Label>
              <MediaFileInput name="cover_file" accept="image/*" />
            </div>
          </div>
        </div>

        <div className="flex items-center justify-end gap-2 pt-2">
          <Button asChild variant="ghost">
            <Link href="/barbers">Cancel</Link>
          </Button>
          <Button type="submit">Create</Button>
        </div>
      </form>
    </PageFrame>
  );
}

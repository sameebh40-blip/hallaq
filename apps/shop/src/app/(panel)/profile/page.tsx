import { redirect } from "next/navigation";

import { randomUUID } from "crypto";

import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";

import { MediaFileInput } from "@/components/media-file-input";
import { getMyShop } from "@/lib/my-shop";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

function isValidGoogleMapsUrl(raw: string) {
  if (!raw) return false;
  try {
    const u = new URL(raw);
    const host = u.hostname.toLowerCase();
    const okHost =
      host === "maps.google.com" ||
      host.endsWith(".google.com") ||
      host === "goo.gl" ||
      host.endsWith(".goo.gl") ||
      host === "maps.app.goo.gl";
    if (!okHost) return false;
    if (host.includes("google.com") && !u.pathname.includes("/maps")) return false;
    return true;
  } catch {
    return false;
  }
}

function isValidHoursValue(raw: string) {
  if (!raw) return true;
  return /^\d{2}:\d{2}-\d{2}:\d{2}$/.test(raw);
}

export default async function ShopProfilePage({
  searchParams,
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const resolvedSearchParams = await searchParams;
  const supabase = await createAppSupabaseServerClient();
  const shop = await getMyShop(supabase);

  if (!shop) {
    return <div className="text-sm text-muted-foreground">No shop assigned to this account.</div>;
  }
  const openingHours =
    shop.opening_hours && typeof shop.opening_hours === "object" ? (shop.opening_hours as Record<string, string>) : {};

  async function save(formData: FormData) {
    "use server";

    const name = String(formData.get("name") ?? "").trim();
    const description = String(formData.get("description") ?? "").trim();
    const area = String(formData.get("area") ?? "").trim();
    const address = String(formData.get("address") ?? "").trim();
    const google_maps_url = String(formData.get("google_maps_url") ?? "").trim();
    const latRaw = String(formData.get("lat") ?? "").trim();
    const lngRaw = String(formData.get("lng") ?? "").trim();
    const phone = String(formData.get("phone") ?? "").trim();
    const whatsapp = String(formData.get("whatsapp") ?? "").trim();
    const instagram = String(formData.get("instagram") ?? "").trim();
    const oh_mon = String(formData.get("oh_mon") ?? "").trim();
    const oh_tue = String(formData.get("oh_tue") ?? "").trim();
    const oh_wed = String(formData.get("oh_wed") ?? "").trim();
    const oh_thu = String(formData.get("oh_thu") ?? "").trim();
    const oh_fri = String(formData.get("oh_fri") ?? "").trim();
    const oh_sat = String(formData.get("oh_sat") ?? "").trim();
    const oh_sun = String(formData.get("oh_sun") ?? "").trim();
    const home_service = formData.get("home_service") === "on";
    const logoFile = formData.get("logo_file");
    const coverFile = formData.get("cover_file");

    if (!name) redirect("/profile");
    if (google_maps_url && !isValidGoogleMapsUrl(google_maps_url)) {
      redirect("/profile?error=invalid_maps");
    }
    if (
      !isValidHoursValue(oh_mon) ||
      !isValidHoursValue(oh_tue) ||
      !isValidHoursValue(oh_wed) ||
      !isValidHoursValue(oh_thu) ||
      !isValidHoursValue(oh_fri) ||
      !isValidHoursValue(oh_sat) ||
      !isValidHoursValue(oh_sun)
    ) {
      redirect("/profile?error=invalid_hours");
    }
    const lat = latRaw ? Number(latRaw) : null;
    const lng = lngRaw ? Number(lngRaw) : null;
    const latValue = lat !== null && Number.isFinite(lat) ? lat : null;
    const lngValue = lng !== null && Number.isFinite(lng) ? lng : null;
    const opening_hours: Record<string, string> = {};
    if (oh_mon) opening_hours.mon = oh_mon;
    if (oh_tue) opening_hours.tue = oh_tue;
    if (oh_wed) opening_hours.wed = oh_wed;
    if (oh_thu) opening_hours.thu = oh_thu;
    if (oh_fri) opening_hours.fri = oh_fri;
    if (oh_sat) opening_hours.sat = oh_sat;
    if (oh_sun) opening_hours.sun = oh_sun;

    const supabase = await createAppSupabaseServerClient();
    const shop = await getMyShop(supabase);
    if (!shop) redirect("/profile");

    const { data: auth } = await supabase.auth.getUser();
    const userId = auth.user?.id ?? null;

    let logoPath: string | undefined;
    let coverPath: string | undefined;

    if (logoFile instanceof File && logoFile.size > 0) {
      const ext = logoFile.name.includes(".") ? logoFile.name.split(".").pop() : undefined;
      const safeExt = ext ? `.${ext.toLowerCase()}` : "";
      const objectPath = `shops/${shop.id}/logo-${randomUUID()}${safeExt}`;
      const bytes = new Uint8Array(await logoFile.arrayBuffer());
      const { error } = await supabase.storage
        .from("shop-images")
        .upload(objectPath, bytes, { contentType: logoFile.type, upsert: true });
      if (error) {
        try {
          await supabase.from("system_logs").insert({
            user_id: userId,
            page: "/shop/profile",
            action: "shop_logo_upload",
            error_message: error.message,
            severity: "error",
            meta: { shop_id: shop.id }
          });
        } catch {}
        redirect("/profile?error=logo_upload_failed");
      }
      logoPath = objectPath;
    }

    if (coverFile instanceof File && coverFile.size > 0) {
      const ext = coverFile.name.includes(".") ? coverFile.name.split(".").pop() : undefined;
      const safeExt = ext ? `.${ext.toLowerCase()}` : "";
      const objectPath = `shops/${shop.id}/cover-${randomUUID()}${safeExt}`;
      const bytes = new Uint8Array(await coverFile.arrayBuffer());
      const { error } = await supabase.storage
        .from("shop-images")
        .upload(objectPath, bytes, { contentType: coverFile.type, upsert: true });
      if (error) {
        try {
          await supabase.from("system_logs").insert({
            user_id: userId,
            page: "/shop/profile",
            action: "shop_cover_upload",
            error_message: error.message,
            severity: "error",
            meta: { shop_id: shop.id }
          });
        } catch {}
        redirect("/profile?error=cover_upload_failed");
      }
      coverPath = objectPath;
    }

    const { error: updateError } = await supabase
      .from("barbershops")
      .update({
        name,
        description: description || null,
        ...(logoPath ? { logo_path: logoPath, logo_url: null } : {}),
        ...(coverPath ? { cover_path: coverPath, cover_url: null } : {}),
        area: area || null,
        address: address || null,
        google_maps_url: google_maps_url || null,
        lat: latValue,
        lng: lngValue,
        opening_hours: Object.keys(opening_hours).length ? opening_hours : {},
        home_service,
        phone: phone || null,
        whatsapp: whatsapp || null,
        instagram: instagram || null,
      })
      .eq("id", shop.id);

    if (updateError) {
      try {
        await supabase.from("system_logs").insert({
          user_id: userId,
          page: "/shop/profile",
          action: "shop_profile_save",
          error_message: updateError.message,
          severity: "error",
          meta: { shop_id: shop.id }
        });
      } catch {}
      redirect("/profile?error=save_failed");
    }

    redirect("/profile");
  }

  return (
    <form action={save} className="grid gap-4" encType="multipart/form-data">
      {resolvedSearchParams?.error === "invalid_maps" ? (
        <div className="text-sm text-red-600">Invalid Google Maps URL. Example: https://maps.google.com/…</div>
      ) : resolvedSearchParams?.error === "invalid_hours" ? (
        <div className="text-sm text-red-600">Invalid opening hours. Use HH:MM-HH:MM (example: 10:00-22:00).</div>
      ) : resolvedSearchParams?.error === "logo_upload_failed" ? (
        <div className="text-sm text-red-600">Couldn’t upload the logo. Please try again.</div>
      ) : resolvedSearchParams?.error === "cover_upload_failed" ? (
        <div className="text-sm text-red-600">Couldn’t upload the cover image. Please try again.</div>
      ) : resolvedSearchParams?.error === "save_failed" ? (
        <div className="text-sm text-red-600">Couldn’t save changes. Please retry.</div>
      ) : null}
      <div className="grid gap-2">
        <Label>Logo</Label>
        <MediaFileInput name="logo_file" accept="image/*" />
      </div>
      <div className="grid gap-2">
        <Label>Cover</Label>
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
        <Label htmlFor="google_maps_url">Google Maps Link</Label>
        <Input id="google_maps_url" name="google_maps_url" defaultValue={shop.google_maps_url ?? ""} />
      </div>
      <div className="grid gap-2">
        <Label htmlFor="lat">Latitude</Label>
        <Input id="lat" name="lat" defaultValue={shop.lat ?? ""} />
      </div>
      <div className="grid gap-2">
        <Label htmlFor="lng">Longitude</Label>
        <Input id="lng" name="lng" defaultValue={shop.lng ?? ""} />
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
      <div className="flex items-center gap-2">
        <Input id="home_service" name="home_service" type="checkbox" defaultChecked={shop.home_service} className="h-4 w-4" />
        <Label htmlFor="home_service">Home Service</Label>
      </div>
      <div className="grid gap-2">
        <Label>Opening Hours (HH:MM-HH:MM)</Label>
        <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
          <div className="grid gap-1">
            <Label htmlFor="oh_sat">Sat</Label>
            <Input id="oh_sat" name="oh_sat" defaultValue={openingHours.sat ?? ""} placeholder="10:00-22:00" />
          </div>
          <div className="grid gap-1">
            <Label htmlFor="oh_sun">Sun</Label>
            <Input id="oh_sun" name="oh_sun" defaultValue={openingHours.sun ?? ""} placeholder="10:00-22:00" />
          </div>
          <div className="grid gap-1">
            <Label htmlFor="oh_mon">Mon</Label>
            <Input id="oh_mon" name="oh_mon" defaultValue={openingHours.mon ?? ""} placeholder="10:00-22:00" />
          </div>
          <div className="grid gap-1">
            <Label htmlFor="oh_tue">Tue</Label>
            <Input id="oh_tue" name="oh_tue" defaultValue={openingHours.tue ?? ""} placeholder="10:00-22:00" />
          </div>
          <div className="grid gap-1">
            <Label htmlFor="oh_wed">Wed</Label>
            <Input id="oh_wed" name="oh_wed" defaultValue={openingHours.wed ?? ""} placeholder="10:00-22:00" />
          </div>
          <div className="grid gap-1">
            <Label htmlFor="oh_thu">Thu</Label>
            <Input id="oh_thu" name="oh_thu" defaultValue={openingHours.thu ?? ""} placeholder="10:00-22:00" />
          </div>
          <div className="grid gap-1">
            <Label htmlFor="oh_fri">Fri</Label>
            <Input id="oh_fri" name="oh_fri" defaultValue={openingHours.fri ?? ""} placeholder="10:00-22:00" />
          </div>
        </div>
      </div>
      <div className="flex items-center justify-end gap-2 pt-2">
        <Button type="submit">Save</Button>
      </div>
    </form>
  );
}

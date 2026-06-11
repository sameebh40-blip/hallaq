import { redirect } from "next/navigation";

import { randomUUID } from "crypto";

import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getMyProfile } from "@hallaq/supabase/profile";

import { MediaFileInput } from "@/components/media-file-input";
import { getMyShopContext } from "@/lib/my-shop-context";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

function isValidGoogleMapsUrl(raw: string) {
  if (!raw) return false;
  try {
    const u = new URL(raw);
    const host = u.hostname.toLowerCase();
    const okHost = host === "maps.google.com" || host.endsWith(".google.com") || host === "goo.gl" || host.endsWith(".goo.gl") || host === "maps.app.goo.gl";
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

export default async function BusinessSettingsPage({ searchParams }: { searchParams?: Promise<{ error?: string; shopId?: string }> }) {
  const sp = searchParams ? await searchParams : undefined;
  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);
  const ctx = await getMyShopContext(supabase);
  const shopId = ctx.shop?.id ?? (profile?.role === "admin" ? (sp?.shopId ?? null) : null);

  if (!shopId) return <div className="text-sm text-muted-foreground">No shop selected.</div>;

  const { data: shop } = await supabase
    .from("barbershops")
    .select("id, name, description, area, address, google_maps_url, lat, lng, opening_hours, home_service, phone, whatsapp, instagram, logo_path, cover_path")
    .eq("id", shopId)
    .maybeSingle();

  if (!shop) return <div className="text-sm text-muted-foreground">Shop not found.</div>;

  const openingHours = shop.opening_hours && typeof shop.opening_hours === "object" ? (shop.opening_hours as Record<string, string>) : {};

  async function save(formData: FormData) {
    "use server";

    const shopId = String(formData.get("shop_id") ?? "").trim();
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

    if (!shopId || !name) redirect("/business/settings");
    if (google_maps_url && !isValidGoogleMapsUrl(google_maps_url)) redirect("/business/settings?error=invalid_maps");
    if (!isValidHoursValue(oh_mon) || !isValidHoursValue(oh_tue) || !isValidHoursValue(oh_wed) || !isValidHoursValue(oh_thu) || !isValidHoursValue(oh_fri) || !isValidHoursValue(oh_sat) || !isValidHoursValue(oh_sun)) {
      redirect("/business/settings?error=invalid_hours");
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
    const { data: auth } = await supabase.auth.getUser();
    const userId = auth.user?.id ?? null;

    let logoPath: string | undefined;
    let coverPath: string | undefined;

    if (logoFile instanceof File && logoFile.size > 0) {
      const ext = logoFile.name.includes(".") ? logoFile.name.split(".").pop() : undefined;
      const safeExt = ext ? `.${ext.toLowerCase()}` : "";
      const objectPath = `shops/${shopId}/logo-${randomUUID()}${safeExt}`;
      const bytes = new Uint8Array(await logoFile.arrayBuffer());
      const { error } = await supabase.storage.from("shop-images").upload(objectPath, bytes, { contentType: logoFile.type, upsert: true });
      if (error) {
        try {
          await supabase.from("system_logs").insert({
            user_id: userId,
            page: "/shop/business/settings",
            action: "shop_logo_upload",
            error_message: error.message,
            severity: "error",
            meta: { shop_id: shopId }
          });
        } catch {}
        redirect("/business/settings?error=logo_upload_failed");
      }
      logoPath = objectPath;
    }

    if (coverFile instanceof File && coverFile.size > 0) {
      const ext = coverFile.name.includes(".") ? coverFile.name.split(".").pop() : undefined;
      const safeExt = ext ? `.${ext.toLowerCase()}` : "";
      const objectPath = `shops/${shopId}/cover-${randomUUID()}${safeExt}`;
      const bytes = new Uint8Array(await coverFile.arrayBuffer());
      const { error } = await supabase.storage.from("shop-images").upload(objectPath, bytes, { contentType: coverFile.type, upsert: true });
      if (error) {
        try {
          await supabase.from("system_logs").insert({
            user_id: userId,
            page: "/shop/business/settings",
            action: "shop_cover_upload",
            error_message: error.message,
            severity: "error",
            meta: { shop_id: shopId }
          });
        } catch {}
        redirect("/business/settings?error=cover_upload_failed");
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
        instagram: instagram || null
      })
      .eq("id", shopId);

    if (updateError) {
      try {
        await supabase.from("system_logs").insert({
          user_id: userId,
          page: "/shop/business/settings",
          action: "shop_profile_save",
          error_message: updateError.message,
          severity: "error",
          meta: { shop_id: shopId }
        });
      } catch {}
      redirect("/business/settings?error=save_failed");
    }

    redirect("/business/settings");
  }

  return (
    <div className="grid gap-4">
      {sp?.error ? (
        <LuxuryCard className="border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">
          {sp.error === "invalid_maps"
            ? "Invalid Google Maps URL. Example: https://maps.google.com/…"
            : sp.error === "invalid_hours"
              ? "Invalid opening hours. Use HH:MM-HH:MM (example: 10:00-22:00)."
              : sp.error === "logo_upload_failed"
                ? "Couldn’t upload the logo. Please try again."
                : sp.error === "cover_upload_failed"
                  ? "Couldn’t upload the cover image. Please try again."
                  : sp.error === "save_failed"
                    ? "Couldn’t save changes. Please retry."
                    : "Something went wrong."}
        </LuxuryCard>
      ) : null}

      <LuxuryCard className="p-5">
        <form action={save} className="grid gap-4" encType="multipart/form-data">
          <input type="hidden" name="shop_id" value={shopId} />
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
          <div className="grid gap-2 md:grid-cols-2">
            <div className="grid gap-2">
              <Label htmlFor="area">Area</Label>
              <Input id="area" name="area" defaultValue={shop.area ?? ""} />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="address">Address</Label>
              <Input id="address" name="address" defaultValue={shop.address ?? ""} />
            </div>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="google_maps_url">Google Maps Link</Label>
            <Input id="google_maps_url" name="google_maps_url" defaultValue={shop.google_maps_url ?? ""} />
          </div>
          <div className="grid gap-2 md:grid-cols-2">
            <div className="grid gap-2">
              <Label htmlFor="lat">Latitude</Label>
              <Input id="lat" name="lat" defaultValue={shop.lat ?? ""} />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="lng">Longitude</Label>
              <Input id="lng" name="lng" defaultValue={shop.lng ?? ""} />
            </div>
          </div>
          <div className="grid gap-3">
            <div className="text-sm font-semibold">Working hours</div>
            <div className="grid gap-2 md:grid-cols-2">
              <div className="grid gap-2">
                <Label>Mon</Label>
                <Input name="oh_mon" placeholder="10:00-22:00" defaultValue={openingHours.mon ?? ""} />
              </div>
              <div className="grid gap-2">
                <Label>Tue</Label>
                <Input name="oh_tue" placeholder="10:00-22:00" defaultValue={openingHours.tue ?? ""} />
              </div>
              <div className="grid gap-2">
                <Label>Wed</Label>
                <Input name="oh_wed" placeholder="10:00-22:00" defaultValue={openingHours.wed ?? ""} />
              </div>
              <div className="grid gap-2">
                <Label>Thu</Label>
                <Input name="oh_thu" placeholder="10:00-22:00" defaultValue={openingHours.thu ?? ""} />
              </div>
              <div className="grid gap-2">
                <Label>Fri</Label>
                <Input name="oh_fri" placeholder="10:00-22:00" defaultValue={openingHours.fri ?? ""} />
              </div>
              <div className="grid gap-2">
                <Label>Sat</Label>
                <Input name="oh_sat" placeholder="10:00-22:00" defaultValue={openingHours.sat ?? ""} />
              </div>
              <div className="grid gap-2">
                <Label>Sun</Label>
                <Input name="oh_sun" placeholder="10:00-22:00" defaultValue={openingHours.sun ?? ""} />
              </div>
            </div>
          </div>
          <div className="grid gap-2 md:grid-cols-3">
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
          </div>
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" name="home_service" defaultChecked={Boolean(shop.home_service)} />
            Home service enabled
          </label>
          <div className="flex justify-end">
            <Button type="submit" variant="secondary">
              Save changes
            </Button>
          </div>
        </form>
      </LuxuryCard>
    </div>
  );
}


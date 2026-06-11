import Link from "next/link";
import { randomUUID } from "crypto";
import { notFound, redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";
import { SafeImage } from "@/components/safe-image";

export const dynamic = "force-dynamic";

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong.";
  if (m.toLowerCase().includes("bucket not found")) {
    return "Storage bucket not found. Run the storage migrations in Supabase to create the buckets.";
  }
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as an admin account.";
  }
  return m;
}

export default async function AdminServiceDetailsPage({
  params,
  searchParams
}: {
  params: Promise<{ id: string }>;
  searchParams?: Promise<{ error?: string }>;
}) {
  const { id } = await params;
  const sp = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((sp?.error ?? "").trim());

  const supabase = await createSupabaseServerClient();

  const { data: service } = await supabase
    .from("services")
    .select(
      "id, shop_id, barber_id, name_en, name_ar, price_bhd, duration_minutes, image_url, category, deposit_type, deposit_value, is_popular, is_active, created_at, deleted_at"
    )
    .eq("id", id)
    .maybeSingle();

  if (!service || service.deleted_at) notFound();

  const { data: shops } = await supabase
    .from("barbershops")
    .select("id, name")
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(400);

  const { data: barbers } = await supabase
    .from("barbers")
    .select("id, display_name, shop_id")
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(800);

  const { data: serviceImages } = await supabase
    .from("service_images")
    .select("id, public_url, position, is_primary")
    .eq("service_id", id)
    .order("position", { ascending: true })
    .order("created_at", { ascending: true })
    .limit(100);
  const shopNameById = new Map((shops ?? []).map((s) => [String(s.id), s.name ?? String(s.id)]));
  const barberLabelById = new Map(
    (barbers ?? []).map((b) => [
      String(b.id),
      `${b.display_name ?? b.id}${b.shop_id ? ` (${shopNameById.get(String(b.shop_id)) ?? b.shop_id})` : " (Independent)"}`
    ])
  );

  async function updateService(formData: FormData) {
    "use server";

    const serviceId = String(formData.get("id") ?? "").trim();
    const nameEn = String(formData.get("name_en") ?? "").trim();
    const nameAr = String(formData.get("name_ar") ?? "").trim();
    const category = String(formData.get("category") ?? "").trim();
    const shopId = String(formData.get("shop_id") ?? "").trim();
    const barberId = String(formData.get("barber_id") ?? "").trim();
    const priceBhd = Number(formData.get("price_bhd") ?? 0);
    const durationMin = Number(formData.get("duration_minutes") ?? 30);
    const depositType = String(formData.get("deposit_type") ?? "").trim();
    const depositValue = Number(formData.get("deposit_value") ?? 0);
    const isPopular = String(formData.get("is_popular") ?? "") === "on";
    const isActive = String(formData.get("is_active") ?? "") !== "off";

    if (!serviceId || !nameEn) redirect(`/services/${id}`);

    const supabase = await createSupabaseServerClient();
    let effectiveShopId = shopId || null;

    if (barberId) {
      const { data: barberRow, error: barberError } = await supabase.from("barbers").select("id, shop_id").eq("id", barberId).maybeSingle();
      if (barberError) redirect(`/services/${id}?error=${encodeURIComponent(barberError.message)}`);
      const barberShopId = String((barberRow as { shop_id?: unknown } | null)?.shop_id ?? "").trim() || null;
      if (effectiveShopId && barberShopId && effectiveShopId !== barberShopId) {
        redirect(`/services/${id}?error=${encodeURIComponent("Selected barber belongs to a different shop.")}`);
      }
      effectiveShopId = effectiveShopId ?? barberShopId;
    }

    const payload: Record<string, unknown> = {
      shop_id: effectiveShopId,
      barber_id: barberId || null,
      name_en: nameEn,
      name_ar: nameAr || null,
      category: category || null,
      price_bhd: priceBhd,
      duration_minutes: durationMin,
      is_popular: isPopular,
      is_active: isActive,
      deposit_type: depositType === "fixed" || depositType === "percent" ? depositType : null,
      deposit_value: depositValue > 0 ? depositValue : null
    };

    const { error: updateError } = await supabase.from("services").update(payload).eq("id", serviceId);
    if (updateError) redirect(`/services/${id}?error=${encodeURIComponent(updateError.message)}`);
    redirect(`/services/${id}`);
  }

  async function uploadImages(formData: FormData) {
    "use server";

    const serviceId = String(formData.get("service_id") ?? "").trim();
    const shopId = String(formData.get("shop_id") ?? "").trim();
    const barberId = String(formData.get("barber_id") ?? "").trim();
    const supabase = await createSupabaseServerClient();

    const { data: current } = await supabase
      .from("service_images")
      .select("id, position, is_primary")
      .eq("service_id", serviceId)
      .order("position", { ascending: true })
      .limit(200);
    const maxPos = Math.max(-1, ...((current ?? []).map((x) => x.position ?? 0)));
    const hasPrimary = Boolean((current ?? []).some((x) => x.is_primary));

    const files = formData.getAll("images");
    const picked = files.filter((f) => f instanceof File && f.size > 0) as File[];
    const prefix = barberId ? `barbers/${barberId}` : shopId ? `shops/${shopId}` : "admin";

    let pos = maxPos + 1;
    for (const item of picked.slice(0, 10)) {
      if (!(item.type ?? "").startsWith("image/")) {
        redirect(`/services/${id}?error=${encodeURIComponent("Only images are supported for service photos.")}`);
      }
      const ext = item.name.includes(".") ? item.name.split(".").pop() : undefined;
      const safeExt = ext ? `.${ext.toLowerCase()}` : "";
      const objectPath = `${prefix}/services/${serviceId}/${randomUUID()}${safeExt}`;
      const bytes = new Uint8Array(await item.arrayBuffer());
      const { error: uploadError } = await supabase.storage
        .from("service-images")
        .upload(objectPath, bytes, { contentType: item.type || "image/jpeg", upsert: true });
      if (uploadError) redirect(`/services/${id}?error=${encodeURIComponent(uploadError.message)}`);
      const publicUrl = supabase.storage.from("service-images").getPublicUrl(objectPath).data.publicUrl;
      const { error: imgError } = await supabase.from("service_images").insert({
        service_id: serviceId,
        storage_path: objectPath,
        public_url: publicUrl,
        position: pos,
        is_primary: !hasPrimary && pos === maxPos + 1
      });
      if (imgError) redirect(`/services/${id}?error=${encodeURIComponent(imgError.message)}`);
      pos += 1;
    }

    const { data } = await supabase
      .from("service_images")
      .select("public_url, position, is_primary")
      .eq("service_id", serviceId)
      .order("position", { ascending: true })
      .order("created_at", { ascending: true })
      .limit(100);
    const list = (data ?? []).slice();
    list.sort((a, b) => (a.is_primary === b.is_primary ? (a.position ?? 0) - (b.position ?? 0) : a.is_primary ? -1 : 1));
    const primary = list[0]?.public_url ?? null;
    await supabase.from("services").update({ image_url: primary }).eq("id", serviceId);
    redirect(`/services/${id}`);
  }

  async function setPrimaryImage(formData: FormData) {
    "use server";

    const serviceId = String(formData.get("service_id") ?? "").trim();
    const imageId = String(formData.get("image_id") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { error: clearError } = await supabase.from("service_images").update({ is_primary: false }).eq("service_id", serviceId);
    if (clearError) redirect(`/services/${id}?error=${encodeURIComponent(clearError.message)}`);
    const { error: setError } = await supabase.from("service_images").update({ is_primary: true }).eq("id", imageId);
    if (setError) redirect(`/services/${id}?error=${encodeURIComponent(setError.message)}`);
    const { data } = await supabase
      .from("service_images")
      .select("public_url, position, is_primary")
      .eq("service_id", serviceId)
      .order("position", { ascending: true })
      .order("created_at", { ascending: true })
      .limit(100);
    const list = (data ?? []).slice();
    list.sort((a, b) => (a.is_primary === b.is_primary ? (a.position ?? 0) - (b.position ?? 0) : a.is_primary ? -1 : 1));
    const primary = list[0]?.public_url ?? null;
    await supabase.from("services").update({ image_url: primary }).eq("id", serviceId);
    redirect(`/services/${id}`);
  }

  async function moveImage(formData: FormData) {
    "use server";

    const serviceId = String(formData.get("service_id") ?? "").trim();
    const imageId = String(formData.get("image_id") ?? "").trim();
    const direction = String(formData.get("direction") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { data: imgs, error } = await supabase
      .from("service_images")
      .select("id, position, is_primary")
      .eq("service_id", serviceId)
      .order("position", { ascending: true })
      .order("created_at", { ascending: true })
      .limit(200);
    if (error) redirect(`/services/${id}?error=${encodeURIComponent(error.message)}`);
    const list = (imgs ?? []).slice();
    list.sort((a, b) => (a.position ?? 0) - (b.position ?? 0));
    const idx = list.findIndex((x) => x.id === imageId);
    if (idx < 0) redirect(`/services/${id}`);
    const nextIdx = direction === "up" ? idx - 1 : direction === "down" ? idx + 1 : idx;
    if (nextIdx < 0 || nextIdx >= list.length) redirect(`/services/${id}`);
    const tmp = list[idx];
    list[idx] = list[nextIdx];
    list[nextIdx] = tmp;
    for (let i = 0; i < list.length; i += 1) {
      const { error: uErr } = await supabase.from("service_images").update({ position: i }).eq("id", list[i].id);
      if (uErr) redirect(`/services/${id}?error=${encodeURIComponent(uErr.message)}`);
    }
    const { data } = await supabase
      .from("service_images")
      .select("public_url, position, is_primary")
      .eq("service_id", serviceId)
      .order("position", { ascending: true })
      .order("created_at", { ascending: true })
      .limit(100);
    const list2 = (data ?? []).slice();
    list2.sort((a, b) => (a.is_primary === b.is_primary ? (a.position ?? 0) - (b.position ?? 0) : a.is_primary ? -1 : 1));
    const primary = list2[0]?.public_url ?? null;
    await supabase.from("services").update({ image_url: primary }).eq("id", serviceId);
    redirect(`/services/${id}`);
  }

  async function deleteImage(formData: FormData) {
    "use server";

    const serviceId = String(formData.get("service_id") ?? "").trim();
    const imageId = String(formData.get("image_id") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { error: delError } = await supabase.from("service_images").delete().eq("id", imageId);
    if (delError) redirect(`/services/${id}?error=${encodeURIComponent(delError.message)}`);

    const { data: imgs } = await supabase
      .from("service_images")
      .select("id, position, is_primary")
      .eq("service_id", serviceId)
      .order("position", { ascending: true })
      .order("created_at", { ascending: true })
      .limit(200);
    const list = (imgs ?? []).slice();
    list.sort((a, b) => (a.position ?? 0) - (b.position ?? 0));
    const hasPrimary = list.some((x) => x.is_primary);
    for (let i = 0; i < list.length; i += 1) {
      const row = list[i];
      const shouldPrimary = !hasPrimary && i === 0;
      const { error: uErr } = await supabase
        .from("service_images")
        .update({ position: i, is_primary: shouldPrimary ? true : row.is_primary })
        .eq("id", row.id);
      if (uErr) redirect(`/services/${id}?error=${encodeURIComponent(uErr.message)}`);
    }
    const { data } = await supabase
      .from("service_images")
      .select("public_url, position, is_primary")
      .eq("service_id", serviceId)
      .order("position", { ascending: true })
      .order("created_at", { ascending: true })
      .limit(100);
    const list2 = (data ?? []).slice();
    list2.sort((a, b) => (a.is_primary === b.is_primary ? (a.position ?? 0) - (b.position ?? 0) : a.is_primary ? -1 : 1));
    const primary = list2[0]?.public_url ?? null;
    await supabase.from("services").update({ image_url: primary }).eq("id", serviceId);
    redirect(`/services/${id}`);
  }

  async function deleteService(formData: FormData) {
    "use server";

    const serviceId = String(formData.get("id") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase
      .from("services")
      .update({ deleted_at: new Date().toISOString(), is_active: false })
      .eq("id", serviceId);
    if (error) redirect(`/services/${id}?error=${encodeURIComponent(error.message)}`);
    redirect("/services");
  }

  return (
    <PageFrame
      title={service.name_en ?? "Service"}
      subtitle="Edit service details and photo."
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/services">Back</Link>
        </Button>
      }
    >
      {sp?.error ? (
        <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard>
      ) : null}

      <LuxuryCard className="mb-6 p-5">
        <form action={updateService} className="grid gap-4 md:grid-cols-3">
          <input type="hidden" name="id" value={service.id} />

          <div className="grid gap-2 md:col-span-2">
            <Label htmlFor="name_en">Name (EN)</Label>
            <Input id="name_en" name="name_en" defaultValue={service.name_en ?? ""} required />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="name_ar">Name (AR)</Label>
            <Input id="name_ar" name="name_ar" defaultValue={service.name_ar ?? ""} />
          </div>

          <div className="grid gap-2">
            <Label htmlFor="price_bhd">Price (BHD)</Label>
            <Input id="price_bhd" name="price_bhd" type="number" step="0.001" defaultValue={String(service.price_bhd ?? 0)} />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="duration_minutes">Duration (min)</Label>
            <Input
              id="duration_minutes"
              name="duration_minutes"
              type="number"
              defaultValue={String(service.duration_minutes ?? 30)}
            />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="category">Category</Label>
            <Input id="category" name="category" defaultValue={service.category ?? ""} />
          </div>

          <div className="grid gap-2">
            <Label htmlFor="shop_id">Shop</Label>
            <select
              id="shop_id"
              name="shop_id"
              className="h-10 rounded-md border border-white/10 bg-transparent px-3 text-sm"
              defaultValue={service.shop_id ?? ""}
            >
              <option value="">None</option>
              {(shops ?? []).map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
          </div>

          <div className="grid gap-2">
            <Label htmlFor="barber_id">Barber</Label>
            <select
              id="barber_id"
              name="barber_id"
              className="h-10 rounded-md border border-white/10 bg-transparent px-3 text-sm"
              defaultValue={service.barber_id ?? ""}
            >
              <option value="">None</option>
              {(barbers ?? []).map((b) => (
                <option key={b.id} value={b.id}>
                  {barberLabelById.get(String(b.id)) ?? b.display_name}
                </option>
              ))}
            </select>
          </div>

          <div className="grid gap-2">
            <Label>Deposit</Label>
            <div className="grid grid-cols-2 gap-2">
              <select
                name="deposit_type"
                className="h-10 rounded-md border border-white/10 bg-transparent px-3 text-sm"
                defaultValue={service.deposit_type ?? ""}
              >
                <option value="">No deposit</option>
                <option value="fixed">Fixed</option>
                <option value="percent">Percent</option>
              </select>
              <Input
                name="deposit_value"
                type="number"
                step="0.001"
                defaultValue={String(service.deposit_value ?? 0)}
              />
            </div>
          </div>

          <div className="flex items-center gap-4 md:col-span-3">
            <label className="flex items-center gap-2 text-sm">
              <input type="checkbox" name="is_popular" className="h-4 w-4" defaultChecked={Boolean(service.is_popular)} />
              Popular
            </label>
            <label className="flex items-center gap-2 text-sm">
              <input type="checkbox" name="is_active" className="h-4 w-4" defaultChecked={Boolean(service.is_active)} />
              Active
            </label>
            <div className="flex-1" />
            <Button type="submit" variant="ghost" formAction={deleteService}>
              Delete
            </Button>
            <Button type="submit">Save</Button>
          </div>
        </form>
      </LuxuryCard>

      <LuxuryCard className="p-5">
        <div className="mb-3 text-sm font-semibold">Images</div>
        <form action={uploadImages} className="flex flex-col gap-3" encType="multipart/form-data">
          <input type="hidden" name="service_id" value={service.id} />
          <input type="hidden" name="shop_id" value={service.shop_id ?? ""} />
          <input type="hidden" name="barber_id" value={service.barber_id ?? ""} />
          <input name="images" type="file" accept="image/*" multiple className="text-sm" />
          <div className="flex justify-end">
            <Button type="submit" variant="secondary">
              Upload
            </Button>
          </div>
        </form>

        {serviceImages?.length ? (
          <div className="mt-4 grid gap-3 md:grid-cols-2">
            {serviceImages
              .slice()
              .sort((a, b) => (a.is_primary === b.is_primary ? (a.position ?? 0) - (b.position ?? 0) : a.is_primary ? -1 : 1))
              .map((img, idx, list) => (
                <div key={img.id} className="flex items-center gap-3 rounded-lg border border-white/10 bg-white/5 p-3">
                  <SafeImage
                    src={img.public_url}
                    fallbackKey="default_service_image"
                    width={76}
                    height={76}
                    className="h-16 w-24 rounded-md object-cover"
                  />
                  <div className="flex-1">
                    <div className="text-xs text-muted-foreground">{img.is_primary ? "Primary" : `#${idx + 1}`}</div>
                    <div className="mt-2 flex flex-wrap gap-2">
                      <form action={setPrimaryImage}>
                        <input type="hidden" name="service_id" value={service.id} />
                        <input type="hidden" name="image_id" value={img.id} />
                        <Button type="submit" size="sm" variant="ghost" disabled={img.is_primary}>
                          Set primary
                        </Button>
                      </form>
                      <form action={moveImage}>
                        <input type="hidden" name="service_id" value={service.id} />
                        <input type="hidden" name="image_id" value={img.id} />
                        <input type="hidden" name="direction" value="up" />
                        <Button type="submit" size="sm" variant="ghost" disabled={idx === 0}>
                          Up
                        </Button>
                      </form>
                      <form action={moveImage}>
                        <input type="hidden" name="service_id" value={service.id} />
                        <input type="hidden" name="image_id" value={img.id} />
                        <input type="hidden" name="direction" value="down" />
                        <Button type="submit" size="sm" variant="ghost" disabled={idx === list.length - 1}>
                          Down
                        </Button>
                      </form>
                      <form action={deleteImage}>
                        <input type="hidden" name="service_id" value={service.id} />
                        <input type="hidden" name="image_id" value={img.id} />
                        <Button type="submit" size="sm" variant="ghost">
                          Remove
                        </Button>
                      </form>
                    </div>
                  </div>
                </div>
              ))}
          </div>
        ) : (
          <div className="mt-3 text-xs text-muted-foreground">No images.</div>
        )}
      </LuxuryCard>
    </PageFrame>
  );
}

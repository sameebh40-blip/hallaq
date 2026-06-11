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

export default async function AdminServiceTemplateDetailsPage({
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

  const { data: template } = await supabase
    .from("service_templates")
    .select("id, name_en, name_ar, description_en, description_ar, price_bhd, duration_minutes, category, deposit_type, deposit_value, created_at")
    .eq("id", id)
    .maybeSingle();

  if (!template) notFound();

  const { data: templateImages } = await supabase
    .from("service_template_images")
    .select("id, public_url, position, is_primary")
    .eq("template_id", id)
    .order("position", { ascending: true })
    .order("created_at", { ascending: true })
    .limit(100);

  async function updateTemplate(formData: FormData) {
    "use server";

    const templateId = String(formData.get("id") ?? "").trim();
    const nameEn = String(formData.get("name_en") ?? "").trim();
    const nameAr = String(formData.get("name_ar") ?? "").trim();
    const descriptionEn = String(formData.get("description_en") ?? "").trim();
    const descriptionAr = String(formData.get("description_ar") ?? "").trim();
    const category = String(formData.get("category") ?? "").trim();
    const priceBhd = Number(formData.get("price_bhd") ?? 0);
    const durationMin = Number(formData.get("duration_minutes") ?? 30);
    const depositType = String(formData.get("deposit_type") ?? "").trim();
    const depositValue = Number(formData.get("deposit_value") ?? 0);

    if (!templateId || !nameEn) redirect(`/service-templates/${id}`);

    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("service_templates").update({
      name_en: nameEn,
      name_ar: nameAr || null,
      description_en: descriptionEn || null,
      description_ar: descriptionAr || null,
      category: category || null,
      price_bhd: priceBhd,
      duration_minutes: durationMin,
      deposit_type: depositType === "fixed" || depositType === "percent" ? depositType : null,
      deposit_value: depositValue > 0 ? depositValue : null
    }).eq("id", templateId);
    if (error) redirect(`/service-templates/${id}?error=${encodeURIComponent(error.message)}`);
    redirect(`/service-templates/${id}`);
  }

  async function removeTemplate(formData: FormData) {
    "use server";

    const templateId = String(formData.get("id") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("service_templates").delete().eq("id", templateId);
    if (error) redirect(`/service-templates/${id}?error=${encodeURIComponent(error.message)}`);
    redirect("/service-templates");
  }

  async function uploadImages(formData: FormData) {
    "use server";

    const templateId = String(formData.get("template_id") ?? "").trim();
    const supabase = await createSupabaseServerClient();

    const { data: current } = await supabase
      .from("service_template_images")
      .select("id, position, is_primary")
      .eq("template_id", templateId)
      .order("position", { ascending: true })
      .limit(200);
    const maxPos = Math.max(-1, ...((current ?? []).map((x) => x.position ?? 0)));
    const hasPrimary = Boolean((current ?? []).some((x) => x.is_primary));

    const files = formData.getAll("images");
    const picked = files.filter((f) => f instanceof File && f.size > 0) as File[];
    let pos = maxPos + 1;
    for (const item of picked.slice(0, 10)) {
      if (!(item.type ?? "").startsWith("image/")) {
        redirect(`/service-templates/${id}?error=${encodeURIComponent("Only images are supported for template photos.")}`);
      }
      const ext = item.name.includes(".") ? item.name.split(".").pop() : undefined;
      const safeExt = ext ? `.${ext.toLowerCase()}` : "";
      const objectPath = `admin/templates/${templateId}/${randomUUID()}${safeExt}`;
      const bytes = new Uint8Array(await item.arrayBuffer());
      const { error: uploadError } = await supabase.storage
        .from("service-images")
        .upload(objectPath, bytes, { contentType: item.type || "image/jpeg", upsert: true });
      if (uploadError) redirect(`/service-templates/${id}?error=${encodeURIComponent(uploadError.message)}`);
      const publicUrl = supabase.storage.from("service-images").getPublicUrl(objectPath).data.publicUrl;
      const { error: imgError } = await supabase.from("service_template_images").insert({
        template_id: templateId,
        storage_path: objectPath,
        public_url: publicUrl,
        position: pos,
        is_primary: !hasPrimary && pos === maxPos + 1
      });
      if (imgError) redirect(`/service-templates/${id}?error=${encodeURIComponent(imgError.message)}`);
      pos += 1;
    }
    redirect(`/service-templates/${id}`);
  }

  async function setPrimaryImage(formData: FormData) {
    "use server";

    const templateId = String(formData.get("template_id") ?? "").trim();
    const imageId = String(formData.get("image_id") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { error: clearError } = await supabase.from("service_template_images").update({ is_primary: false }).eq("template_id", templateId);
    if (clearError) redirect(`/service-templates/${id}?error=${encodeURIComponent(clearError.message)}`);
    const { error: setError } = await supabase.from("service_template_images").update({ is_primary: true }).eq("id", imageId);
    if (setError) redirect(`/service-templates/${id}?error=${encodeURIComponent(setError.message)}`);
    redirect(`/service-templates/${id}`);
  }

  async function moveImage(formData: FormData) {
    "use server";

    const templateId = String(formData.get("template_id") ?? "").trim();
    const imageId = String(formData.get("image_id") ?? "").trim();
    const direction = String(formData.get("direction") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { data: imgs, error } = await supabase
      .from("service_template_images")
      .select("id, position, is_primary")
      .eq("template_id", templateId)
      .order("position", { ascending: true })
      .order("created_at", { ascending: true })
      .limit(200);
    if (error) redirect(`/service-templates/${id}?error=${encodeURIComponent(error.message)}`);
    const list = (imgs ?? []).slice();
    list.sort((a, b) => (a.position ?? 0) - (b.position ?? 0));
    const idx = list.findIndex((x) => x.id === imageId);
    if (idx < 0) redirect(`/service-templates/${id}`);
    const nextIdx = direction === "up" ? idx - 1 : direction === "down" ? idx + 1 : idx;
    if (nextIdx < 0 || nextIdx >= list.length) redirect(`/service-templates/${id}`);
    const tmp = list[idx];
    list[idx] = list[nextIdx];
    list[nextIdx] = tmp;
    for (let i = 0; i < list.length; i += 1) {
      const { error: uErr } = await supabase.from("service_template_images").update({ position: i }).eq("id", list[i].id);
      if (uErr) redirect(`/service-templates/${id}?error=${encodeURIComponent(uErr.message)}`);
    }
    redirect(`/service-templates/${id}`);
  }

  async function deleteImage(formData: FormData) {
    "use server";

    const templateId = String(formData.get("template_id") ?? "").trim();
    const imageId = String(formData.get("image_id") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { error: delError } = await supabase.from("service_template_images").delete().eq("id", imageId);
    if (delError) redirect(`/service-templates/${id}?error=${encodeURIComponent(delError.message)}`);

    const { data: imgs } = await supabase
      .from("service_template_images")
      .select("id, position, is_primary")
      .eq("template_id", templateId)
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
        .from("service_template_images")
        .update({ position: i, is_primary: shouldPrimary ? true : row.is_primary })
        .eq("id", row.id);
      if (uErr) redirect(`/service-templates/${id}?error=${encodeURIComponent(uErr.message)}`);
    }
    redirect(`/service-templates/${id}`);
  }

  const imgs = (templateImages ?? []).slice();
  imgs.sort((a, b) => (a.is_primary === b.is_primary ? (a.position ?? 0) - (b.position ?? 0) : a.is_primary ? -1 : 1));

  return (
    <PageFrame
      title={template.name_en ?? "Template"}
      subtitle="Edit template details and images."
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/service-templates">Back</Link>
        </Button>
      }
    >
      {sp?.error ? (
        <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard>
      ) : null}

      <LuxuryCard className="mb-6 p-5">
        <form action={updateTemplate} className="grid gap-4 md:grid-cols-3">
          <input type="hidden" name="id" value={template.id} />
          <div className="grid gap-2 md:col-span-2">
            <Label htmlFor="name_en">Name (EN)</Label>
            <Input id="name_en" name="name_en" defaultValue={template.name_en ?? ""} required />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="name_ar">Name (AR)</Label>
            <Input id="name_ar" name="name_ar" defaultValue={template.name_ar ?? ""} />
          </div>
          <div className="grid gap-2 md:col-span-3">
            <Label htmlFor="description_en">Description (EN)</Label>
            <Input id="description_en" name="description_en" defaultValue={template.description_en ?? ""} />
          </div>
          <div className="grid gap-2 md:col-span-3">
            <Label htmlFor="description_ar">Description (AR)</Label>
            <Input id="description_ar" name="description_ar" defaultValue={template.description_ar ?? ""} />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="price_bhd">Price (BHD)</Label>
            <Input id="price_bhd" name="price_bhd" type="number" step="0.001" defaultValue={String(template.price_bhd ?? 0)} />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="duration_minutes">Duration (min)</Label>
            <Input id="duration_minutes" name="duration_minutes" type="number" defaultValue={String(template.duration_minutes ?? 30)} />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="category">Category</Label>
            <Input id="category" name="category" defaultValue={template.category ?? ""} />
          </div>
          <div className="grid gap-2">
            <Label>Deposit</Label>
            <div className="grid grid-cols-2 gap-2">
              <select
                name="deposit_type"
                className="h-10 rounded-md border border-white/10 bg-transparent px-3 text-sm"
                defaultValue={template.deposit_type ?? ""}
              >
                <option value="">No deposit</option>
                <option value="fixed">Fixed</option>
                <option value="percent">Percent</option>
              </select>
              <Input name="deposit_value" type="number" step="0.001" defaultValue={String(template.deposit_value ?? 0)} />
            </div>
          </div>
          <div className="flex items-center justify-end gap-2 pt-2 md:col-span-3">
            <Button type="submit" variant="ghost" formAction={removeTemplate}>
              Delete
            </Button>
            <Button type="submit">Save</Button>
          </div>
        </form>
      </LuxuryCard>

      <LuxuryCard className="p-5">
        <div className="mb-3 text-sm font-semibold">Images</div>
        <form action={uploadImages} className="flex flex-col gap-3" encType="multipart/form-data">
          <input type="hidden" name="template_id" value={template.id} />
          <input name="images" type="file" accept="image/*" multiple className="text-sm" />
          <div className="flex justify-end">
            <Button type="submit" variant="secondary">
              Upload
            </Button>
          </div>
        </form>

        {imgs.length ? (
          <div className="mt-4 grid gap-3 md:grid-cols-2">
            {imgs.map((img, idx) => (
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
                      <input type="hidden" name="template_id" value={template.id} />
                      <input type="hidden" name="image_id" value={img.id} />
                      <Button type="submit" size="sm" variant="ghost" disabled={img.is_primary}>
                        Set primary
                      </Button>
                    </form>
                    <form action={moveImage}>
                      <input type="hidden" name="template_id" value={template.id} />
                      <input type="hidden" name="image_id" value={img.id} />
                      <input type="hidden" name="direction" value="up" />
                      <Button type="submit" size="sm" variant="ghost" disabled={idx === 0}>
                        Up
                      </Button>
                    </form>
                    <form action={moveImage}>
                      <input type="hidden" name="template_id" value={template.id} />
                      <input type="hidden" name="image_id" value={img.id} />
                      <input type="hidden" name="direction" value="down" />
                      <Button type="submit" size="sm" variant="ghost" disabled={idx === imgs.length - 1}>
                        Down
                      </Button>
                    </form>
                    <form action={deleteImage}>
                      <input type="hidden" name="template_id" value={template.id} />
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

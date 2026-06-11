import Link from "next/link";
import { randomUUID } from "crypto";
import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

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

export default async function AdminServiceTemplatesPage({ searchParams }: { searchParams?: Promise<{ error?: string }> }) {
  const params = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((params?.error ?? "").trim());

  const supabase = await createSupabaseServerClient();

  const { data: templates } = await supabase
    .from("service_templates")
    .select("id, name_en, name_ar, price_bhd, duration_minutes, category, deposit_type, deposit_value, created_at")
    .order("created_at", { ascending: false })
    .limit(200);

  async function createTemplate(formData: FormData) {
    "use server";

    const nameEn = String(formData.get("name_en") ?? "").trim();
    const nameAr = String(formData.get("name_ar") ?? "").trim();
    const descriptionEn = String(formData.get("description_en") ?? "").trim();
    const descriptionAr = String(formData.get("description_ar") ?? "").trim();
    const category = String(formData.get("category") ?? "").trim();
    const priceBhd = Number(formData.get("price_bhd") ?? 0);
    const durationMin = Number(formData.get("duration_minutes") ?? 30);
    const depositType = String(formData.get("deposit_type") ?? "").trim();
    const depositValue = Number(formData.get("deposit_value") ?? 0);
    const files = formData.getAll("images");

    if (!nameEn) redirect("/service-templates");

    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const { data: inserted, error: insertError } = await supabase
      .from("service_templates")
      .insert({
        name_en: nameEn,
        name_ar: nameAr || null,
        description_en: descriptionEn || null,
        description_ar: descriptionAr || null,
        category: category || null,
        price_bhd: priceBhd,
        duration_minutes: durationMin,
        deposit_type: depositType === "fixed" || depositType === "percent" ? depositType : null,
        deposit_value: depositValue > 0 ? depositValue : null,
        created_by: actorId
      })
      .select("id")
      .maybeSingle();

    if (insertError) redirect(`/service-templates?error=${encodeURIComponent(insertError.message)}`);
    const templateId = inserted?.id;
    if (!templateId) redirect("/service-templates");

    const picked = files.filter((f) => f instanceof File && f.size > 0) as File[];
    let pos = 0;
    for (const item of picked.slice(0, 10)) {
      if (!(item.type ?? "").startsWith("image/")) {
        redirect(`/service-templates?error=${encodeURIComponent("Only images are supported for template photos.")}`);
      }
      const ext = item.name.includes(".") ? item.name.split(".").pop() : undefined;
      const safeExt = ext ? `.${ext.toLowerCase()}` : "";
      const objectPath = `admin/templates/${templateId}/${randomUUID()}${safeExt}`;
      const bytes = new Uint8Array(await item.arrayBuffer());
      const { error: uploadError } = await supabase.storage
        .from("service-images")
        .upload(objectPath, bytes, { contentType: item.type || "image/jpeg", upsert: true });
      if (uploadError) redirect(`/service-templates?error=${encodeURIComponent(uploadError.message)}`);
      const publicUrl = supabase.storage.from("service-images").getPublicUrl(objectPath).data.publicUrl;
      const { error: imgError } = await supabase.from("service_template_images").insert({
        template_id: templateId,
        storage_path: objectPath,
        public_url: publicUrl,
        position: pos,
        is_primary: pos === 0
      });
      if (imgError) redirect(`/service-templates?error=${encodeURIComponent(imgError.message)}`);
      pos += 1;
    }

    redirect(`/service-templates/${templateId}`);
  }

  async function removeTemplate(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("service_templates").delete().eq("id", id);
    if (error) redirect(`/service-templates?error=${encodeURIComponent(error.message)}`);
    redirect("/service-templates");
  }

  return (
    <PageFrame
      title="Service templates"
      subtitle="Create reusable service templates (with photos) and apply them when creating services."
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/services">Back</Link>
        </Button>
      }
    >
      {params?.error ? (
        <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard>
      ) : null}

      <LuxuryCard className="mb-6 p-5">
        <form action={createTemplate} className="grid gap-4 md:grid-cols-3" encType="multipart/form-data">
          <div className="grid gap-2 md:col-span-2">
            <Label htmlFor="name_en">Name (EN)</Label>
            <Input id="name_en" name="name_en" required />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="name_ar">Name (AR)</Label>
            <Input id="name_ar" name="name_ar" />
          </div>
          <div className="grid gap-2 md:col-span-3">
            <Label htmlFor="description_en">Description (EN)</Label>
            <Input id="description_en" name="description_en" />
          </div>
          <div className="grid gap-2 md:col-span-3">
            <Label htmlFor="description_ar">Description (AR)</Label>
            <Input id="description_ar" name="description_ar" />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="price_bhd">Price (BHD)</Label>
            <Input id="price_bhd" name="price_bhd" type="number" step="0.001" defaultValue="0" />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="duration_minutes">Duration (min)</Label>
            <Input id="duration_minutes" name="duration_minutes" type="number" defaultValue="30" />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="category">Category</Label>
            <Input id="category" name="category" />
          </div>
          <div className="grid gap-2">
            <Label>Deposit</Label>
            <div className="grid grid-cols-2 gap-2">
              <select
                name="deposit_type"
                className="h-10 rounded-md border border-white/10 bg-transparent px-3 text-sm"
                defaultValue=""
              >
                <option value="">No deposit</option>
                <option value="fixed">Fixed</option>
                <option value="percent">Percent</option>
              </select>
              <Input name="deposit_value" type="number" step="0.001" defaultValue="0" />
            </div>
          </div>
          <div className="grid gap-2 md:col-span-3">
            <Label>Images</Label>
            <input name="images" type="file" accept="image/*" multiple className="text-sm" />
          </div>
          <div className="flex items-center gap-4 md:col-span-3">
            <div className="flex-1" />
            <Button type="submit" variant="secondary">
              Create template
            </Button>
          </div>
        </form>
      </LuxuryCard>

      <LuxuryCard className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[980px] text-sm">
            <thead className="text-xs text-muted-foreground">
              <tr className="border-b border-white/10">
                <th className="px-4 py-3 text-left font-medium">Template</th>
                <th className="px-4 py-3 text-left font-medium">Category</th>
                <th className="px-4 py-3 text-left font-medium">Price</th>
                <th className="px-4 py-3 text-left font-medium">Duration</th>
                <th className="px-4 py-3 text-right font-medium">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/10">
              {templates?.length ? (
                templates.map((t) => (
                  <tr key={t.id}>
                    <td className="px-4 py-3">
                      <div className="font-medium">{t.name_en}</div>
                      {t.name_ar ? <div className="text-xs text-muted-foreground">{t.name_ar}</div> : null}
                      <div className="pt-1">
                        <Button asChild variant="ghost" size="sm">
                          <Link href={`/service-templates/${t.id}`}>Edit</Link>
                        </Button>
                      </div>
                    </td>
                    <td className="px-4 py-3">{t.category ?? "—"}</td>
                    <td className="px-4 py-3">{Number(t.price_bhd ?? 0).toFixed(3)} BHD</td>
                    <td className="px-4 py-3">{t.duration_minutes ?? 30} min</td>
                    <td className="px-4 py-3 text-right">
                      <form action={removeTemplate}>
                        <input type="hidden" name="id" value={t.id} />
                        <Button type="submit" size="sm" variant="ghost">
                          Delete
                        </Button>
                      </form>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td className="px-4 py-6 text-muted-foreground" colSpan={5}>
                    No templates yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </LuxuryCard>
    </PageFrame>
  );
}

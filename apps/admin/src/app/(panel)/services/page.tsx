import Link from "next/link";
import { redirect } from "next/navigation";
import { randomUUID } from "crypto";

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

export default async function AdminServicesPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string; q?: string; shop_id?: string; barber_id?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((params?.error ?? "").trim());
  const q = String(params?.q ?? "").trim();
  const shopFilter = String(params?.shop_id ?? "").trim();
  const barberFilter = String(params?.barber_id ?? "").trim();

  const supabase = await createSupabaseServerClient();

  const { data: shops } = await supabase
    .from("barbershops")
    .select("id, name")
    .order("created_at", { ascending: false })
    .limit(200);

  const { data: barbers } = await supabase
    .from("barbers")
    .select("id, display_name, shop_id")
    .order("created_at", { ascending: false })
    .limit(400);

  const { data: templates } = await supabase
    .from("service_templates")
    .select("id, name_en")
    .order("created_at", { ascending: false })
    .limit(200);

  let servicesQuery = supabase
    .from("services")
    .select(
      "id, shop_id, barber_id, name_en, name_ar, price_bhd, duration_minutes, image_url, category, deposit_type, deposit_value, is_popular, is_active, created_at"
    )
    .is("deleted_at", null);

  if (shopFilter) servicesQuery = servicesQuery.eq("shop_id", shopFilter);
  if (barberFilter) servicesQuery = servicesQuery.eq("barber_id", barberFilter);
  if (q) {
    const safe = q.replaceAll("%", "");
    servicesQuery = servicesQuery.or(`name_en.ilike.%${safe}%,name_ar.ilike.%${safe}%`);
  }

  const { data: rows } = await servicesQuery.order("created_at", { ascending: false }).limit(200);
  const shopNameById = new Map((shops ?? []).map((s) => [String(s.id), s.name ?? String(s.id)]));
  const barberLabelById = new Map(
    (barbers ?? []).map((b) => [
      String(b.id),
      `${b.display_name ?? b.id}${b.shop_id ? ` (${shopNameById.get(String(b.shop_id)) ?? b.shop_id})` : " (Independent)"}`
    ])
  );

  async function createService(formData: FormData) {
    "use server";

    const nameEn = String(formData.get("name_en") ?? "").trim();
    const nameAr = String(formData.get("name_ar") ?? "").trim();
    const category = String(formData.get("category") ?? "").trim();
    const shopId = String(formData.get("shop_id") ?? "").trim();
    const barberId = String(formData.get("barber_id") ?? "").trim();
    const templateId = String(formData.get("template_id") ?? "").trim();
    const priceBhd = Number(formData.get("price_bhd") ?? 0);
    const durationMin = Number(formData.get("duration_minutes") ?? 30);
    const depositType = String(formData.get("deposit_type") ?? "").trim();
    const depositValue = Number(formData.get("deposit_value") ?? 0);
    const isPopular = String(formData.get("is_popular") ?? "") === "on";
    const isActive = String(formData.get("is_active") ?? "") !== "off";
    const files = formData.getAll("images");

    const supabase = await createSupabaseServerClient();
    let effectiveShopId = shopId || null;

    if (barberId) {
      const { data: barberRow, error: barberError } = await supabase.from("barbers").select("id, shop_id").eq("id", barberId).maybeSingle();
      if (barberError) redirect(`/services?error=${encodeURIComponent(barberError.message)}`);
      const barberShopId = String((barberRow as { shop_id?: unknown } | null)?.shop_id ?? "").trim() || null;
      if (effectiveShopId && barberShopId && effectiveShopId !== barberShopId) {
        redirect(`/services?error=${encodeURIComponent("Selected barber belongs to a different shop.")}`);
      }
      effectiveShopId = effectiveShopId ?? barberShopId;
    }

    let template: {
      id: string;
      name_en: string;
      name_ar: string | null;
      description_en: string | null;
      description_ar: string | null;
      price_bhd: number;
      duration_minutes: number;
      category: string | null;
      deposit_type: string | null;
      deposit_value: number | null;
    } | null = null;
    let templateImages: Array<{ storage_path: string; public_url: string; position: number; is_primary: boolean }> = [];
    if (templateId) {
      const { data: tRow, error: tErr } = await supabase
        .from("service_templates")
        .select("id, name_en, name_ar, description_en, description_ar, price_bhd, duration_minutes, category, deposit_type, deposit_value")
        .eq("id", templateId)
        .maybeSingle();
      if (tErr) redirect(`/services?error=${encodeURIComponent(tErr.message)}`);
      template = tRow;
      const { data: tImgs } = await supabase
        .from("service_template_images")
        .select("storage_path, public_url, position, is_primary")
        .eq("template_id", templateId)
        .order("position", { ascending: true })
        .limit(50);
      templateImages = (tImgs ?? []).map((x) => ({
        storage_path: x.storage_path,
        public_url: x.public_url,
        position: x.position ?? 0,
        is_primary: Boolean(x.is_primary)
      }));
    }

    const finalNameEn = nameEn || template?.name_en || "";
    if (!finalNameEn) redirect("/services");

    const { data: inserted, error: insertError } = await supabase
      .from("services")
      .insert({
        shop_id: effectiveShopId,
        barber_id: barberId || null,
        name_en: finalNameEn,
        name_ar: nameAr || template?.name_ar || null,
        category: category || template?.category || null,
        price_bhd: Number.isFinite(priceBhd) && priceBhd > 0 ? priceBhd : template?.price_bhd ?? 0,
        duration_minutes: Number.isFinite(durationMin) && durationMin > 0 ? durationMin : template?.duration_minutes ?? 30,
        image_url: null,
        is_popular: isPopular,
        is_active: isActive,
        deposit_type:
          depositType === "fixed" || depositType === "percent" ? depositType : (template?.deposit_type ?? null),
        deposit_value: depositValue > 0 ? depositValue : (template?.deposit_value ?? null)
      })
      .select("id")
      .maybeSingle();

    if (insertError) redirect(`/services?error=${encodeURIComponent(insertError.message)}`);
    const serviceId = inserted?.id;
    if (!serviceId) redirect("/services");

    const picked = files.filter((f) => f instanceof File && f.size > 0) as File[];
    const prefix = barberId ? `barbers/${barberId}` : effectiveShopId ? `shops/${effectiveShopId}` : "admin";

    let pos = 0;
    const toUpload = picked.length ? picked.slice(0, 10) : [];
    for (const item of toUpload) {
      if (!(item.type ?? "").startsWith("image/")) {
        redirect(`/services?error=${encodeURIComponent("Only images are supported for service photos.")}`);
      }
      const ext = item.name.includes(".") ? item.name.split(".").pop() : undefined;
      const safeExt = ext ? `.${ext.toLowerCase()}` : "";
      const objectPath = `${prefix}/services/${serviceId}/${randomUUID()}${safeExt}`;
      const bytes = new Uint8Array(await item.arrayBuffer());
      const { error: uploadError } = await supabase.storage
        .from("service-images")
        .upload(objectPath, bytes, { contentType: item.type || "image/jpeg", upsert: true });
      if (uploadError) redirect(`/services?error=${encodeURIComponent(uploadError.message)}`);
      const publicUrl = supabase.storage.from("service-images").getPublicUrl(objectPath).data.publicUrl;
      const { error: imgError } = await supabase.from("service_images").insert({
        service_id: serviceId,
        storage_path: objectPath,
        public_url: publicUrl,
        position: pos,
        is_primary: pos === 0
      });
      if (imgError) redirect(`/services?error=${encodeURIComponent(imgError.message)}`);
      pos += 1;
    }

    if (!picked.length && templateImages.length) {
      let p = 0;
      for (const img of templateImages.slice(0, 10)) {
        const { error: imgError } = await supabase.from("service_images").insert({
          service_id: serviceId,
          storage_path: img.storage_path,
          public_url: img.public_url,
          position: p,
          is_primary: p === 0
        });
        if (imgError) redirect(`/services?error=${encodeURIComponent(imgError.message)}`);
        p += 1;
      }
    }

    const { data: primary } = await supabase
      .from("service_images")
      .select("public_url")
      .eq("service_id", serviceId)
      .eq("is_primary", true)
      .maybeSingle();
    if (primary?.public_url) {
      const { error: imgUrlErr } = await supabase.from("services").update({ image_url: primary.public_url }).eq("id", serviceId);
      if (imgUrlErr) redirect(`/services?error=${encodeURIComponent(imgUrlErr.message)}`);
    }

    redirect("/services");
  }

  async function toggleActive(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "").trim();
    const current = String(formData.get("current") ?? "") === "true";

    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("services").update({ is_active: !current }).eq("id", id);
    if (error) redirect(`/services?error=${encodeURIComponent(error.message)}`);
    redirect("/services");
  }

  async function togglePopular(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "").trim();
    const current = String(formData.get("current") ?? "") === "true";

    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("services").update({ is_popular: !current }).eq("id", id);
    if (error) redirect(`/services?error=${encodeURIComponent(error.message)}`);
    redirect("/services");
  }

  async function remove(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("services").update({ deleted_at: new Date().toISOString(), is_active: false }).eq("id", id);
    if (error) redirect(`/services?error=${encodeURIComponent(error.message)}`);
    redirect("/services");
  }

  return (
    <PageFrame
      title="Services"
      subtitle="Create, edit, and assign services to shops and barbers."
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/service-templates">Templates</Link>
        </Button>
      }
    >
      {params?.error ? (
        <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard>
      ) : null}

      <LuxuryCard className="mb-6 p-5">
        <form className="grid gap-3 md:grid-cols-5" method="get">
          <div className="grid gap-2 md:col-span-2">
            <Label htmlFor="q">Search</Label>
            <Input id="q" name="q" defaultValue={q} placeholder="Name (EN/AR)" />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="shop_id_filter">Shop</Label>
            <select
              id="shop_id_filter"
              name="shop_id"
              className="h-10 rounded-md border border-white/10 bg-transparent px-3 text-sm"
              defaultValue={shopFilter}
            >
              <option value="">All</option>
              {(shops ?? []).map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="barber_id_filter">Barber</Label>
            <select
              id="barber_id_filter"
              name="barber_id"
              className="h-10 rounded-md border border-white/10 bg-transparent px-3 text-sm"
              defaultValue={barberFilter}
            >
              <option value="">All</option>
              {(barbers ?? []).map((b) => (
                <option key={b.id} value={b.id}>
                  {barberLabelById.get(String(b.id)) ?? b.display_name}
                </option>
              ))}
            </select>
          </div>
          <div className="flex items-end justify-end gap-2">
            <Button type="submit" variant="secondary">
              Apply
            </Button>
            <Button asChild type="button" variant="ghost">
              <Link href="/services">Reset</Link>
            </Button>
          </div>
        </form>
      </LuxuryCard>

      <LuxuryCard className="mb-6 p-5">
        <form action={createService} className="grid gap-4 md:grid-cols-3" encType="multipart/form-data">
          <div className="grid gap-2 md:col-span-2">
            <Label htmlFor="name_en">Name (EN)</Label>
            <Input id="name_en" name="name_en" />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="name_ar">Name (AR)</Label>
            <Input id="name_ar" name="name_ar" />
          </div>
          <div className="grid gap-2 md:col-span-3">
            <Label htmlFor="template_id">Template</Label>
            <select
              id="template_id"
              name="template_id"
              className="h-10 rounded-md border border-white/10 bg-transparent px-3 text-sm"
              defaultValue=""
            >
              <option value="">None</option>
              {(templates ?? []).map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name_en}
                </option>
              ))}
            </select>
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
            <Label htmlFor="shop_id">Shop</Label>
            <select
              id="shop_id"
              name="shop_id"
              className="h-10 rounded-md border border-white/10 bg-transparent px-3 text-sm"
              defaultValue=""
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
              defaultValue=""
            >
              <option value="">None</option>
              {(barbers ?? []).map((b) => (
                <option key={b.id} value={b.id}>
                  {b.display_name}
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
            <label className="flex items-center gap-2 text-sm">
              <input type="checkbox" name="is_popular" className="h-4 w-4" />
              Popular
            </label>
            <label className="flex items-center gap-2 text-sm">
              <input type="checkbox" name="is_active" className="h-4 w-4" defaultChecked />
              Active
            </label>
            <div className="flex-1" />
            <Button type="submit" variant="secondary">
              Add service
            </Button>
          </div>
        </form>
      </LuxuryCard>

      <LuxuryCard className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[1180px] text-sm">
            <thead className="text-xs text-muted-foreground">
              <tr className="border-b border-white/10">
                <th className="px-4 py-3 text-left font-medium">Image</th>
                <th className="px-4 py-3 text-left font-medium">Service</th>
                <th className="px-4 py-3 text-left font-medium">Owner</th>
                <th className="px-4 py-3 text-left font-medium">Price</th>
                <th className="px-4 py-3 text-left font-medium">Deposit</th>
                <th className="px-4 py-3 text-left font-medium">Duration</th>
                <th className="px-4 py-3 text-left font-medium">Popular</th>
                <th className="px-4 py-3 text-left font-medium">Active</th>
                <th className="px-4 py-3 text-right font-medium">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/10">
              {rows?.length ? (
                rows.map((r) => (
                  <tr key={r.id} className="hover:bg-white/5">
                    <td className="px-4 py-3">
                      <div className="h-10 w-14 overflow-hidden rounded-md border border-white/10 bg-white/5">
                        <SafeImage
                          src={r.image_url}
                          fallbackKey="default_service_image"
                          width={56}
                          height={40}
                          className="h-full w-full object-cover"
                        />
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="font-medium">{r.name_en}</div>
                      {r.name_ar ? <div className="text-xs text-muted-foreground">{r.name_ar}</div> : null}
                      <div className="text-xs text-muted-foreground">{r.category ?? ""}</div>
                      <div className="pt-1">
                        <Button asChild variant="ghost" size="sm">
                          <Link href={`/services/${r.id}`}>Edit</Link>
                        </Button>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-xs text-muted-foreground">
                      <div>Shop: {r.shop_id ? shopNameById.get(String(r.shop_id)) ?? r.shop_id : "-"}</div>
                      <div>Barber: {r.barber_id ? barberLabelById.get(String(r.barber_id)) ?? r.barber_id : "-"}</div>
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">{Number(r.price_bhd ?? 0).toFixed(3)} BHD</td>
                    <td className="px-4 py-3 text-muted-foreground">
                      {r.deposit_type && Number(r.deposit_value ?? 0) > 0 ? (
                        <span>
                          {r.deposit_type} • {Number(r.deposit_value).toFixed(3)}
                        </span>
                      ) : (
                        "—"
                      )}
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">{r.duration_minutes} min</td>
                    <td className="px-4 py-3 text-muted-foreground">{r.is_popular ? "Yes" : "No"}</td>
                    <td className="px-4 py-3 text-muted-foreground">{r.is_active ? "Yes" : "No"}</td>
                    <td className="px-4 py-3 text-right">
                      <div className="flex justify-end gap-2">
                        <form action={togglePopular}>
                          <input type="hidden" name="id" value={r.id} />
                          <input type="hidden" name="current" value={String(Boolean(r.is_popular))} />
                          <Button type="submit" size="sm" variant="secondary">
                            {r.is_popular ? "Unpopular" : "Popular"}
                          </Button>
                        </form>
                        <form action={toggleActive}>
                          <input type="hidden" name="id" value={r.id} />
                          <input type="hidden" name="current" value={String(Boolean(r.is_active))} />
                          <Button type="submit" size="sm" variant="secondary">
                            {r.is_active ? "Disable" : "Enable"}
                          </Button>
                        </form>
                        <form action={remove}>
                          <input type="hidden" name="id" value={r.id} />
                          <Button type="submit" size="sm" variant="ghost">
                            Delete
                          </Button>
                        </form>
                      </div>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={8} className="px-4 py-10 text-center text-muted-foreground">
                    No services yet.
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

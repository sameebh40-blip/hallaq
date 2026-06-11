import { redirect } from "next/navigation";
import { randomUUID } from "crypto";

import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getMyProfile } from "@hallaq/supabase/profile";

import { MediaFileInput } from "@/components/media-file-input";
import { SafeImage } from "@/components/safe-image";
import { getMyShopContext } from "@/lib/my-shop-context";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type ServiceBarberAssignmentRow = {
  service_id: string;
  barber_id: string;
};

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
    return "Permission denied. Make sure you are signed in as the shop owner account.";
  }
  return m;
}

export default async function BusinessServicesPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string; shopId?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((params?.error ?? "").trim());
  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);
  const ctx = await getMyShopContext(supabase);

  const shopId = ctx.shop?.id ?? (profile?.role === "admin" ? (params?.shopId ?? null) : null);
  if (!shopId) return <div className="text-sm text-muted-foreground">No shop selected.</div>;

  const { data: barbers } = await supabase
    .from("barbers")
    .select("id, display_name")
    .eq("shop_id", shopId)
    .order("display_name", { ascending: true })
    .limit(200);

  const { data: rows } = await supabase
    .from("services")
    .select(
      "id, shop_id, barber_id, name_en, name_ar, description_en, description_ar, price_bhd, duration_minutes, image_url, category, is_popular, is_active, deposit_type, deposit_value, owner_type, owner_id, name, description, duration_min, price, active, created_at"
    )
    .or(`shop_id.eq.${shopId},and(owner_type.eq.shop,owner_id.eq.${shopId})`)
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(100);

  const serviceIds = (rows ?? []).map((r) => r.id).filter(Boolean);
  const { data: assignments } = serviceIds.length
    ? await supabase.from("service_barbers").select("service_id, barber_id").in("service_id", serviceIds).limit(5000)
    : { data: [] as ServiceBarberAssignmentRow[] };

  async function createService(formData: FormData) {
    "use server";

    const nameEn = String(formData.get("name_en") ?? "").trim();
    const nameAr = String(formData.get("name_ar") ?? "").trim();
    const descEn = String(formData.get("description_en") ?? "").trim();
    const descAr = String(formData.get("description_ar") ?? "").trim();
    const category = String(formData.get("category") ?? "").trim();
    const barberId = String(formData.get("barber_id") ?? "").trim();
    const depositType = String(formData.get("deposit_type") ?? "").trim();
    const depositValue = Number(formData.get("deposit_value") ?? 0);

    const priceBhd = Number(formData.get("price_bhd") ?? 0);
    const durationMin = Number(formData.get("duration_minutes") ?? 30);
    const isPopular = String(formData.get("is_popular") ?? "") === "on";
    const isActive = String(formData.get("is_active") ?? "") !== "off";
    const shopId = String(formData.get("shop_id") ?? "").trim();

    if (!nameEn || !shopId) redirect("/business/services");

    const supabase = await createAppSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const file = formData.get("image_file");
    let imageUrl: string | null = null;
    if (file instanceof File && file.size > 0) {
      if (!(file.type ?? "").startsWith("image/")) {
        redirect(`/business/services?error=${encodeURIComponent("Only images are supported for service photos.")}`);
      }
      const ext = file.name.includes(".") ? file.name.split(".").pop() : undefined;
      const safeExt = ext ? `.${ext.toLowerCase()}` : "";
      const objectPath = `shops/${shopId}/services/${randomUUID()}${safeExt}`;
      const bytes = new Uint8Array(await file.arrayBuffer());
      const { error: uploadError } = await supabase.storage
        .from("service-images")
        .upload(objectPath, bytes, { contentType: file.type || "image/jpeg", upsert: true });
      if (uploadError) redirect(`/business/services?error=${encodeURIComponent(uploadError.message)}`);
      imageUrl = supabase.storage.from("service-images").getPublicUrl(objectPath).data.publicUrl;
    }

    const { data: created, error: insertError } = await supabase
      .from("services")
      .insert({
        shop_id: shopId,
        barber_id: barberId || null,
        name_en: nameEn,
        name_ar: nameAr || null,
        description_en: descEn || null,
        description_ar: descAr || null,
        category: category || null,
        price_bhd: priceBhd,
        duration_minutes: durationMin,
        image_url: imageUrl,
        is_popular: isPopular,
        is_active: isActive,
        deposit_type: depositType === "fixed" || depositType === "percent" ? depositType : null,
        deposit_value: depositValue > 0 ? depositValue : null,
        owner_type: "shop",
        owner_id: shopId,
        name: nameEn,
        description: descEn || null,
        price: priceBhd,
        duration_min: durationMin,
        active: isActive
      })
      .select("id")
      .maybeSingle();

    if (insertError) redirect(`/business/services?error=${encodeURIComponent(insertError.message)}`);

    if (actorId && created?.id) {
      await supabase.from("audit_events").insert({
        actor_profile_id: actorId,
        action: "service_created",
        entity_type: "service",
        entity_id: created.id,
        meta: { name_en: nameEn }
      });
    }

    redirect("/business/services");
  }

  async function updateAssignments(formData: FormData) {
    "use server";

    const serviceId = String(formData.get("service_id") ?? "").trim();
    const shopId = String(formData.get("shop_id") ?? "").trim();
    if (!serviceId || !shopId) redirect("/business/services");

    const selected = formData
      .getAll("assigned_barbers")
      .map((v) => String(v))
      .filter(Boolean);

    const supabase = await createAppSupabaseServerClient();

    await supabase.from("service_barbers").delete().eq("service_id", serviceId);
    if (selected.length) {
      const rows = selected.map((barberId) => ({ service_id: serviceId, barber_id: barberId }));
      const { error } = await supabase.from("service_barbers").insert(rows);
      if (error) redirect(`/business/services?error=${encodeURIComponent(error.message)}`);
    }
    redirect("/business/services");
  }

  async function toggleActive(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const current = String(formData.get("current") ?? "") === "true";
    const shopId = String(formData.get("shop_id") ?? "").trim();
    if (!id || !shopId) redirect("/business/services");

    const supabase = await createAppSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;
    await supabase
      .from("services")
      .update({ is_active: !current, active: !current })
      .eq("id", id)
      .or(`shop_id.eq.${shopId},and(owner_type.eq.shop,owner_id.eq.${shopId})`);
    if (actorId) {
      await supabase.from("audit_events").insert({
        actor_profile_id: actorId,
        action: "service_active_toggled",
        entity_type: "service",
        entity_id: id,
        meta: { is_active: !current }
      });
    }
    redirect("/business/services");
  }

  async function togglePopular(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const current = String(formData.get("current") ?? "") === "true";
    const shopId = String(formData.get("shop_id") ?? "").trim();
    if (!id || !shopId) redirect("/business/services");

    const supabase = await createAppSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;
    const { error: upError } = await supabase
      .from("services")
      .update({ is_popular: !current })
      .eq("id", id)
      .or(`shop_id.eq.${shopId},and(owner_type.eq.shop,owner_id.eq.${shopId})`);

    if (upError) redirect(`/business/services?error=${encodeURIComponent(upError.message)}`);
    if (actorId) {
      await supabase.from("audit_events").insert({
        actor_profile_id: actorId,
        action: "service_popular_toggled",
        entity_type: "service",
        entity_id: id,
        meta: { is_popular: !current }
      });
    }
    redirect("/business/services");
  }

  async function updateService(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "").trim();
    const nameEn = String(formData.get("name_en") ?? "").trim();
    const nameAr = String(formData.get("name_ar") ?? "").trim();
    const descEn = String(formData.get("description_en") ?? "").trim();
    const descAr = String(formData.get("description_ar") ?? "").trim();
    const category = String(formData.get("category") ?? "").trim();
    const barberId = String(formData.get("barber_id") ?? "").trim();
    const priceBhd = Number(formData.get("price_bhd") ?? 0);
    const durationMin = Number(formData.get("duration_minutes") ?? 30);
    const depositType = String(formData.get("deposit_type") ?? "").trim();
    const depositValue = Number(formData.get("deposit_value") ?? 0);
    const shopId = String(formData.get("shop_id") ?? "").trim();

    if (!id || !nameEn || !shopId) redirect("/business/services");

    const supabase = await createAppSupabaseServerClient();
    const file = formData.get("image_file");
    let imageUrl: string | undefined;
    if (file instanceof File && file.size > 0) {
      if (!(file.type ?? "").startsWith("image/")) {
        redirect(`/business/services?error=${encodeURIComponent("Only images are supported for service photos.")}`);
      }
      const ext = file.name.includes(".") ? file.name.split(".").pop() : undefined;
      const safeExt = ext ? `.${ext.toLowerCase()}` : "";
      const objectPath = `shops/${shopId}/services/${id}/${randomUUID()}${safeExt}`;
      const bytes = new Uint8Array(await file.arrayBuffer());
      const { error: uploadError } = await supabase.storage
        .from("service-images")
        .upload(objectPath, bytes, { contentType: file.type || "image/jpeg", upsert: true });
      if (uploadError) redirect(`/business/services?error=${encodeURIComponent(uploadError.message)}`);
      imageUrl = supabase.storage.from("service-images").getPublicUrl(objectPath).data.publicUrl;
    }

    const payload: Record<string, unknown> = {
      barber_id: barberId || null,
      name_en: nameEn,
      name_ar: nameAr || null,
      description_en: descEn || null,
      description_ar: descAr || null,
      category: category || null,
      price_bhd: priceBhd,
      duration_minutes: durationMin,
      deposit_type: depositType === "fixed" || depositType === "percent" ? depositType : null,
      deposit_value: depositValue > 0 ? depositValue : null,
      name: nameEn,
      description: descEn || null,
      price: priceBhd,
      duration_min: durationMin
    };
    if (imageUrl) payload.image_url = imageUrl;

    const { error: upError } = await supabase
      .from("services")
      .update(payload)
      .eq("id", id)
      .or(`shop_id.eq.${shopId},and(owner_type.eq.shop,owner_id.eq.${shopId})`);
    if (upError) redirect(`/business/services?error=${encodeURIComponent(upError.message)}`);
    redirect("/business/services");
  }

  async function deleteService(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const shopId = String(formData.get("shop_id") ?? "").trim();
    if (!id || !shopId) redirect("/business/services");

    const supabase = await createAppSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;
    await supabase
      .from("services")
      .update({ deleted_at: new Date().toISOString(), is_active: false, active: false })
      .eq("id", id)
      .or(`shop_id.eq.${shopId},and(owner_type.eq.shop,owner_id.eq.${shopId})`);
    if (actorId) {
      await supabase.from("audit_events").insert({
        actor_profile_id: actorId,
        action: "service_soft_deleted",
        entity_type: "service",
        entity_id: id,
        meta: {}
      });
    }
    redirect("/business/services");
  }

  return (
    <div className="flex flex-col gap-6">
      {params?.error ? (
        <LuxuryCard className="border border-red-500/40 bg-red-500/10 p-4">
          <div className="text-sm text-red-200">{error}</div>
        </LuxuryCard>
      ) : null}
      <LuxuryCard className="p-5">
        <form action={createService} className="grid gap-4 md:grid-cols-3" encType="multipart/form-data">
          <input type="hidden" name="shop_id" value={shopId} />
          <div className="grid gap-2 md:col-span-2">
            <Label htmlFor="name_en">Service name (EN)</Label>
            <Input id="name_en" name="name_en" placeholder="Haircut..." required />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="price_bhd">Price (BHD)</Label>
            <Input id="price_bhd" name="price_bhd" type="number" step="0.001" defaultValue="0" />
          </div>
          <div className="grid gap-2 md:col-span-2">
            <Label htmlFor="name_ar">Service name (AR)</Label>
            <Input id="name_ar" name="name_ar" placeholder="قص شعر..." />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="duration_minutes">Duration (min)</Label>
            <Input id="duration_minutes" name="duration_minutes" type="number" defaultValue="30" />
          </div>
          <div className="grid gap-2 md:col-span-3">
            <Label htmlFor="description_en">Description (EN)</Label>
            <Input id="description_en" name="description_en" placeholder="Short description..." />
          </div>
          <div className="grid gap-2 md:col-span-3">
            <Label htmlFor="description_ar">Description (AR)</Label>
            <Input id="description_ar" name="description_ar" placeholder="وصف قصير..." />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="category">Category</Label>
            <Input id="category" name="category" placeholder="Haircut..." />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="barber_id">Assign to barber</Label>
            <select id="barber_id" name="barber_id" className="h-10 rounded-md border border-white/10 bg-white/5 px-3 text-sm" defaultValue="">
              <option value="">Shop service (all barbers)</option>
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
              <select name="deposit_type" className="h-10 rounded-md border border-white/10 bg-white/5 px-3 text-sm" defaultValue="">
                <option value="">No deposit</option>
                <option value="fixed">Fixed</option>
                <option value="percent">Percent</option>
              </select>
              <Input name="deposit_value" type="number" step="0.001" placeholder="Value" defaultValue="0" />
            </div>
          </div>
          <div className="grid gap-2 md:col-span-3">
            <Label>Service image</Label>
            <MediaFileInput name="image_file" accept="image/*" />
          </div>
          <div className="flex items-center gap-3 md:col-span-3">
            <label className="flex items-center gap-2 text-sm">
              <input type="checkbox" name="is_popular" className="h-4 w-4" />
              Popular
            </label>
            <label className="flex items-center gap-2 text-sm">
              <input type="checkbox" name="is_active" className="h-4 w-4" defaultChecked />
              Active
            </label>
          </div>
          <div className="flex items-end justify-end md:col-span-2">
            <Button type="submit" variant="secondary">
              Add service
            </Button>
          </div>
        </form>
      </LuxuryCard>

      <LuxuryCard className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[980px] text-sm">
            <thead className="text-xs text-muted-foreground">
              <tr className="border-b border-white/10">
                <th className="px-5 py-3 text-left font-medium">Image</th>
                <th className="px-5 py-3 text-left font-medium">Service</th>
                <th className="px-5 py-3 text-left font-medium">Assigned</th>
                <th className="px-5 py-3 text-left font-medium">Duration</th>
                <th className="px-5 py-3 text-left font-medium">Price</th>
                <th className="px-5 py-3 text-left font-medium">Popular</th>
                <th className="px-5 py-3 text-left font-medium">Active</th>
                <th className="px-5 py-3 text-right font-medium">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/10">
              {rows?.length ? (
                rows.map((r) => (
                  <tr key={r.id} className="hover:bg-white/5">
                    <td className="px-5 py-3">
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
                    <td className="px-5 py-3">
                      <div className="font-medium">{r.name_en ?? r.name}</div>
                      {r.name_ar ? <div className="text-xs text-muted-foreground">{r.name_ar}</div> : null}
                      {r.description_en || r.description ? <div className="text-xs text-muted-foreground">{r.description_en ?? r.description}</div> : null}
                    </td>
                    <td className="px-5 py-3 text-muted-foreground">
                      {r.barber_id ? (barbers ?? []).find((b) => b.id === r.barber_id)?.display_name ?? "Barber" : "All"}
                    </td>
                    <td className="px-5 py-3 text-muted-foreground">{r.duration_minutes ?? r.duration_min} min</td>
                    <td className="px-5 py-3 text-muted-foreground">{Number(r.price_bhd ?? r.price ?? 0).toFixed(3)} BHD</td>
                    <td className="px-5 py-3 text-muted-foreground">{r.is_popular ? "Yes" : "No"}</td>
                    <td className="px-5 py-3 text-muted-foreground">{r.is_active ?? r.active ? "Yes" : "No"}</td>
                    <td className="px-5 py-3 text-right">
                      <div className="flex flex-col items-end gap-2">
                        <div className="flex justify-end gap-2">
                          <form action={togglePopular}>
                            <input type="hidden" name="id" value={r.id} />
                            <input type="hidden" name="current" value={String(Boolean(r.is_popular))} />
                            <input type="hidden" name="shop_id" value={shopId} />
                            <Button type="submit" size="sm" variant="secondary">
                              {r.is_popular ? "Unpopular" : "Popular"}
                            </Button>
                          </form>
                          <form action={toggleActive}>
                            <input type="hidden" name="id" value={r.id} />
                            <input type="hidden" name="current" value={String(Boolean(r.is_active ?? r.active))} />
                            <input type="hidden" name="shop_id" value={shopId} />
                            <Button type="submit" size="sm" variant="secondary">
                              {r.is_active ?? r.active ? "Disable" : "Enable"}
                            </Button>
                          </form>
                          <form action={deleteService}>
                            <input type="hidden" name="id" value={r.id} />
                            <input type="hidden" name="shop_id" value={shopId} />
                            <Button type="submit" size="sm" variant="ghost">
                              Delete
                            </Button>
                          </form>
                        </div>
                        <form
                          action={updateService}
                          className="grid w-full max-w-[520px] gap-2 rounded-md border border-white/10 p-3"
                          encType="multipart/form-data"
                        >
                          <input type="hidden" name="id" value={r.id} />
                          <input type="hidden" name="shop_id" value={shopId} />
                          <div className="grid grid-cols-2 gap-2">
                            <Input name="name_en" placeholder="Name (EN)" defaultValue={r.name_en ?? r.name ?? ""} />
                            <Input name="name_ar" placeholder="Name (AR)" defaultValue={r.name_ar ?? ""} />
                          </div>
                          <div className="grid grid-cols-2 gap-2">
                            <Input name="price_bhd" type="number" step="0.001" defaultValue={Number(r.price_bhd ?? r.price ?? 0)} />
                            <Input name="duration_minutes" type="number" defaultValue={Number(r.duration_minutes ?? r.duration_min ?? 30)} />
                          </div>
                          <div className="grid grid-cols-2 gap-2">
                            <Input name="category" placeholder="Category" defaultValue={r.category ?? ""} />
                            <select
                              name="barber_id"
                              className="h-10 rounded-md border border-white/10 bg-white/5 px-3 text-sm"
                              defaultValue={r.barber_id ?? ""}
                            >
                              <option value="">All</option>
                              {(barbers ?? []).map((b) => (
                                <option key={b.id} value={b.id}>
                                  {b.display_name}
                                </option>
                              ))}
                            </select>
                          </div>
                          <div className="grid grid-cols-2 gap-2">
                            <select name="deposit_type" className="h-10 rounded-md border border-white/10 bg-white/5 px-3 text-sm" defaultValue={r.deposit_type ?? ""}>
                              <option value="">No deposit</option>
                              <option value="fixed">Fixed</option>
                              <option value="percent">Percent</option>
                            </select>
                            <Input name="deposit_value" type="number" step="0.001" placeholder="Deposit value" defaultValue={Number(r.deposit_value ?? 0)} />
                          </div>
                          <Input name="description_en" placeholder="Description (EN)" defaultValue={r.description_en ?? r.description ?? ""} />
                          <Input name="description_ar" placeholder="Description (AR)" defaultValue={r.description_ar ?? ""} />
                          <MediaFileInput name="image_file" accept="image/*" />
                          <div className="flex justify-end">
                            <Button type="submit" size="sm" variant="secondary">
                              Update
                            </Button>
                          </div>
                        </form>
                        {r.barber_id ? null : (
                          <form action={updateAssignments} className="grid w-full max-w-[520px] gap-2 rounded-md border border-white/10 p-3">
                            <input type="hidden" name="service_id" value={r.id} />
                            <input type="hidden" name="shop_id" value={shopId} />
                            <div className="text-xs text-muted-foreground">
                              Assign this shop service to specific barbers (leave empty to allow all barbers).
                            </div>
                            <div className="grid grid-cols-2 gap-2">
                              {(barbers ?? []).map((b) => {
                                const checked = (assignments ?? []).some((a) => a.service_id === r.id && a.barber_id === b.id);
                                return (
                                  <label key={b.id} className="flex items-center gap-2 text-sm">
                                    <input type="checkbox" name="assigned_barbers" value={b.id} defaultChecked={checked} className="h-4 w-4" />
                                    {b.display_name}
                                  </label>
                                );
                              })}
                            </div>
                            <div className="flex justify-end">
                              <Button type="submit" size="sm" variant="secondary">
                                Save assignments
                              </Button>
                            </div>
                          </form>
                        )}
                      </div>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={8} className="px-5 py-10 text-center text-muted-foreground">
                    No services yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </LuxuryCard>
    </div>
  );
}

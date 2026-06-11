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
    return "Storage bucket not found. Create the missing buckets in Supabase Storage.";
  }
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as an admin account.";
  }
  return m;
}

function parseTags(value: string) {
  return Array.from(
    new Set(
      value
        .split(",")
        .map((t) => t.trim())
        .filter(Boolean)
    )
  ).slice(0, 30);
}

export default async function ProductDetailsPage({
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

  const { data: product } = await supabase
    .from("products")
    .select("id, shop_id, name, description, sku, category_id, price, currency, stock, images, active, deleted_at, created_at, updated_at")
    .eq("id", id)
    .maybeSingle();

  if (!product) notFound();

  const { data: categories } = await supabase
    .from("product_categories")
    .select("id, name_en, name_ar")
    .order("name_en", { ascending: true })
    .limit(500);

  const { data: shops } = await supabase
    .from("barbershops")
    .select("id, name")
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(400);

  const { data: productImages } = await supabase
    .from("product_images")
    .select("id, public_url, position, is_primary")
    .eq("product_id", id)
    .order("position", { ascending: true })
    .order("created_at", { ascending: true })
    .limit(100);

  const { data: tagLinks } = await supabase
    .from("product_tag_links")
    .select("tag_id, product_tags (id, name)")
    .eq("product_id", id)
    .limit(200);

  const existingTags = (tagLinks ?? [])
    .map((l) => {
      const tag = (l as unknown as { product_tags?: { name?: string | null } | null }).product_tags;
      return tag?.name ?? undefined;
    })
    .filter(Boolean) as string[];

  const { data: options } = await supabase
    .from("product_options")
    .select("id, name_en, name_ar, position")
    .eq("product_id", id)
    .order("position", { ascending: true })
    .limit(50);

  const optionIds = (options ?? []).map((o) => o.id);
  const { data: optionValues } = optionIds.length
    ? await supabase
        .from("product_option_values")
        .select("id, option_id, value_en, value_ar, position")
        .in("option_id", optionIds)
        .order("position", { ascending: true })
        .limit(500)
    : { data: [] as Array<{ id: string; option_id: string; value_en: string; value_ar: string | null; position: number }> };

  const valuesByOption = new Map<string, Array<{ id: string; value_en: string; value_ar: string | null; position: number }>>();
  for (const v of optionValues ?? []) {
    const list = valuesByOption.get(v.option_id) ?? [];
    list.push({ id: v.id, value_en: v.value_en, value_ar: v.value_ar ?? null, position: v.position ?? 0 });
    valuesByOption.set(v.option_id, list);
  }

  const { data: variants } = await supabase
    .from("product_variants")
    .select("id, sku, signature, price, stock, active, created_at")
    .eq("product_id", id)
    .order("created_at", { ascending: true })
    .limit(400);

  const variantIds = (variants ?? []).map((v) => v.id);
  const { data: variantValues } = variantIds.length
    ? await supabase
        .from("product_variant_values")
        .select("variant_id, option_value_id")
        .in("variant_id", variantIds)
        .limit(5000)
    : { data: [] as Array<{ variant_id: string; option_value_id: string }> };

  const valueMetaById = new Map((optionValues ?? []).map((v) => [v.id, v]));
  const valueIdsByVariant = new Map<string, string[]>();
  for (const vv of variantValues ?? []) {
    const list = valueIdsByVariant.get(vv.variant_id) ?? [];
    list.push(vv.option_value_id);
    valueIdsByVariant.set(vv.variant_id, list);
  }

  function variantLabel(variantId: string) {
    const ids = valueIdsByVariant.get(variantId) ?? [];
    const byOption = new Map<string, string>();
    for (const vid of ids) {
      const meta = valueMetaById.get(vid);
      if (!meta) continue;
      byOption.set(meta.option_id, meta.value_en);
    }
    const parts = (options ?? []).map((o) => byOption.get(o.id)).filter(Boolean) as string[];
    return parts.join(" / ");
  }

  async function syncLegacyImages(supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>, productId: string) {
    const { data } = await supabase
      .from("product_images")
      .select("public_url, position, is_primary")
      .eq("product_id", productId)
      .order("position", { ascending: true })
      .order("created_at", { ascending: true })
      .limit(100);
    const list = (data ?? []).slice();
    list.sort((a, b) => (a.is_primary === b.is_primary ? (a.position ?? 0) - (b.position ?? 0) : a.is_primary ? -1 : 1));
    const urls = list.map((x) => x.public_url);
    await supabase.from("products").update({ images: urls }).eq("id", productId);
  }

  async function updateProduct(formData: FormData) {
    "use server";

    const productId = String(formData.get("id") ?? "").trim();
    const shopId = String(formData.get("shop_id") ?? "").trim();
    const name = String(formData.get("name") ?? "").trim();
    const description = String(formData.get("description") ?? "").trim();
    const sku = String(formData.get("sku") ?? "").trim();
    const categoryId = String(formData.get("category_id") ?? "").trim();
    const tags = parseTags(String(formData.get("tags") ?? "").trim());
    const price = Number(formData.get("price") ?? 0);
    const stock = Number(formData.get("stock") ?? 0);
    const active = String(formData.get("active") ?? "") !== "off";

    if (!productId || !shopId || !name) redirect(`/products/${id}`);

    const supabase = await createSupabaseServerClient();

    const payload: Record<string, unknown> = {
      shop_id: shopId,
      name,
      description: description || null,
      sku: sku || null,
      category_id: categoryId || null,
      price,
      stock,
      active
    };

    const { error: updateError } = await supabase.from("products").update(payload).eq("id", productId);
    if (updateError) redirect(`/products/${id}?error=${encodeURIComponent(updateError.message)}`);

    const { error: clearLinksError } = await supabase.from("product_tag_links").delete().eq("product_id", productId);
    if (clearLinksError) redirect(`/products/${id}?error=${encodeURIComponent(clearLinksError.message)}`);

    for (const t of tags) {
      const { data: tagRow, error: tagError } = await supabase
        .from("product_tags")
        .upsert({ name: t }, { onConflict: "name" })
        .select("id")
        .maybeSingle();
      if (tagError) redirect(`/products/${id}?error=${encodeURIComponent(tagError.message)}`);
      if (!tagRow?.id) continue;
      const { error: linkError } = await supabase.from("product_tag_links").insert({ product_id: productId, tag_id: tagRow.id });
      if (linkError) redirect(`/products/${id}?error=${encodeURIComponent(linkError.message)}`);
    }

    redirect(`/products/${id}`);
  }

  async function softDeleteProduct(formData: FormData) {
    "use server";

    const productId = String(formData.get("id") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("products").update({ deleted_at: new Date().toISOString(), active: false }).eq("id", productId);
    if (error) redirect(`/products/${id}?error=${encodeURIComponent(error.message)}`);
    redirect("/products");
  }

  async function restoreProduct(formData: FormData) {
    "use server";

    const productId = String(formData.get("id") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("products").update({ deleted_at: null }).eq("id", productId);
    if (error) redirect(`/products/${id}?error=${encodeURIComponent(error.message)}`);
    redirect(`/products/${id}`);
  }

  async function uploadImages(formData: FormData) {
    "use server";

    const productId = String(formData.get("id") ?? "").trim();
    const shopId = String(formData.get("shop_id") ?? "").trim();
    if (!productId || !shopId) redirect(`/products/${id}`);

    const supabase = await createSupabaseServerClient();
    const { data: currentImages } = await supabase
      .from("product_images")
      .select("id, position, is_primary")
      .eq("product_id", productId)
      .order("position", { ascending: true })
      .limit(200);

    const maxPos = Math.max(-1, ...((currentImages ?? []).map((x) => x.position ?? 0)));
    const hasPrimary = Boolean((currentImages ?? []).some((x) => x.is_primary));

    const files = formData.getAll("images");
    let pos = maxPos + 1;
    for (const item of files.slice(0, 10)) {
      if (!(item instanceof File) || item.size <= 0) continue;
      if (!(item.type ?? "").startsWith("image/")) redirect(`/products/${id}?error=${encodeURIComponent("Only images are supported.")}`);
      const ext = item.name.includes(".") ? item.name.split(".").pop() : undefined;
      const safeExt = ext ? `.${ext.toLowerCase()}` : "";
      const objectPath = `shops/${shopId}/products/${productId}/${randomUUID()}${safeExt}`;
      const bytes = new Uint8Array(await item.arrayBuffer());
      const { error: uploadError } = await supabase.storage
        .from("products")
        .upload(objectPath, bytes, { contentType: item.type || "image/jpeg", upsert: true });
      if (uploadError) redirect(`/products/${id}?error=${encodeURIComponent(uploadError.message)}`);
      const publicUrl = supabase.storage.from("products").getPublicUrl(objectPath).data.publicUrl;
      const { error: imgError } = await supabase.from("product_images").insert({
        product_id: productId,
        storage_path: objectPath,
        public_url: publicUrl,
        position: pos,
        is_primary: !hasPrimary && pos === maxPos + 1
      });
      if (imgError) redirect(`/products/${id}?error=${encodeURIComponent(imgError.message)}`);
      pos += 1;
    }

    await syncLegacyImages(supabase, productId);
    redirect(`/products/${id}`);
  }

  async function setPrimaryImage(formData: FormData) {
    "use server";

    const productId = String(formData.get("product_id") ?? "").trim();
    const imageId = String(formData.get("image_id") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { error: clearError } = await supabase.from("product_images").update({ is_primary: false }).eq("product_id", productId);
    if (clearError) redirect(`/products/${id}?error=${encodeURIComponent(clearError.message)}`);
    const { error: setError } = await supabase.from("product_images").update({ is_primary: true }).eq("id", imageId);
    if (setError) redirect(`/products/${id}?error=${encodeURIComponent(setError.message)}`);
    await syncLegacyImages(supabase, productId);
    redirect(`/products/${id}`);
  }

  async function moveImage(formData: FormData) {
    "use server";

    const productId = String(formData.get("product_id") ?? "").trim();
    const imageId = String(formData.get("image_id") ?? "").trim();
    const direction = String(formData.get("direction") ?? "").trim();
    const supabase = await createSupabaseServerClient();

    const { data: imgs, error } = await supabase
      .from("product_images")
      .select("id, position, is_primary")
      .eq("product_id", productId)
      .order("position", { ascending: true })
      .order("created_at", { ascending: true })
      .limit(200);
    if (error) redirect(`/products/${id}?error=${encodeURIComponent(error.message)}`);
    const list = (imgs ?? []).slice();
    list.sort((a, b) => (a.position ?? 0) - (b.position ?? 0));

    const idx = list.findIndex((x) => x.id === imageId);
    if (idx < 0) redirect(`/products/${id}`);
    const nextIdx = direction === "up" ? idx - 1 : direction === "down" ? idx + 1 : idx;
    if (nextIdx < 0 || nextIdx >= list.length) redirect(`/products/${id}`);
    const tmp = list[idx];
    list[idx] = list[nextIdx];
    list[nextIdx] = tmp;

    for (let i = 0; i < list.length; i += 1) {
      const { error: uErr } = await supabase.from("product_images").update({ position: i }).eq("id", list[i].id);
      if (uErr) redirect(`/products/${id}?error=${encodeURIComponent(uErr.message)}`);
    }
    await syncLegacyImages(supabase, productId);
    redirect(`/products/${id}`);
  }

  async function deleteImage(formData: FormData) {
    "use server";

    const productId = String(formData.get("product_id") ?? "").trim();
    const imageId = String(formData.get("image_id") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { error: delError } = await supabase.from("product_images").delete().eq("id", imageId);
    if (delError) redirect(`/products/${id}?error=${encodeURIComponent(delError.message)}`);

    const { data: imgs } = await supabase
      .from("product_images")
      .select("id, position, is_primary")
      .eq("product_id", productId)
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
        .from("product_images")
        .update({ position: i, is_primary: shouldPrimary ? true : row.is_primary })
        .eq("id", row.id);
      if (uErr) redirect(`/products/${id}?error=${encodeURIComponent(uErr.message)}`);
    }
    await syncLegacyImages(supabase, productId);
    redirect(`/products/${id}`);
  }

  async function addOption(formData: FormData) {
    "use server";

    const productId = String(formData.get("product_id") ?? "").trim();
    const nameEn = String(formData.get("name_en") ?? "").trim();
    const nameAr = String(formData.get("name_ar") ?? "").trim();
    if (!productId || !nameEn) redirect(`/products/${id}`);
    const supabase = await createSupabaseServerClient();
    const { data: existing } = await supabase.from("product_options").select("id, position").eq("product_id", productId).limit(200);
    const pos = Math.max(-1, ...((existing ?? []).map((x) => x.position ?? 0))) + 1;
    const { error } = await supabase.from("product_options").insert({
      product_id: productId,
      name_en: nameEn,
      name_ar: nameAr || null,
      position: pos
    });
    if (error) redirect(`/products/${id}?error=${encodeURIComponent(error.message)}`);
    redirect(`/products/${id}`);
  }

  async function addOptionValue(formData: FormData) {
    "use server";

    const optionId = String(formData.get("option_id") ?? "").trim();
    const valueEn = String(formData.get("value_en") ?? "").trim();
    const valueAr = String(formData.get("value_ar") ?? "").trim();
    if (!optionId || !valueEn) redirect(`/products/${id}`);
    const supabase = await createSupabaseServerClient();
    const { data: existing } = await supabase
      .from("product_option_values")
      .select("id, position")
      .eq("option_id", optionId)
      .limit(500);
    const pos = Math.max(-1, ...((existing ?? []).map((x) => x.position ?? 0))) + 1;
    const { error } = await supabase.from("product_option_values").insert({
      option_id: optionId,
      value_en: valueEn,
      value_ar: valueAr || null,
      position: pos
    });
    if (error) redirect(`/products/${id}?error=${encodeURIComponent(error.message)}`);
    redirect(`/products/${id}`);
  }

  async function deleteOptionValue(formData: FormData) {
    "use server";

    const valueId = String(formData.get("value_id") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("product_option_values").delete().eq("id", valueId);
    if (error) redirect(`/products/${id}?error=${encodeURIComponent(error.message)}`);
    redirect(`/products/${id}`);
  }

  async function deleteOption(formData: FormData) {
    "use server";

    const optionId = String(formData.get("option_id") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("product_options").delete().eq("id", optionId);
    if (error) redirect(`/products/${id}?error=${encodeURIComponent(error.message)}`);
    redirect(`/products/${id}`);
  }

  async function generateVariants(formData: FormData) {
    "use server";

    const productId = String(formData.get("product_id") ?? "").trim();
    const supabase = await createSupabaseServerClient();

    const { data: opts, error: optError } = await supabase
      .from("product_options")
      .select("id, position")
      .eq("product_id", productId)
      .order("position", { ascending: true })
      .limit(50);
    if (optError) redirect(`/products/${id}?error=${encodeURIComponent(optError.message)}`);

    const ids = (opts ?? []).map((o) => o.id);
    if (!ids.length) redirect(`/products/${id}?error=${encodeURIComponent("Add options and values first.")}`);

    const { data: vals, error: valError } = await supabase
      .from("product_option_values")
      .select("id, option_id, position")
      .in("option_id", ids)
      .order("position", { ascending: true })
      .limit(2000);
    if (valError) redirect(`/products/${id}?error=${encodeURIComponent(valError.message)}`);

    const grouped = new Map<string, string[]>();
    for (const v of vals ?? []) {
      const list = grouped.get(v.option_id) ?? [];
      list.push(v.id);
      grouped.set(v.option_id, list);
    }

    const orderedGroups = ids.map((oid) => grouped.get(oid) ?? []);
    if (orderedGroups.some((g) => g.length === 0)) redirect(`/products/${id}?error=${encodeURIComponent("Each option must have at least 1 value.")}`);

    let combos = 1;
    for (const g of orderedGroups) combos *= g.length;
    if (combos > 200) redirect(`/products/${id}?error=${encodeURIComponent("Too many combinations. Reduce values before generating variants.")}`);

    const build = (i: number, acc: string[], out: string[][]) => {
      if (i === orderedGroups.length) {
        out.push(acc.slice());
        return;
      }
      for (const v of orderedGroups[i]) {
        acc.push(v);
        build(i + 1, acc, out);
        acc.pop();
      }
    };
    const all: string[][] = [];
    build(0, [], all);

    for (const valueIds of all) {
      const signature = valueIds.slice().sort().join(".");
      const { data: vRow, error: vErr } = await supabase
        .from("product_variants")
        .upsert({ product_id: productId, signature, active: true }, { onConflict: "product_id,signature" })
        .select("id")
        .maybeSingle();
      if (vErr) redirect(`/products/${id}?error=${encodeURIComponent(vErr.message)}`);
      const variantId = vRow?.id;
      if (!variantId) continue;

      const { error: clearErr } = await supabase.from("product_variant_values").delete().eq("variant_id", variantId);
      if (clearErr) redirect(`/products/${id}?error=${encodeURIComponent(clearErr.message)}`);

      const rows = valueIds.map((vid) => ({ variant_id: variantId, option_value_id: vid }));
      const { error: vvErr } = await supabase.from("product_variant_values").insert(rows);
      if (vvErr) redirect(`/products/${id}?error=${encodeURIComponent(vvErr.message)}`);
    }

    redirect(`/products/${id}`);
  }

  async function updateVariant(formData: FormData) {
    "use server";

    const variantId = String(formData.get("variant_id") ?? "").trim();
    const sku = String(formData.get("sku") ?? "").trim();
    const priceRaw = String(formData.get("price") ?? "").trim();
    const stock = Number(formData.get("stock") ?? 0);
    const active = String(formData.get("active") ?? "") !== "off";

    const price = priceRaw ? Number(priceRaw) : null;
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase
      .from("product_variants")
      .update({ sku: sku || null, price, stock, active })
      .eq("id", variantId);
    if (error) redirect(`/products/${id}?error=${encodeURIComponent(error.message)}`);
    redirect(`/products/${id}`);
  }

  const images = (productImages ?? []).slice();
  images.sort((a, b) => (a.is_primary === b.is_primary ? (a.position ?? 0) - (b.position ?? 0) : a.is_primary ? -1 : 1));
  const tagsText = existingTags.join(", ");

  return (
    <PageFrame
      title={product.name ?? "Product"}
      subtitle="Edit product details, images, and variants."
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/products">Back</Link>
        </Button>
      }
    >
      {sp?.error ? (
        <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard>
      ) : null}

      <LuxuryCard className="mb-6 p-5">
        <form action={updateProduct} className="grid gap-4 md:grid-cols-3">
          <input type="hidden" name="id" value={product.id} />
          <div className="grid gap-2 md:col-span-2">
            <Label htmlFor="name">Name</Label>
            <Input id="name" name="name" defaultValue={product.name ?? ""} required />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="shop_id">Shop</Label>
            <select
              id="shop_id"
              name="shop_id"
              className="h-10 rounded-md border border-white/10 bg-transparent px-3 text-sm"
              defaultValue={product.shop_id}
              required
            >
              {(shops ?? []).map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="sku">SKU</Label>
            <Input id="sku" name="sku" defaultValue={product.sku ?? ""} />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="category_id">Category</Label>
            <select
              id="category_id"
              name="category_id"
              className="h-10 rounded-md border border-white/10 bg-transparent px-3 text-sm"
              defaultValue={product.category_id ?? ""}
            >
              <option value="">None</option>
              {(categories ?? []).map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name_en}
                </option>
              ))}
            </select>
          </div>
          <div className="grid gap-2 md:col-span-3">
            <Label htmlFor="description">Description</Label>
            <Input id="description" name="description" defaultValue={product.description ?? ""} />
          </div>
          <div className="grid gap-2 md:col-span-3">
            <Label htmlFor="tags">Tags (comma separated)</Label>
            <Input id="tags" name="tags" defaultValue={tagsText} />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="price">Price (BHD)</Label>
            <Input id="price" name="price" type="number" step="0.001" defaultValue={String(product.price ?? 0)} />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="stock">Stock</Label>
            <Input id="stock" name="stock" type="number" defaultValue={String(product.stock ?? 0)} />
          </div>
          <div className="grid gap-2">
            <Label>Status</Label>
            <select
              name="active"
              className="h-10 rounded-md border border-white/10 bg-transparent px-3 text-sm"
              defaultValue={product.active ? "on" : "off"}
              disabled={Boolean(product.deleted_at)}
            >
              <option value="on">Active</option>
              <option value="off">Inactive</option>
            </select>
          </div>
          <div className="flex items-center justify-end gap-2 pt-2 md:col-span-3">
            {product.deleted_at ? (
              <Button type="submit" variant="ghost" formAction={restoreProduct}>
                Restore
              </Button>
            ) : (
              <Button type="submit" variant="ghost" formAction={softDeleteProduct}>
                Delete
              </Button>
            )}
            <Button type="submit">Save</Button>
          </div>
        </form>
      </LuxuryCard>

      <LuxuryCard className="mb-6 p-5">
        <div className="mb-3 text-sm font-semibold">Images</div>
        <form action={uploadImages} className="flex flex-col gap-3" encType="multipart/form-data">
          <input type="hidden" name="id" value={product.id} />
          <input type="hidden" name="shop_id" value={product.shop_id} />
          <input name="images" type="file" accept="image/*" multiple className="text-sm" />
          <div className="flex justify-end">
            <Button type="submit" variant="secondary">
              Upload
            </Button>
          </div>
        </form>
        {images.length ? (
          <div className="mt-4 grid gap-3 md:grid-cols-2">
            {images.map((img, idx) => (
              <div key={img.id} className="flex items-center gap-3 rounded-lg border border-white/10 bg-white/5 p-3">
                <SafeImage
                  src={img.public_url}
                  fallbackKey="default_product_image"
                  width={76}
                  height={76}
                  className="h-16 w-16 rounded-md object-cover"
                />
                <div className="flex-1">
                  <div className="text-xs text-muted-foreground">{img.is_primary ? "Primary" : `#${idx + 1}`}</div>
                  <div className="mt-2 flex flex-wrap gap-2">
                    <form action={setPrimaryImage}>
                      <input type="hidden" name="product_id" value={product.id} />
                      <input type="hidden" name="image_id" value={img.id} />
                      <Button type="submit" size="sm" variant="ghost" disabled={img.is_primary}>
                        Set primary
                      </Button>
                    </form>
                    <form action={moveImage}>
                      <input type="hidden" name="product_id" value={product.id} />
                      <input type="hidden" name="image_id" value={img.id} />
                      <input type="hidden" name="direction" value="up" />
                      <Button type="submit" size="sm" variant="ghost" disabled={idx === 0}>
                        Up
                      </Button>
                    </form>
                    <form action={moveImage}>
                      <input type="hidden" name="product_id" value={product.id} />
                      <input type="hidden" name="image_id" value={img.id} />
                      <input type="hidden" name="direction" value="down" />
                      <Button type="submit" size="sm" variant="ghost" disabled={idx === images.length - 1}>
                        Down
                      </Button>
                    </form>
                    <form action={deleteImage}>
                      <input type="hidden" name="product_id" value={product.id} />
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

      <LuxuryCard className="mb-6 p-5">
        <div className="mb-3 text-sm font-semibold">Options</div>
        <form action={addOption} className="grid gap-3 md:grid-cols-3">
          <input type="hidden" name="product_id" value={product.id} />
          <div className="grid gap-2">
            <Label htmlFor="opt_name_en">Option name (EN)</Label>
            <Input id="opt_name_en" name="name_en" placeholder="Size" required />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="opt_name_ar">Option name (AR)</Label>
            <Input id="opt_name_ar" name="name_ar" placeholder="المقاس" />
          </div>
          <div className="flex items-end justify-end">
            <Button type="submit" variant="secondary">
              Add option
            </Button>
          </div>
        </form>

        {options?.length ? (
          <div className="mt-4 grid gap-4">
            {options.map((o) => (
              <div key={o.id} className="rounded-lg border border-white/10 bg-white/5 p-4">
                <div className="flex items-center gap-3">
                  <div className="flex-1 text-sm font-medium">{o.name_en}</div>
                  <form action={deleteOption}>
                    <input type="hidden" name="option_id" value={o.id} />
                    <Button type="submit" size="sm" variant="ghost">
                      Remove option
                    </Button>
                  </form>
                </div>

                <div className="mt-3 grid gap-2">
                  {(valuesByOption.get(o.id) ?? []).map((v) => (
                    <div key={v.id} className="flex items-center justify-between rounded-md border border-white/10 px-3 py-2 text-sm">
                      <div>{v.value_en}</div>
                      <form action={deleteOptionValue}>
                        <input type="hidden" name="value_id" value={v.id} />
                        <Button type="submit" size="sm" variant="ghost">
                          Remove
                        </Button>
                      </form>
                    </div>
                  ))}
                </div>

                <form action={addOptionValue} className="mt-3 grid gap-3 md:grid-cols-3">
                  <input type="hidden" name="option_id" value={o.id} />
                  <div className="grid gap-2 md:col-span-2">
                    <Label>Value (EN)</Label>
                    <Input name="value_en" placeholder="Small" required />
                  </div>
                  <div className="flex items-end justify-end">
                    <Button type="submit" size="sm" variant="secondary">
                      Add value
                    </Button>
                  </div>
                </form>
              </div>
            ))}
          </div>
        ) : (
          <div className="mt-3 text-xs text-muted-foreground">No options yet.</div>
        )}
      </LuxuryCard>

      <LuxuryCard className="p-5">
        <div className="flex items-center gap-3">
          <div className="flex-1 text-sm font-semibold">Variants</div>
          <form action={generateVariants}>
            <input type="hidden" name="product_id" value={product.id} />
            <Button type="submit" variant="secondary" size="sm">
              Generate variants
            </Button>
          </form>
        </div>

        {variants?.length ? (
          <div className="mt-4 overflow-x-auto">
            <table className="w-full min-w-[980px] text-sm">
              <thead className="text-xs text-muted-foreground">
                <tr className="border-b border-white/10">
                  <th className="px-4 py-3 text-left font-medium">Variant</th>
                  <th className="px-4 py-3 text-left font-medium">SKU</th>
                  <th className="px-4 py-3 text-left font-medium">Price override</th>
                  <th className="px-4 py-3 text-left font-medium">Stock</th>
                  <th className="px-4 py-3 text-left font-medium">Active</th>
                  <th className="px-4 py-3 text-right font-medium">Save</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/10">
                {variants.map((v) => {
                  const label = variantLabel(v.id) || v.signature || v.id.slice(0, 8);
                  const formId = `variant-${v.id}`;
                  return (
                    <tr key={v.id}>
                      <td className="px-4 py-3">{label}</td>
                      <td className="px-4 py-3">
                        <Input form={formId} name="sku" defaultValue={v.sku ?? ""} className="h-9 w-44" />
                      </td>
                      <td className="px-4 py-3">
                        <Input
                          form={formId}
                          name="price"
                          defaultValue={v.price == null ? "" : String(v.price)}
                          type="number"
                          step="0.001"
                          className="h-9 w-32"
                        />
                      </td>
                      <td className="px-4 py-3">
                        <Input form={formId} name="stock" defaultValue={String(v.stock ?? 0)} type="number" className="h-9 w-28" />
                      </td>
                      <td className="px-4 py-3">
                        <select
                          form={formId}
                          name="active"
                          defaultValue={v.active ? "on" : "off"}
                          className="h-9 w-28 rounded-md border border-white/10 bg-transparent px-2 text-xs"
                        >
                          <option value="on">On</option>
                          <option value="off">Off</option>
                        </select>
                      </td>
                      <td className="px-4 py-3 text-right">
                        <form id={formId} action={updateVariant} className="flex justify-end">
                          <input type="hidden" name="variant_id" value={v.id} />
                          <Button type="submit" size="sm" variant="secondary" className="h-9">
                            Save
                          </Button>
                        </form>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="mt-3 text-xs text-muted-foreground">No variants yet. Add options and values then generate.</div>
        )}
      </LuxuryCard>
    </PageFrame>
  );
}

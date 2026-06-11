import Link from "next/link";
import { randomUUID } from "crypto";
import { redirect } from "next/navigation";

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
  ).slice(0, 20);
}

export default async function AdminProductsPage({ searchParams }: { searchParams?: Promise<{ error?: string }> }) {
  const params = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((params?.error ?? "").trim());

  const supabase = await createSupabaseServerClient();

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

  const shopNameById = new Map((shops ?? []).map((s) => [s.id, s.name ?? ""]));

  const { data: rows } = await supabase
    .from("products")
    .select("id, shop_id, name, description, sku, category_id, price, currency, stock, images, active, deleted_at, created_at, updated_at")
    .order("created_at", { ascending: false })
    .limit(200);

  const productIds = (rows ?? []).map((r) => r.id);
  const { data: productImages } = productIds.length
    ? await supabase
        .from("product_images")
        .select("product_id, public_url, position, is_primary")
        .in("product_id", productIds)
        .order("position", { ascending: true })
        .order("created_at", { ascending: true })
        .limit(2000)
    : { data: [] as Array<{ product_id: string; public_url: string; position: number; is_primary: boolean }> };

  const imagesByProductId = new Map<string, Array<{ public_url: string; position: number; is_primary: boolean }>>();
  for (const img of productImages ?? []) {
    const list = imagesByProductId.get(img.product_id) ?? [];
    list.push({ public_url: img.public_url, position: img.position ?? 0, is_primary: Boolean(img.is_primary) });
    imagesByProductId.set(img.product_id, list);
  }

  async function createProduct(formData: FormData) {
    "use server";

    const shopId = String(formData.get("shop_id") ?? "").trim();
    const name = String(formData.get("name") ?? "").trim();
    const description = String(formData.get("description") ?? "").trim();
    const sku = String(formData.get("sku") ?? "").trim();
    const categoryId = String(formData.get("category_id") ?? "").trim();
    const tags = parseTags(String(formData.get("tags") ?? "").trim());
    const price = Number(formData.get("price") ?? 0);
    const stock = Number(formData.get("stock") ?? 0);
    const active = String(formData.get("active") ?? "") !== "off";

    if (!shopId || !name) redirect("/products");

    const supabase = await createSupabaseServerClient();

    const { data: inserted, error: insertError } = await supabase
      .from("products")
      .insert({
      shop_id: shopId,
      name,
      description: description || null,
      price,
      stock,
      active,
      sku: sku || null,
      category_id: categoryId || null
      })
      .select("id")
      .maybeSingle();

    if (insertError) redirect(`/products?error=${encodeURIComponent(insertError.message)}`);
    if (!inserted?.id) redirect("/products");

    const productId = inserted.id;

    const images: string[] = [];
    const files = formData.getAll("images");
    let pos = 0;
    for (const item of files.slice(0, 10)) {
      if (!(item instanceof File) || item.size <= 0) continue;
      if (!(item.type ?? "").startsWith("image/")) redirect(`/products?error=${encodeURIComponent("Only images are supported.")}`);

      const ext = item.name.includes(".") ? item.name.split(".").pop() : undefined;
      const safeExt = ext ? `.${ext.toLowerCase()}` : "";
      const objectPath = `shops/${shopId}/products/${productId}/${randomUUID()}${safeExt}`;
      const bytes = new Uint8Array(await item.arrayBuffer());
      const { error: uploadError } = await supabase.storage
        .from("products")
        .upload(objectPath, bytes, { contentType: item.type || "image/jpeg", upsert: true });
      if (uploadError) redirect(`/products?error=${encodeURIComponent(uploadError.message)}`);
      const publicUrl = supabase.storage.from("products").getPublicUrl(objectPath).data.publicUrl;
      images.push(publicUrl);
      const { error: imgError } = await supabase.from("product_images").insert({
        product_id: productId,
        storage_path: objectPath,
        public_url: publicUrl,
        position: pos,
        is_primary: pos === 0
      });
      if (imgError) redirect(`/products?error=${encodeURIComponent(imgError.message)}`);
      pos += 1;
    }

    if (images.length) {
      const { error: legacyImagesError } = await supabase.from("products").update({ images }).eq("id", productId);
      if (legacyImagesError) redirect(`/products?error=${encodeURIComponent(legacyImagesError.message)}`);
    }

    for (const t of tags) {
      const { data: tagRow, error: tagError } = await supabase
        .from("product_tags")
        .upsert({ name: t }, { onConflict: "name" })
        .select("id")
        .maybeSingle();
      if (tagError) redirect(`/products?error=${encodeURIComponent(tagError.message)}`);
      if (!tagRow?.id) continue;
      const { error: linkError } = await supabase.from("product_tag_links").upsert(
        { product_id: productId, tag_id: tagRow.id },
        { onConflict: "product_id,tag_id" }
      );
      if (linkError) redirect(`/products?error=${encodeURIComponent(linkError.message)}`);
    }

    redirect(`/products/${productId}`);
  }

  async function toggleActive(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "").trim();
    const current = String(formData.get("current") ?? "") === "true";
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("products").update({ active: !current }).eq("id", id);
    if (error) redirect(`/products?error=${encodeURIComponent(error.message)}`);
    redirect("/products");
  }

  async function softDeleteProduct(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("products").update({ deleted_at: new Date().toISOString(), active: false }).eq("id", id);
    if (error) redirect(`/products?error=${encodeURIComponent(error.message)}`);
    redirect("/products");
  }

  async function restoreProduct(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("products").update({ deleted_at: null }).eq("id", id);
    if (error) redirect(`/products?error=${encodeURIComponent(error.message)}`);
    redirect("/products");
  }

  return (
    <PageFrame
      title="Products"
      subtitle="Create products and manage product catalog across all shops."
      actions={
        <div className="flex items-center gap-2">
          <Button asChild variant="ghost" size="sm">
            <Link href="/product-taxonomy">Categories & Tags</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/orders">Orders</Link>
          </Button>
        </div>
      }
    >
      {params?.error ? (
        <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard>
      ) : null}

      <LuxuryCard className="mb-6 p-5">
        <form action={createProduct} className="grid gap-4 md:grid-cols-3">
          <div className="grid gap-2 md:col-span-2">
            <Label htmlFor="name">Name</Label>
            <Input id="name" name="name" required />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="shop_id">Shop</Label>
            <select
              id="shop_id"
              name="shop_id"
              className="h-10 rounded-md border border-white/10 bg-transparent px-3 text-sm"
              defaultValue=""
              required
            >
              <option value="" disabled>
                Select shop
              </option>
              {(shops ?? []).map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="sku">SKU</Label>
            <Input id="sku" name="sku" />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="category_id">Category</Label>
            <select
              id="category_id"
              name="category_id"
              className="h-10 rounded-md border border-white/10 bg-transparent px-3 text-sm"
              defaultValue=""
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
            <Input id="description" name="description" />
          </div>
          <div className="grid gap-2 md:col-span-3">
            <Label htmlFor="tags">Tags (comma separated)</Label>
            <Input id="tags" name="tags" placeholder="e.g. shampoo, beard, premium" />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="price">Price (BHD)</Label>
            <Input id="price" name="price" type="number" step="0.001" defaultValue="0" />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="stock">Stock</Label>
            <Input id="stock" name="stock" type="number" defaultValue="0" />
          </div>
          <div className="grid gap-2">
            <Label>Active</Label>
            <select name="active" className="h-10 rounded-md border border-white/10 bg-transparent px-3 text-sm">
              <option value="on">Active</option>
              <option value="off">Inactive</option>
            </select>
          </div>
          <div className="grid gap-2 md:col-span-3">
            <Label>Images</Label>
            <input name="images" type="file" accept="image/*" multiple className="text-sm" />
          </div>
          <div className="flex items-center gap-4 md:col-span-3">
            <div className="flex-1" />
            <Button type="submit" variant="secondary">
              Add product
            </Button>
          </div>
        </form>
      </LuxuryCard>

      <LuxuryCard className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[1280px] text-sm">
            <thead className="text-xs text-muted-foreground">
              <tr className="border-b border-white/10">
                <th className="px-4 py-3 text-left font-medium">Image</th>
                <th className="px-4 py-3 text-left font-medium">Product</th>
                <th className="px-4 py-3 text-left font-medium">Shop</th>
                <th className="px-4 py-3 text-left font-medium">SKU</th>
                <th className="px-4 py-3 text-left font-medium">Price</th>
                <th className="px-4 py-3 text-left font-medium">Stock</th>
                <th className="px-4 py-3 text-left font-medium">Status</th>
                <th className="px-4 py-3 text-right font-medium">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/10">
              {rows?.length ? (
                rows.map((r) => {
                  const imgs = (imagesByProductId.get(r.id) ?? []).slice();
                  imgs.sort((a, b) => (a.is_primary === b.is_primary ? (a.position ?? 0) - (b.position ?? 0) : a.is_primary ? -1 : 1));
                  const img = imgs[0]?.public_url ?? (Array.isArray(r.images) ? r.images[0] : null);
                  return (
                    <tr key={r.id} className="align-top">
                      <td className="px-4 py-3">
                        <SafeImage
                          src={img}
                          fallbackKey="default_product_image"
                          alt={r.name ?? "Product"}
                          width={52}
                          height={52}
                          className="h-12 w-12 rounded-md object-cover"
                        />
                      </td>
                      <td className="px-4 py-3">
                        <div className="font-medium">{r.name}</div>
                        <div className="text-xs text-muted-foreground">{r.description ?? ""}</div>
                        <div className="pt-1">
                          <Button asChild variant="ghost" size="sm">
                            <Link href={`/products/${r.id}`}>Edit</Link>
                          </Button>
                        </div>
                      </td>
                      <td className="px-4 py-3">{shopNameById.get(r.shop_id) ?? r.shop_id}</td>
                      <td className="px-4 py-3">{r.sku ?? "—"}</td>
                      <td className="px-4 py-3">
                        {Number(r.price ?? 0).toFixed(3)} {r.currency ?? "BHD"}
                      </td>
                      <td className="px-4 py-3">{r.stock ?? 0}</td>
                      <td className="px-4 py-3">
                        {r.deleted_at ? "Deleted" : r.active ? "Active" : "Inactive"}
                      </td>
                      <td className="px-4 py-3 text-right">
                        <div className="flex items-center justify-end gap-2">
                          <form action={toggleActive}>
                            <input type="hidden" name="id" value={r.id} />
                            <input type="hidden" name="current" value={String(Boolean(r.active))} />
                            <Button type="submit" variant="ghost" size="sm">
                              {r.active ? "Disable" : "Enable"}
                            </Button>
                          </form>
                          {r.deleted_at ? (
                            <form action={restoreProduct}>
                              <input type="hidden" name="id" value={r.id} />
                              <Button type="submit" variant="ghost" size="sm">
                                Restore
                              </Button>
                            </form>
                          ) : (
                            <form action={softDeleteProduct}>
                            <input type="hidden" name="id" value={r.id} />
                            <Button type="submit" variant="ghost" size="sm">
                              Delete
                            </Button>
                          </form>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })
              ) : (
                <tr>
                  <td className="px-4 py-6 text-muted-foreground" colSpan={8}>
                    No products yet.
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

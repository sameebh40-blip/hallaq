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

type ProductImagesRow = { images: string[] | null };

type OrderRow = {
  id: string;
  status: string;
  total_amount: number | null;
  currency: string | null;
  payment_method: string | null;
  payment_status: string | null;
  created_at: string;
  profiles: { full_name: string | null; phone: string | null; email: string | null } | null;
};

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong.";
  const l = m.toLowerCase();
  if (l.includes("bucket not found")) return "Storage bucket not found. Create missing buckets in Supabase Storage.";
  if (l.includes("permission denied") || l.includes("row-level security")) return "Permission denied. Make sure you are signed in as the shop owner account.";
  return m;
}

async function uploadProductImages(
  supabase: Awaited<ReturnType<typeof createAppSupabaseServerClient>>,
  shopId: string,
  files: Array<File | null>
) {
  const urls: string[] = [];
  for (const f of files) {
    if (!f || f.size <= 0) continue;
    if (!(f.type ?? "").startsWith("image/")) continue;
    const ext = f.name.includes(".") ? f.name.split(".").pop() : undefined;
    const safeExt = ext ? `.${ext.toLowerCase()}` : "";
    const objectPath = `shops/${shopId}/products/${randomUUID()}${safeExt}`;
    const bytes = new Uint8Array(await f.arrayBuffer());
    const { error } = await supabase.storage.from("product-images").upload(objectPath, bytes, { contentType: f.type || "image/jpeg", upsert: true });
    if (error) throw error;
    urls.push(supabase.storage.from("product-images").getPublicUrl(objectPath).data.publicUrl);
  }
  return urls;
}

export default async function BusinessProductsPage({
  searchParams
}: {
  searchParams?: Promise<{ shopId?: string; tab?: string; error?: string }>;
}) {
  const sp = searchParams ? await searchParams : undefined;
  const tab = (sp?.tab ?? "").trim() || "products";
  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);
  const ctx = await getMyShopContext(supabase);
  const shopId = ctx.shop?.id ?? (profile?.role === "admin" ? (sp?.shopId ?? null) : null);
  if (!shopId) return <div className="text-sm text-muted-foreground">No shop selected.</div>;

  const error = sp?.error ? userFacingDbError(sp.error) : null;

  const { data: products } = await supabase
    .from("products")
    .select("id, name, description, price, currency, stock, images, active, created_at")
    .eq("shop_id", shopId)
    .order("created_at", { ascending: false })
    .limit(300);

  const { data: ordersRaw } = await supabase
    .from("orders")
    .select("id, customer_profile_id, status, total_amount, currency, payment_method, payment_status, delivery_address, customer_note, created_at, profiles(full_name, phone, email)")
    .eq("shop_id", shopId)
    .order("created_at", { ascending: false })
    .limit(200);

  const orders = (ordersRaw ?? []) as unknown as OrderRow[];
  const orderIds = orders.map((o) => o.id);
  const { data: orderItems } = orderIds.length
    ? await supabase.from("order_items").select("order_id, quantity").in("order_id", orderIds).limit(5000)
    : { data: [] as Array<{ order_id: string; quantity: number }> };

  const itemCountByOrder = new Map<string, number>();
  for (const i of orderItems ?? []) itemCountByOrder.set(i.order_id, (itemCountByOrder.get(i.order_id) ?? 0) + Number(i.quantity ?? 0));

  async function createProduct(formData: FormData) {
    "use server";
    const shopId = String(formData.get("shop_id") ?? "").trim();
    const name = String(formData.get("name") ?? "").trim();
    const description = String(formData.get("description") ?? "").trim();
    const price = Number(formData.get("price") ?? 0);
    const stock = Number(formData.get("stock") ?? 0);
    const active = String(formData.get("active") ?? "") !== "off";
    if (!shopId || !name) redirect("/business/products");

    const f1 = formData.get("image_1");
    const f2 = formData.get("image_2");
    const f3 = formData.get("image_3");
    const f4 = formData.get("image_4");

    const supabase = await createAppSupabaseServerClient();
    let images: string[] = [];
    try {
      images = await uploadProductImages(supabase, shopId, [
        f1 instanceof File ? f1 : null,
        f2 instanceof File ? f2 : null,
        f3 instanceof File ? f3 : null,
        f4 instanceof File ? f4 : null
      ]);
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Upload failed.";
      redirect(`/business/products?error=${encodeURIComponent(msg)}`);
    }

    const { error } = await supabase.from("products").insert({
      shop_id: shopId,
      name,
      description: description || null,
      price,
      currency: "BHD",
      stock: Number.isFinite(stock) ? stock : 0,
      images,
      active
    });
    if (error) redirect(`/business/products?error=${encodeURIComponent(error.message)}`);
    redirect("/business/products");
  }

  async function updateProduct(formData: FormData) {
    "use server";
    const id = String(formData.get("id") ?? "").trim();
    const shopId = String(formData.get("shop_id") ?? "").trim();
    const name = String(formData.get("name") ?? "").trim();
    const description = String(formData.get("description") ?? "").trim();
    const price = Number(formData.get("price") ?? 0);
    const stock = Number(formData.get("stock") ?? 0);
    const active = String(formData.get("active") ?? "") !== "off";
    const replaceImages = String(formData.get("replace_images") ?? "") === "on";
    if (!id || !shopId || !name) redirect("/business/products");

    const f1 = formData.get("image_1");
    const f2 = formData.get("image_2");
    const f3 = formData.get("image_3");
    const f4 = formData.get("image_4");

    const supabase = await createAppSupabaseServerClient();
    let newImages: string[] = [];
    const files = [f1 instanceof File ? f1 : null, f2 instanceof File ? f2 : null, f3 instanceof File ? f3 : null, f4 instanceof File ? f4 : null];
    const hasAny = files.some((f) => f && f.size > 0);
    if (hasAny) {
      try {
        newImages = await uploadProductImages(supabase, shopId, files);
      } catch (e) {
        const msg = e instanceof Error ? e.message : "Upload failed.";
        redirect(`/business/products?error=${encodeURIComponent(msg)}`);
      }
    }

    const payload: Record<string, unknown> = {
      name,
      description: description || null,
      price,
      stock: Number.isFinite(stock) ? stock : 0,
      active
    };
    if (hasAny) {
      if (replaceImages) payload.images = newImages;
      else {
        const { data: current } = await supabase.from("products").select("images").eq("id", id).maybeSingle();
        const existing = ((current as ProductImagesRow | null)?.images ?? []) as string[];
        payload.images = [...existing, ...newImages].slice(0, 12);
      }
    }

    const { error } = await supabase.from("products").update(payload).eq("id", id).eq("shop_id", shopId);
    if (error) redirect(`/business/products?error=${encodeURIComponent(error.message)}`);
    redirect("/business/products");
  }

  async function deleteProduct(formData: FormData) {
    "use server";
    const id = String(formData.get("id") ?? "").trim();
    const shopId = String(formData.get("shop_id") ?? "").trim();
    if (!id || !shopId) redirect("/business/products");
    const supabase = await createAppSupabaseServerClient();
    const { error } = await supabase.from("products").update({ active: false }).eq("id", id).eq("shop_id", shopId);
    if (error) redirect(`/business/products?error=${encodeURIComponent(error.message)}`);
    redirect("/business/products");
  }

  async function updateOrderStatus(formData: FormData) {
    "use server";
    const id = String(formData.get("id") ?? "").trim();
    const shopId = String(formData.get("shop_id") ?? "").trim();
    const status = String(formData.get("status") ?? "").trim();
    if (!id || !shopId) redirect("/business/products?tab=orders");
    const allowed = ["pending", "accepted", "rejected", "shipped", "delivered", "cancelled"];
    if (!allowed.includes(status)) redirect("/business/products?tab=orders");
    const supabase = await createAppSupabaseServerClient();
    const { error } = await supabase.from("orders").update({ status }).eq("id", id).eq("shop_id", shopId);
    if (error) redirect(`/business/products?tab=orders&error=${encodeURIComponent(error.message)}`);
    redirect("/business/products?tab=orders");
  }

  return (
    <div className="grid gap-4">
      {error ? <LuxuryCard className="border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard> : null}

      <LuxuryCard className="p-4">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div className="grid gap-1">
            <div className="text-base font-semibold">Products</div>
            <div className="text-sm text-muted-foreground">Inventory, pricing, orders, and low stock visibility.</div>
          </div>
          <form method="get" className="flex items-center gap-2">
            <input type="hidden" name="tab" value={tab} />
            <select
              name="tab"
              defaultValue={tab}
              className="h-9 rounded-md border border-white/10 bg-white/5 px-3 text-sm"
              onChange={(e) => (e.currentTarget.form ? e.currentTarget.form.submit() : undefined)}
            >
              <option value="products">Products</option>
              <option value="orders">Orders</option>
            </select>
          </form>
        </div>
      </LuxuryCard>

      {tab === "orders" ? (
        <LuxuryCard className="overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[1100px] text-sm">
              <thead className="text-xs text-muted-foreground">
                <tr className="border-b border-white/10">
                  <th className="px-5 py-3 text-left font-medium">Order</th>
                  <th className="px-5 py-3 text-left font-medium">Customer</th>
                  <th className="px-5 py-3 text-left font-medium">Payment</th>
                  <th className="px-5 py-3 text-left font-medium">Items</th>
                  <th className="px-5 py-3 text-left font-medium">Total</th>
                  <th className="px-5 py-3 text-right font-medium">Update</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/10">
                {orders?.length ? (
                  orders.map((o) => (
                    <tr key={o.id} className="hover:bg-white/5">
                      <td className="px-5 py-3">
                        <div className="font-medium">{o.id}</div>
                        <div className="text-xs text-muted-foreground">{new Date(o.created_at).toLocaleString()}</div>
                        <div className="text-xs text-muted-foreground">status: {o.status}</div>
                      </td>
                      <td className="px-5 py-3 text-muted-foreground">
                        <div className="font-medium text-foreground">{o.profiles?.full_name ?? "Customer"}</div>
                        <div className="text-xs text-muted-foreground">{o.profiles?.phone ?? o.profiles?.email ?? ""}</div>
                      </td>
                      <td className="px-5 py-3 text-muted-foreground">
                        {o.payment_method} • {o.payment_status}
                      </td>
                      <td className="px-5 py-3 text-muted-foreground">{itemCountByOrder.get(o.id) ?? 0}</td>
                      <td className="px-5 py-3 text-muted-foreground">
                        {Number(o.total_amount ?? 0).toFixed(3)} {o.currency ?? "BHD"}
                      </td>
                      <td className="px-5 py-3 text-right">
                        <form action={updateOrderStatus} className="flex justify-end gap-2">
                          <input type="hidden" name="id" value={o.id} />
                          <input type="hidden" name="shop_id" value={shopId} />
                          <select name="status" defaultValue={o.status} className="h-9 rounded-md border border-white/10 bg-white/5 px-2 text-xs text-muted-foreground">
                            <option value="pending">pending</option>
                            <option value="accepted">accepted</option>
                            <option value="rejected">rejected</option>
                            <option value="shipped">shipped</option>
                            <option value="delivered">delivered</option>
                            <option value="cancelled">cancelled</option>
                          </select>
                          <Button type="submit" size="sm" variant="secondary">
                            Save
                          </Button>
                        </form>
                      </td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan={6} className="px-5 py-10 text-center text-muted-foreground">
                      No orders yet.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </LuxuryCard>
      ) : (
        <>
          <LuxuryCard className="p-5">
            <div className="text-base font-semibold">Add product</div>
            <form action={createProduct} className="mt-4 grid gap-4 md:grid-cols-2" encType="multipart/form-data">
              <input type="hidden" name="shop_id" value={shopId} />
              <div className="grid gap-2 md:col-span-2">
                <Label htmlFor="name">Name</Label>
                <Input id="name" name="name" required placeholder="Shampoo / Pomade / ..." />
              </div>
              <div className="grid gap-2 md:col-span-2">
                <Label htmlFor="description">Description</Label>
                <Input id="description" name="description" placeholder="Details…" />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="price">Price (BHD)</Label>
                <Input id="price" name="price" type="number" step="0.001" defaultValue="0" />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="stock">Stock</Label>
                <Input id="stock" name="stock" type="number" step="1" defaultValue="0" />
              </div>
              <div className="grid gap-2 md:col-span-2">
                <Label>Images (up to 4)</Label>
                <div className="grid gap-3 md:grid-cols-2">
                  <MediaFileInput name="image_1" accept="image/*" />
                  <MediaFileInput name="image_2" accept="image/*" />
                  <MediaFileInput name="image_3" accept="image/*" />
                  <MediaFileInput name="image_4" accept="image/*" />
                </div>
              </div>
              <div className="grid gap-2">
                <Label>Status</Label>
                <select name="active" defaultValue="on" className="h-10 rounded-md border border-white/10 bg-white/5 px-3 text-sm">
                  <option value="on">Active</option>
                  <option value="off">Inactive</option>
                </select>
              </div>
              <div className="flex items-end justify-end md:col-span-2">
                <Button type="submit" variant="secondary">
                  Create product
                </Button>
              </div>
            </form>
          </LuxuryCard>

          <LuxuryCard className="overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full min-w-[1100px] text-sm">
                <thead className="text-xs text-muted-foreground">
                  <tr className="border-b border-white/10">
                    <th className="px-5 py-3 text-left font-medium">Product</th>
                    <th className="px-5 py-3 text-left font-medium">Price</th>
                    <th className="px-5 py-3 text-left font-medium">Stock</th>
                    <th className="px-5 py-3 text-left font-medium">Status</th>
                    <th className="px-5 py-3 text-right font-medium">Edit</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-white/10">
                  {products?.length ? (
                    products.map((p) => {
                      const primary = (p.images ?? [])[0] ?? null;
                      const lowStock = Number(p.stock ?? 0) <= 3;
                      return (
                        <tr key={p.id} className="hover:bg-white/5">
                          <td className="px-5 py-3">
                            <div className="flex items-center gap-3">
                              <div className="h-10 w-10 overflow-hidden rounded-md border border-white/10 bg-white/5">
                                <SafeImage src={primary} fallbackKey="default_product_image" width={40} height={40} className="h-full w-full object-cover" />
                              </div>
                              <div>
                                <div className="font-medium">{p.name}</div>
                                <div className="text-xs text-muted-foreground">{p.description ?? ""}</div>
                              </div>
                            </div>
                          </td>
                          <td className="px-5 py-3 text-muted-foreground">
                            {Number(p.price ?? 0).toFixed(3)} {p.currency ?? "BHD"}
                          </td>
                          <td className="px-5 py-3 text-muted-foreground">
                            <span className={lowStock ? "text-amber-200" : ""}>{p.stock ?? 0}</span>
                            {lowStock ? <span className="ml-2 text-xs text-amber-200">Low</span> : null}
                          </td>
                          <td className="px-5 py-3 text-muted-foreground">{p.active ? "Active" : "Inactive"}</td>
                          <td className="px-5 py-3 text-right">
                            <details className="group">
                              <summary className="cursor-pointer list-none rounded-md border border-white/10 bg-white/5 px-3 py-2 text-xs text-muted-foreground hover:bg-white/10">
                                Edit
                              </summary>
                              <div className="mt-2 w-[700px] max-w-[92vw] rounded-md border border-white/10 bg-background/80 p-4 backdrop-blur">
                                <form action={updateProduct} className="grid gap-3" encType="multipart/form-data">
                                  <input type="hidden" name="id" value={p.id} />
                                  <input type="hidden" name="shop_id" value={shopId} />
                                  <div className="grid gap-2">
                                    <Label>Name</Label>
                                    <Input name="name" defaultValue={p.name ?? ""} required />
                                  </div>
                                  <div className="grid gap-2">
                                    <Label>Description</Label>
                                    <Input name="description" defaultValue={p.description ?? ""} />
                                  </div>
                                  <div className="grid grid-cols-2 gap-2">
                                    <div className="grid gap-2">
                                      <Label>Price (BHD)</Label>
                                      <Input name="price" type="number" step="0.001" defaultValue={Number(p.price ?? 0)} />
                                    </div>
                                    <div className="grid gap-2">
                                      <Label>Stock</Label>
                                      <Input name="stock" type="number" step="1" defaultValue={Number(p.stock ?? 0)} />
                                    </div>
                                  </div>
                                  <div className="grid gap-2">
                                    <Label>Images (up to 4)</Label>
                                    <div className="grid gap-3 md:grid-cols-2">
                                      <MediaFileInput name="image_1" accept="image/*" />
                                      <MediaFileInput name="image_2" accept="image/*" />
                                      <MediaFileInput name="image_3" accept="image/*" />
                                      <MediaFileInput name="image_4" accept="image/*" />
                                    </div>
                                    <label className="flex items-center gap-2 text-xs text-muted-foreground">
                                      <input type="checkbox" name="replace_images" className="h-4 w-4" />
                                      Replace existing images (otherwise new images are appended)
                                    </label>
                                  </div>
                                  <div className="grid gap-2">
                                    <Label>Status</Label>
                                    <select name="active" defaultValue={p.active ? "on" : "off"} className="h-10 rounded-md border border-white/10 bg-white/5 px-3 text-sm">
                                      <option value="on">Active</option>
                                      <option value="off">Inactive</option>
                                    </select>
                                  </div>
                                  <div className="flex justify-end gap-2">
                                    <Button type="submit" size="sm" variant="secondary">
                                      Save
                                    </Button>
                                  </div>
                                </form>
                                <form action={deleteProduct} className="mt-3 flex justify-end">
                                  <input type="hidden" name="id" value={p.id} />
                                  <input type="hidden" name="shop_id" value={shopId} />
                                  <Button type="submit" size="sm" variant="ghost">
                                    Delete
                                  </Button>
                                </form>
                              </div>
                            </details>
                          </td>
                        </tr>
                      );
                    })
                  ) : (
                    <tr>
                      <td colSpan={5} className="px-5 py-10 text-center text-muted-foreground">
                        No products yet.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </LuxuryCard>
        </>
      )}
    </div>
  );
}

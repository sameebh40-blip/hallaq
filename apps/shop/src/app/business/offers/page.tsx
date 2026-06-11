import { redirect } from "next/navigation";

import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getMyProfile } from "@hallaq/supabase/profile";

import { getMyShopContext } from "@/lib/my-shop-context";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

function toDatetimeLocal(iso: string | null) {
  if (!iso) return "";
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export default async function BusinessOffersPage({ searchParams }: { searchParams?: Promise<{ shopId?: string; error?: string }> }) {
  const sp = searchParams ? await searchParams : undefined;
  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);
  const ctx = await getMyShopContext(supabase);
  const shopId = ctx.shop?.id ?? (profile?.role === "admin" ? (sp?.shopId ?? null) : null);
  if (!shopId) return <div className="text-sm text-muted-foreground">No shop selected.</div>;

  const { data: offers } = await supabase
    .from("offers")
    .select("id, title, description, discount_percent, valid_from, valid_to, active, created_at")
    .eq("shop_id", shopId)
    .order("created_at", { ascending: false })
    .limit(200);

  async function createOffer(formData: FormData) {
    "use server";
    const shopId = String(formData.get("shop_id") ?? "").trim();
    const title = String(formData.get("title") ?? "").trim();
    const description = String(formData.get("description") ?? "").trim();
    const discountPercent = Number(formData.get("discount_percent") ?? 0);
    const validFromRaw = String(formData.get("valid_from") ?? "").trim();
    const validToRaw = String(formData.get("valid_to") ?? "").trim();
    const active = String(formData.get("active") ?? "") !== "off";
    if (!shopId || !title) redirect("/business/offers");

    const valid_from = validFromRaw ? new Date(validFromRaw).toISOString() : null;
    const valid_to = validToRaw ? new Date(validToRaw).toISOString() : null;

    const supabase = await createAppSupabaseServerClient();
    const { error } = await supabase.from("offers").insert({
      shop_id: shopId,
      title,
      description: description || null,
      discount_percent: Number.isFinite(discountPercent) && discountPercent > 0 ? discountPercent : null,
      valid_from,
      valid_to,
      active
    });
    if (error) redirect(`/business/offers?error=${encodeURIComponent(error.message)}`);
    redirect("/business/offers");
  }

  async function updateOffer(formData: FormData) {
    "use server";
    const id = String(formData.get("id") ?? "").trim();
    const shopId = String(formData.get("shop_id") ?? "").trim();
    const title = String(formData.get("title") ?? "").trim();
    const description = String(formData.get("description") ?? "").trim();
    const discountPercent = Number(formData.get("discount_percent") ?? 0);
    const validFromRaw = String(formData.get("valid_from") ?? "").trim();
    const validToRaw = String(formData.get("valid_to") ?? "").trim();
    const active = String(formData.get("active") ?? "") !== "off";
    if (!id || !shopId || !title) redirect("/business/offers");

    const valid_from = validFromRaw ? new Date(validFromRaw).toISOString() : null;
    const valid_to = validToRaw ? new Date(validToRaw).toISOString() : null;

    const supabase = await createAppSupabaseServerClient();
    const { error } = await supabase
      .from("offers")
      .update({
        title,
        description: description || null,
        discount_percent: Number.isFinite(discountPercent) && discountPercent > 0 ? discountPercent : null,
        valid_from,
        valid_to,
        active
      })
      .eq("id", id)
      .eq("shop_id", shopId);
    if (error) redirect(`/business/offers?error=${encodeURIComponent(error.message)}`);
    redirect("/business/offers");
  }

  async function deleteOffer(formData: FormData) {
    "use server";
    const id = String(formData.get("id") ?? "").trim();
    const shopId = String(formData.get("shop_id") ?? "").trim();
    if (!id || !shopId) redirect("/business/offers");
    const supabase = await createAppSupabaseServerClient();
    const { error } = await supabase.from("offers").delete().eq("id", id).eq("shop_id", shopId);
    if (error) redirect(`/business/offers?error=${encodeURIComponent(error.message)}`);
    redirect("/business/offers");
  }

  return (
    <div className="grid gap-4">
      {sp?.error ? (
        <LuxuryCard className="border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{sp.error}</LuxuryCard>
      ) : null}

      <LuxuryCard className="p-5">
        <div className="text-base font-semibold">Create offer</div>
        <form action={createOffer} className="mt-4 grid gap-4 md:grid-cols-2">
          <input type="hidden" name="shop_id" value={shopId} />
          <div className="grid gap-2 md:col-span-2">
            <Label htmlFor="title">Title</Label>
            <Input id="title" name="title" placeholder="20% off Haircut" required />
          </div>
          <div className="grid gap-2 md:col-span-2">
            <Label htmlFor="description">Description</Label>
            <Input id="description" name="description" placeholder="Valid this weekend only…" />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="discount_percent">Discount %</Label>
            <Input id="discount_percent" name="discount_percent" type="number" step="0.01" defaultValue="0" />
          </div>
          <div className="grid gap-2">
            <Label>Status</Label>
            <select name="active" defaultValue="on" className="h-10 rounded-md border border-white/10 bg-white/5 px-3 text-sm">
              <option value="on">Active</option>
              <option value="off">Inactive</option>
            </select>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="valid_from">Valid from</Label>
            <Input id="valid_from" name="valid_from" type="datetime-local" />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="valid_to">Valid to</Label>
            <Input id="valid_to" name="valid_to" type="datetime-local" />
          </div>
          <div className="flex justify-end md:col-span-2">
            <Button type="submit" variant="secondary">
              Create offer
            </Button>
          </div>
        </form>
      </LuxuryCard>

      <LuxuryCard className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[980px] text-sm">
            <thead className="text-xs text-muted-foreground">
              <tr className="border-b border-white/10">
                <th className="px-5 py-3 text-left font-medium">Offer</th>
                <th className="px-5 py-3 text-left font-medium">Window</th>
                <th className="px-5 py-3 text-left font-medium">Status</th>
                <th className="px-5 py-3 text-right font-medium">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/10">
              {offers?.length ? (
                offers.map((o) => (
                  <tr key={o.id} className="hover:bg-white/5">
                    <td className="px-5 py-3">
                      <div className="font-medium">{o.title ?? "Offer"}</div>
                      <div className="text-xs text-muted-foreground">{o.description ?? ""}</div>
                      <div className="text-xs text-muted-foreground">{o.discount_percent != null ? `${o.discount_percent}%` : "—"}</div>
                    </td>
                    <td className="px-5 py-3 text-muted-foreground">
                      {o.valid_from ? new Date(o.valid_from).toLocaleString() : "—"} → {o.valid_to ? new Date(o.valid_to).toLocaleString() : "—"}
                    </td>
                    <td className="px-5 py-3 text-muted-foreground">{o.active ? "Active" : "Inactive"}</td>
                    <td className="px-5 py-3">
                      <div className="flex justify-end gap-2">
                        <details className="group">
                          <summary className="cursor-pointer list-none rounded-md border border-white/10 bg-white/5 px-3 py-2 text-xs text-muted-foreground hover:bg-white/10">
                            Edit
                          </summary>
                          <div className="mt-2 w-[560px] max-w-[90vw] rounded-md border border-white/10 bg-background/80 p-4 backdrop-blur">
                            <form action={updateOffer} className="grid gap-3">
                              <input type="hidden" name="id" value={o.id} />
                              <input type="hidden" name="shop_id" value={shopId} />
                              <div className="grid gap-2">
                                <Label>Title</Label>
                                <Input name="title" defaultValue={o.title ?? ""} required />
                              </div>
                              <div className="grid gap-2">
                                <Label>Description</Label>
                                <Input name="description" defaultValue={o.description ?? ""} />
                              </div>
                              <div className="grid grid-cols-2 gap-2">
                                <div className="grid gap-2">
                                  <Label>Discount %</Label>
                                  <Input name="discount_percent" type="number" step="0.01" defaultValue={Number(o.discount_percent ?? 0)} />
                                </div>
                                <div className="grid gap-2">
                                  <Label>Status</Label>
                                  <select name="active" defaultValue={o.active ? "on" : "off"} className="h-10 rounded-md border border-white/10 bg-white/5 px-3 text-sm">
                                    <option value="on">Active</option>
                                    <option value="off">Inactive</option>
                                  </select>
                                </div>
                              </div>
                              <div className="grid grid-cols-2 gap-2">
                                <div className="grid gap-2">
                                  <Label>Valid from</Label>
                                  <Input name="valid_from" type="datetime-local" defaultValue={toDatetimeLocal(o.valid_from)} />
                                </div>
                                <div className="grid gap-2">
                                  <Label>Valid to</Label>
                                  <Input name="valid_to" type="datetime-local" defaultValue={toDatetimeLocal(o.valid_to)} />
                                </div>
                              </div>
                              <div className="flex justify-end gap-2">
                                <Button type="submit" size="sm" variant="secondary">
                                  Save
                                </Button>
                              </div>
                            </form>
                          </div>
                        </details>
                        <form action={deleteOffer}>
                          <input type="hidden" name="id" value={o.id} />
                          <input type="hidden" name="shop_id" value={shopId} />
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
                  <td colSpan={4} className="px-5 py-10 text-center text-muted-foreground">
                    No offers yet.
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

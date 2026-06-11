import Link from "next/link";
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
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as an admin account.";
  }
  return m;
}

export default async function AdminProductTaxonomyPage({ searchParams }: { searchParams?: Promise<{ error?: string }> }) {
  const params = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((params?.error ?? "").trim());

  const supabase = await createSupabaseServerClient();

  const { data: categories } = await supabase
    .from("product_categories")
    .select("id, name_en, name_ar, created_at")
    .order("name_en", { ascending: true })
    .limit(500);

  const { data: tags } = await supabase.from("product_tags").select("id, name, created_at").order("name", { ascending: true }).limit(1000);

  async function createCategory(formData: FormData) {
    "use server";

    const nameEn = String(formData.get("name_en") ?? "").trim();
    const nameAr = String(formData.get("name_ar") ?? "").trim();
    if (!nameEn) redirect("/product-taxonomy");
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("product_categories").insert({ name_en: nameEn, name_ar: nameAr || null });
    if (error) redirect(`/product-taxonomy?error=${encodeURIComponent(error.message)}`);
    redirect("/product-taxonomy");
  }

  async function deleteCategory(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("product_categories").delete().eq("id", id);
    if (error) redirect(`/product-taxonomy?error=${encodeURIComponent(error.message)}`);
    redirect("/product-taxonomy");
  }

  async function createTag(formData: FormData) {
    "use server";

    const name = String(formData.get("name") ?? "").trim();
    if (!name) redirect("/product-taxonomy");
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("product_tags").upsert({ name }, { onConflict: "name" });
    if (error) redirect(`/product-taxonomy?error=${encodeURIComponent(error.message)}`);
    redirect("/product-taxonomy");
  }

  async function deleteTag(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "").trim();
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.from("product_tags").delete().eq("id", id);
    if (error) redirect(`/product-taxonomy?error=${encodeURIComponent(error.message)}`);
    redirect("/product-taxonomy");
  }

  return (
    <PageFrame
      title="Product taxonomy"
      subtitle="Manage product categories and tags."
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/products">Back</Link>
        </Button>
      }
    >
      {params?.error ? (
        <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard>
      ) : null}

      <div className="grid gap-6 lg:grid-cols-2">
        <LuxuryCard className="p-5">
          <div className="mb-3 text-sm font-semibold">Categories</div>
          <form action={createCategory} className="grid gap-3 md:grid-cols-3">
            <div className="grid gap-2">
              <Label htmlFor="name_en">Name (EN)</Label>
              <Input id="name_en" name="name_en" required />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="name_ar">Name (AR)</Label>
              <Input id="name_ar" name="name_ar" />
            </div>
            <div className="flex items-end justify-end">
              <Button type="submit" variant="secondary">
                Add
              </Button>
            </div>
          </form>

          <div className="mt-4 grid gap-2">
            {(categories ?? []).map((c) => (
              <div key={c.id} className="flex items-center justify-between rounded-lg border border-white/10 bg-white/5 px-3 py-2">
                <div className="text-sm">
                  <div className="font-medium">{c.name_en}</div>
                  {c.name_ar ? <div className="text-xs text-muted-foreground">{c.name_ar}</div> : null}
                </div>
                <form action={deleteCategory}>
                  <input type="hidden" name="id" value={c.id} />
                  <Button type="submit" size="sm" variant="ghost">
                    Delete
                  </Button>
                </form>
              </div>
            ))}
            {!categories?.length ? <div className="text-xs text-muted-foreground">No categories yet.</div> : null}
          </div>
        </LuxuryCard>

        <LuxuryCard className="p-5">
          <div className="mb-3 text-sm font-semibold">Tags</div>
          <form action={createTag} className="grid gap-3 md:grid-cols-3">
            <div className="grid gap-2 md:col-span-2">
              <Label htmlFor="tag_name">Name</Label>
              <Input id="tag_name" name="name" required />
            </div>
            <div className="flex items-end justify-end">
              <Button type="submit" variant="secondary">
                Add
              </Button>
            </div>
          </form>

          <div className="mt-4 grid gap-2">
            {(tags ?? []).map((t) => (
              <div key={t.id} className="flex items-center justify-between rounded-lg border border-white/10 bg-white/5 px-3 py-2">
                <div className="text-sm font-medium">{t.name}</div>
                <form action={deleteTag}>
                  <input type="hidden" name="id" value={t.id} />
                  <Button type="submit" size="sm" variant="ghost">
                    Delete
                  </Button>
                </form>
              </div>
            ))}
            {!tags?.length ? <div className="text-xs text-muted-foreground">No tags yet.</div> : null}
          </div>
        </LuxuryCard>
      </div>
    </PageFrame>
  );
}


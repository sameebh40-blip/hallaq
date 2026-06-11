import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getT } from "@hallaq/ui/translations-server";

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

type AwardRow = {
  id: string;
  year: number;
  target_type: string;
  target_id: string;
  created_at: string;
  category: { id: string; name_en: string; name_ar: string }[] | null;
};

export default async function AwardsPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const t = await getT();
  const params = searchParams ? await searchParams : undefined;
  const errorMessage = userFacingDbError((params?.error ?? "").trim());
  const supabase = await createSupabaseServerClient();

  const [{ data: categories }, { data: awards }] = await Promise.all([
    supabase.from("award_categories").select("id, name_en, name_ar, created_at").order("created_at", { ascending: false }),
    supabase
      .from("awards")
      .select("id, year, target_type, target_id, created_at, category:award_categories(id, name_en, name_ar)")
      .order("year", { ascending: false })
      .limit(80)
  ]);

  async function createCategory(formData: FormData) {
    "use server";

    const nameEn = String(formData.get("nameEn") ?? "").trim();
    const nameAr = String(formData.get("nameAr") ?? "").trim();
    if (!nameEn || !nameAr) redirect("/awards");

    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const { data: created, error } = await supabase
      .from("award_categories")
      .insert({ name_en: nameEn, name_ar: nameAr })
      .select("id")
      .single();
    if (error) redirect(`/awards?error=${encodeURIComponent(error.message)}`);

    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "award_category_created",
      entity_type: "award_category",
      entity_id: created?.id ?? null,
      meta: { nameEn, nameAr }
    });
    if (logError) redirect(`/awards?error=${encodeURIComponent(logError.message)}`);

    redirect("/awards");
  }

  async function assignWinner(formData: FormData) {
    "use server";

    const categoryId = String(formData.get("categoryId") ?? "");
    const year = Number(formData.get("year") ?? new Date().getFullYear());
    const targetType = String(formData.get("targetType") ?? "barber");
    const targetId = String(formData.get("targetId") ?? "");

    if (!categoryId || !targetId) redirect("/awards");

    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const { data: created, error } = await supabase
      .from("awards")
      .insert({ category_id: categoryId, year, target_type: targetType, target_id: targetId })
      .select("id")
      .single();
    if (error) redirect(`/awards?error=${encodeURIComponent(error.message)}`);

    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "award_assigned",
      entity_type: "award",
      entity_id: created?.id ?? null,
      meta: { categoryId, year, targetType, targetId }
    });
    if (logError) redirect(`/awards?error=${encodeURIComponent(logError.message)}`);

    redirect("/awards");
  }

  return (
    <PageFrame
      title={t("admin.nav.awards")}
      subtitle="Create awards and assign prestige categories to barbers and stores."
      actions={
        <div className="flex items-center gap-2">
          <Button asChild variant="ghost" size="sm">
            <a href="#categories">Categories</a>
          </Button>
          <Button asChild variant="secondary" size="sm">
            <a href="#winners">Assign Winner</a>
          </Button>
        </div>
      }
    >
      {params?.error ? (
        <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">
          {errorMessage}
        </LuxuryCard>
      ) : null}
      <div className="grid grid-cols-1 gap-3 xl:grid-cols-2">
        <LuxuryCard id="categories" className="p-5">
          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Categories</div>
            <div className="text-xs text-muted-foreground">Enterprise-grade social proof.</div>
          </div>

          <form action={createCategory} className="mt-4 grid grid-cols-1 gap-3">
            <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
              <input
                name="nameEn"
                placeholder="Name (EN)"
                className="h-11 rounded-lg border border-white/10 bg-white/5 px-3 text-sm outline-none focus:ring-2 focus:ring-primary/40"
              />
              <input
                name="nameAr"
                placeholder="Name (AR)"
                className="h-11 rounded-lg border border-white/10 bg-white/5 px-3 text-sm outline-none focus:ring-2 focus:ring-primary/40"
              />
            </div>
            <Button type="submit" className="h-11">
              Create Category
            </Button>
          </form>

          <div className="mt-4 grid grid-cols-1 gap-2 text-sm">
            {categories?.length ? (
              categories.map((c) => (
                <div key={c.id} className="rounded-lg border border-white/10 bg-white/5 px-4 py-3">
                  <div className="font-medium">{c.name_en}</div>
                  <div className="text-xs text-muted-foreground">{c.name_ar}</div>
                </div>
              ))
            ) : (
              <div className="rounded-lg border border-white/10 bg-white/5 p-4 text-sm text-muted-foreground">
                No categories yet.
              </div>
            )}
          </div>
        </LuxuryCard>

        <LuxuryCard id="winners" className="p-5">
          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Winners</div>
            <div className="text-xs text-muted-foreground">Assign winners by year and category.</div>
          </div>

          <form action={assignWinner} className="mt-4 grid grid-cols-1 gap-3">
            <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
              <select
                name="categoryId"
                className="h-11 rounded-lg border border-white/10 bg-white/5 px-3 text-sm outline-none focus:ring-2 focus:ring-primary/40"
                defaultValue=""
              >
                <option value="">Select category…</option>
                {(categories ?? []).map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name_en}
                  </option>
                ))}
              </select>
              <input
                name="year"
                defaultValue={String(new Date().getFullYear())}
                className="h-11 rounded-lg border border-white/10 bg-white/5 px-3 text-sm outline-none focus:ring-2 focus:ring-primary/40"
              />
            </div>
            <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
              <select
                name="targetType"
                className="h-11 rounded-lg border border-white/10 bg-white/5 px-3 text-sm outline-none focus:ring-2 focus:ring-primary/40"
                defaultValue="barber"
              >
                <option value="barber">Barber</option>
                <option value="shop">Shop</option>
              </select>
              <input
                name="targetId"
                placeholder="Target UUID"
                className="h-11 rounded-lg border border-white/10 bg-white/5 px-3 text-sm outline-none focus:ring-2 focus:ring-primary/40"
              />
            </div>
            <Button type="submit" className="h-11">
              Assign Winner
            </Button>
          </form>

          <div className="mt-4 divide-y divide-white/10 overflow-hidden rounded-lg border border-white/10 bg-white/5">
            {awards?.length ? (
              (awards as unknown as AwardRow[]).map((a) => (
                <div key={a.id} className="flex items-start justify-between gap-4 px-4 py-3 text-sm">
                  <div className="flex flex-col gap-1">
                    <div className="font-medium">
                      {a.category?.[0]?.name_en ?? "Category"} • {a.year}
                    </div>
                    <div className="text-xs text-muted-foreground">
                      {a.target_type} • <span className="font-mono">{a.target_id}</span>
                    </div>
                  </div>
                  <div className="text-xs text-muted-foreground">
                    {Intl.DateTimeFormat("en", { dateStyle: "medium" }).format(new Date(a.created_at))}
                  </div>
                </div>
              ))
            ) : (
              <div className="px-4 py-8 text-center text-sm text-muted-foreground">No winners yet.</div>
            )}
          </div>
        </LuxuryCard>
      </div>
    </PageFrame>
  );
}

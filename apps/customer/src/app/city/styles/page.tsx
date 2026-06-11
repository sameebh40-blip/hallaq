import Link from "next/link";

import { getT } from "@hallaq/ui/translations-server";
import { cn } from "@hallaq/ui/cn";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { SafeImage } from "@/components/safe-image";
import { createAppSupabaseServerClient } from "@/lib/supabase";
import { signedOrUrl } from "@hallaq/supabase/storage";

export const dynamic = "force-dynamic";

type CategoryKey = "All" | "Fade" | "Crop" | "Classic" | "Trending";

type StyleLibraryListRow = {
  id: unknown;
  name_en?: unknown;
  name_ar?: unknown;
  category?: unknown;
  cover_url?: unknown;
  cover_path?: unknown;
  views_count?: unknown;
};

function pickString(...values: unknown[]): string | null {
  for (const v of values) {
    if (typeof v === "string") {
      const t = v.trim();
      if (t) return t;
    }
  }
  return null;
}

function categoryFromParam(value: string | undefined): CategoryKey {
  const v = (value ?? "").trim();
  if (v === "Fade" || v === "Crop" || v === "Classic" || v === "Trending") return v;
  return "All";
}

export default async function CityStylesPage({ searchParams }: { searchParams: Promise<{ cat?: string }> }) {
  const t = await getT();
  const params = await searchParams;
  const cat = categoryFromParam(params.cat);
  const supabase = await createAppSupabaseServerClient();

  const categories: CategoryKey[] = ["All", "Fade", "Crop", "Classic", "Trending"];
  const stylesQuery = supabase
    .from("style_library")
    .select("id, name_en, name_ar, category, cover_url, cover_path, views_count")
    .eq("is_active", true)
    .eq("status", "approved")
    .order("views_count", { ascending: false })
    .order("created_at", { ascending: false })
    .limit(60);

  const { data, error } =
    cat === "All" ? await stylesQuery : await stylesQuery.eq("category", cat);

  const list = await Promise.all(
    (data ?? []).map(async (s) => {
      const row = s as unknown as StyleLibraryListRow;
      const coverRef = pickString(row.cover_path, row.cover_url);
      const cover = await signedOrUrl(supabase, "style-library", coverRef);
      const name = pickString(row.name_en, row.name_ar) ?? "Style";
      return {
        id: String(row.id),
        name,
        views: Number(row.views_count ?? 0),
        coverUrl: (typeof cover === "string" && cover.trim()) ? cover : null
      };
    })
  );

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 px-4 pt-6 pb-24">
      <header className="flex items-center justify-between">
        <div className="flex flex-col gap-1">
          <div className="text-[13px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">{t("customer.city.title")}</div>
          <div className="text-sm font-semibold text-[#111111]">Style Library</div>
        </div>
        <Link href="/city" className="text-xs font-semibold text-muted-foreground underline underline-offset-4">
          Back
        </Link>
      </header>

      <div className="flex gap-2 overflow-x-auto pb-1">
        {categories.map((c) => {
          const active = c === cat;
          const href = c === "All" ? "/city/styles" : `/city/styles?cat=${encodeURIComponent(c)}`;
          return (
            <Link
              key={c}
              href={href}
              className={cn(
                "shrink-0 rounded-full border px-3 py-2 text-[12px] font-semibold leading-none transition",
                active
                  ? "border-[hsl(var(--gold))] bg-[hsl(var(--gold))/0.10] text-[#111111]"
                  : "border-black/10 bg-white text-muted-foreground hover:border-black/20"
              )}
            >
              {c}
            </Link>
          );
        })}
      </div>

      {error ? (
        <div className="rounded-[26px] border bg-white p-4 text-sm text-muted-foreground">
          Styles are unavailable right now. Refresh the page to try again.
        </div>
      ) : null}

      <div className="grid grid-cols-2 gap-3">
        {list.map((s) => (
          <Link key={s.id} href={`/city/styles/${encodeURIComponent(s.id)}`} className="block">
            <div className="overflow-hidden rounded-[24px] border bg-white shadow-[0_16px_36px_rgba(17,17,17,0.08)]">
              <div className="aspect-square w-full overflow-hidden">
                <SafeImage src={s.coverUrl} fallbackKey="default_style_image" alt={s.name} className="h-full w-full object-cover" />
              </div>
              <div className="p-3">
                <div className="text-[12px] font-semibold text-[#111111]">{s.name}</div>
                <div className="mt-1 text-[11px] text-muted-foreground">{s.views.toLocaleString()} views</div>
              </div>
            </div>
          </Link>
        ))}
      </div>

      <CustomerBottomNav />
    </main>
  );
}

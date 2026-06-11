import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";
import { MissingSection } from "./missing-section";

export const dynamic = "force-dynamic";

type BrandAssetKey = string;

async function getBrandAssetUrl(supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>, key: BrandAssetKey) {
  const { data } = await supabase
    .from("brand_assets")
    .select("asset_url")
    .eq("asset_key", key)
    .eq("is_active", true)
    .maybeSingle();
  const url = (data?.asset_url ?? "").trim();
  return url || null;
}

export default async function MissingImagesPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string; applied?: string }>;
}) {
  const sp = searchParams ? await searchParams : undefined;
  const errorMsg = (sp?.error ?? "").trim();
  const appliedMsg = (sp?.applied ?? "").trim();

  const supabase = await createSupabaseServerClient();

  async function applyDefault(formData: FormData) {
    "use server";

    const entityType = String(formData.get("entity_type") ?? "").trim();
    const entityId = String(formData.get("entity_id") ?? "").trim();
    const field = String(formData.get("field") ?? "").trim();
    if (!entityType || !entityId || !field) redirect("/missing-images");

    const supabase = await createSupabaseServerClient();

    const keyByField: Record<string, BrandAssetKey> = {
      profile_avatar: "default_profile_avatar",
      barber_avatar: "default_barber_avatar",
      barber_cover: "default_barber_cover",
      shop_logo: "default_shop_logo",
      shop_cover: "default_shop_cover",
      service_image: "default_service_image",
      product_image: "default_product_image",
      reel_thumbnail: "default_reel_thumbnail",
      post_thumbnail: "default_reel_thumbnail"
    };

    const key = keyByField[field];
    if (!key) redirect("/missing-images");

    const url = await getBrandAssetUrl(supabase, key);
    if (!url) redirect(`/missing-images?error=${encodeURIComponent(`Missing brand asset: ${key}. Upload it in Brand Assets.`)}`);

    let error: { message: string } | null = null;
    if (entityType === "profiles" && field === "profile_avatar") {
      const res = await supabase.from("profiles").update({ avatar_url: url, avatar_path: null }).eq("id", entityId);
      error = res.error ? { message: res.error.message } : null;
    } else if (entityType === "barbers" && field === "barber_avatar") {
      const res = await supabase.from("barbers").update({ avatar_url: url, avatar_path: null }).eq("id", entityId);
      error = res.error ? { message: res.error.message } : null;
    } else if (entityType === "barbers" && field === "barber_cover") {
      const res = await supabase.from("barbers").update({ cover_url: url, cover_path: null }).eq("id", entityId);
      error = res.error ? { message: res.error.message } : null;
    } else if (entityType === "barbershops" && field === "shop_logo") {
      const res = await supabase.from("barbershops").update({ logo_url: url, logo_path: null }).eq("id", entityId);
      error = res.error ? { message: res.error.message } : null;
    } else if (entityType === "barbershops" && field === "shop_cover") {
      const res = await supabase.from("barbershops").update({ cover_url: url, cover_path: null }).eq("id", entityId);
      error = res.error ? { message: res.error.message } : null;
    } else if (entityType === "services" && field === "service_image") {
      const res = await supabase.from("services").update({ image_url: url }).eq("id", entityId);
      error = res.error ? { message: res.error.message } : null;
    } else if (entityType === "products" && field === "product_image") {
      const res = await supabase.from("products").update({ image_url: url }).eq("id", entityId);
      error = res.error ? { message: res.error.message } : null;
    } else if (entityType === "reels" && field === "reel_thumbnail") {
      const res = await supabase.from("reels").update({ thumbnail_url: url, thumbnail_path: null }).eq("id", entityId);
      error = res.error ? { message: res.error.message } : null;
    } else if (entityType === "posts" && field === "post_thumbnail") {
      const res = await supabase.from("posts").update({ thumbnail_url: url, thumbnail_path: null }).eq("id", entityId);
      error = res.error ? { message: res.error.message } : null;
    } else {
      redirect("/missing-images");
    }

    if (error) redirect(`/missing-images?error=${encodeURIComponent(error.message)}`);
    redirect(`/missing-images?applied=${encodeURIComponent(`${entityType}:${field}:${entityId}`)}`);
  }

  async function applyDefaultBulk(formData: FormData) {
    "use server";

    const entityType = String(formData.get("entity_type") ?? "").trim();
    const field = String(formData.get("field") ?? "").trim();
    const ids = (formData.getAll("entity_ids") ?? []).map((v) => String(v).trim()).filter(Boolean);
    if (!entityType || !field || !ids.length) redirect("/missing-images");

    const supabase = await createSupabaseServerClient();

    const keyByField: Record<string, BrandAssetKey> = {
      profile_avatar: "default_profile_avatar",
      barber_avatar: "default_barber_avatar",
      barber_cover: "default_barber_cover",
      shop_logo: "default_shop_logo",
      shop_cover: "default_shop_cover",
      service_image: "default_service_image",
      product_image: "default_product_image",
      reel_thumbnail: "default_reel_thumbnail",
      post_thumbnail: "default_reel_thumbnail"
    };

    const key = keyByField[field];
    if (!key) redirect("/missing-images");

    const url = await getBrandAssetUrl(supabase, key);
    if (!url) redirect(`/missing-images?error=${encodeURIComponent(`Missing brand asset: ${key}. Upload it in Brand Assets.`)}`);

    let error: { message: string } | null = null;
    if (entityType === "profiles" && field === "profile_avatar") {
      const res = await supabase.from("profiles").update({ avatar_url: url, avatar_path: null }).in("id", ids);
      error = res.error ? { message: res.error.message } : null;
    } else if (entityType === "barbers" && field === "barber_avatar") {
      const res = await supabase.from("barbers").update({ avatar_url: url, avatar_path: null }).in("id", ids);
      error = res.error ? { message: res.error.message } : null;
    } else if (entityType === "barbers" && field === "barber_cover") {
      const res = await supabase.from("barbers").update({ cover_url: url, cover_path: null }).in("id", ids);
      error = res.error ? { message: res.error.message } : null;
    } else if (entityType === "barbershops" && field === "shop_logo") {
      const res = await supabase.from("barbershops").update({ logo_url: url, logo_path: null }).in("id", ids);
      error = res.error ? { message: res.error.message } : null;
    } else if (entityType === "barbershops" && field === "shop_cover") {
      const res = await supabase.from("barbershops").update({ cover_url: url, cover_path: null }).in("id", ids);
      error = res.error ? { message: res.error.message } : null;
    } else if (entityType === "services" && field === "service_image") {
      const res = await supabase.from("services").update({ image_url: url }).in("id", ids);
      error = res.error ? { message: res.error.message } : null;
    } else if (entityType === "products" && field === "product_image") {
      const res = await supabase.from("products").update({ image_url: url }).in("id", ids);
      error = res.error ? { message: res.error.message } : null;
    } else if (entityType === "reels" && field === "reel_thumbnail") {
      const res = await supabase.from("reels").update({ thumbnail_url: url, thumbnail_path: null }).in("id", ids);
      error = res.error ? { message: res.error.message } : null;
    } else if (entityType === "posts" && field === "post_thumbnail") {
      const res = await supabase.from("posts").update({ thumbnail_url: url, thumbnail_path: null }).in("id", ids);
      error = res.error ? { message: res.error.message } : null;
    } else {
      redirect("/missing-images");
    }

    if (error) redirect(`/missing-images?error=${encodeURIComponent(error.message)}`);
    redirect(`/missing-images?applied=${encodeURIComponent(`${entityType}:${field}:bulk(${ids.length})`)}`);
  }

  async function applyDefaultsForSection(formData: FormData) {
    "use server";

    const sectionId = String(formData.get("section_id") ?? "").trim();
    if (!sectionId) redirect("/missing-images");

    const supabase = await createSupabaseServerClient();

    async function applyDefaultsForSectionId(supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>, sectionId: string) {
      const keyBySection: Record<string, BrandAssetKey> = {
        "profiles.avatar": "default_profile_avatar",
        "shops.logo": "default_shop_logo",
        "shops.cover": "default_shop_cover",
        "barbers.avatar": "default_barber_avatar",
        "barbers.cover": "default_barber_cover",
        "services.image": "default_service_image",
        "products.image": "default_product_image",
        "reels.thumb": "default_reel_thumbnail",
        "posts.thumb": "default_reel_thumbnail"
      };

      const key = keyBySection[sectionId];
      if (!key) throw new Error(`Unknown section: ${sectionId}`);

      const url = await getBrandAssetUrl(supabase, key);
      if (!url) throw new Error(`Missing brand asset: ${key}. Upload it in Brand Assets.`);

      if (sectionId === "profiles.avatar") {
        const res = await supabase
          .from("profiles")
          .update({ avatar_url: url, avatar_path: null }, { count: "exact" })
          .is("avatar_url", null)
          .is("avatar_path", null);
        if (res.error) throw new Error(res.error.message);
        return res.count ?? 0;
      }

      if (sectionId === "shops.logo") {
        const res = await supabase
          .from("barbershops")
          .update({ logo_url: url, logo_path: null }, { count: "exact" })
          .is("deleted_at", null)
          .is("logo_url", null)
          .is("logo_path", null);
        if (res.error) throw new Error(res.error.message);
        return res.count ?? 0;
      }

      if (sectionId === "shops.cover") {
        const res = await supabase
          .from("barbershops")
          .update({ cover_url: url, cover_path: null }, { count: "exact" })
          .is("deleted_at", null)
          .is("cover_url", null)
          .is("cover_path", null);
        if (res.error) throw new Error(res.error.message);
        return res.count ?? 0;
      }

      if (sectionId === "barbers.avatar") {
        const res = await supabase
          .from("barbers")
          .update({ avatar_url: url, avatar_path: null }, { count: "exact" })
          .is("deleted_at", null)
          .is("avatar_url", null)
          .is("avatar_path", null);
        if (res.error) throw new Error(res.error.message);
        return res.count ?? 0;
      }

      if (sectionId === "barbers.cover") {
        const res = await supabase
          .from("barbers")
          .update({ cover_url: url, cover_path: null }, { count: "exact" })
          .is("deleted_at", null)
          .is("cover_url", null)
          .is("cover_path", null);
        if (res.error) throw new Error(res.error.message);
        return res.count ?? 0;
      }

      if (sectionId === "services.image") {
        const res = await supabase
          .from("services")
          .update({ image_url: url }, { count: "exact" })
          .is("deleted_at", null)
          .is("image_url", null);
        if (res.error) throw new Error(res.error.message);
        return res.count ?? 0;
      }

      if (sectionId === "products.image") {
        const res = await supabase
          .from("products")
          .update({ image_url: url }, { count: "exact" })
          .is("deleted_at", null)
          .is("image_url", null);
        if (res.error) throw new Error(res.error.message);
        return res.count ?? 0;
      }

      if (sectionId === "reels.thumb") {
        const res = await supabase
          .from("reels")
          .update({ thumbnail_url: url, thumbnail_path: null }, { count: "exact" })
          .is("deleted_at", null)
          .is("thumbnail_url", null)
          .is("thumbnail_path", null);
        if (res.error) throw new Error(res.error.message);
        return res.count ?? 0;
      }

      if (sectionId === "posts.thumb") {
        const res = await supabase
          .from("posts")
          .update({ thumbnail_url: url, thumbnail_path: null }, { count: "exact" })
          .is("deleted_at", null)
          .is("thumbnail_url", null)
          .is("thumbnail_path", null);
        if (res.error) throw new Error(res.error.message);
        return res.count ?? 0;
      }

      return 0;
    }

    try {
      const updatedCount = await applyDefaultsForSectionId(supabase, sectionId);
      redirect(`/missing-images?applied=${encodeURIComponent(`bulk:${sectionId}:${updatedCount}`)}`);
    } catch (e) {
      redirect(`/missing-images?error=${encodeURIComponent(e instanceof Error ? e.message : "Bulk apply failed")}`);
    }
  }

  async function fixAllMissing() {
    "use server";
    const supabase = await createSupabaseServerClient();
    const sections = [
      "profiles.avatar",
      "shops.logo",
      "shops.cover",
      "barbers.avatar",
      "barbers.cover",
      "services.image",
      "products.image",
      "reels.thumb",
      "posts.thumb"
    ];

    try {
      let total = 0;
      for (const sectionId of sections) {
        const urlBySection: Record<string, BrandAssetKey> = {
          "profiles.avatar": "default_profile_avatar",
          "shops.logo": "default_shop_logo",
          "shops.cover": "default_shop_cover",
          "barbers.avatar": "default_barber_avatar",
          "barbers.cover": "default_barber_cover",
          "services.image": "default_service_image",
          "products.image": "default_product_image",
          "reels.thumb": "default_reel_thumbnail",
          "posts.thumb": "default_reel_thumbnail"
        };
        const key = urlBySection[sectionId];
        const url = await getBrandAssetUrl(supabase, key);
        if (!url) throw new Error(`Missing brand asset: ${key}. Upload it in Brand Assets.`);
        if (sectionId === "profiles.avatar") {
          const res = await supabase.from("profiles").update({ avatar_url: url, avatar_path: null }, { count: "exact" }).is("avatar_url", null).is("avatar_path", null);
          if (res.error) throw new Error(res.error.message);
          total += res.count ?? 0;
        } else if (sectionId === "shops.logo") {
          const res = await supabase
            .from("barbershops")
            .update({ logo_url: url, logo_path: null }, { count: "exact" })
            .is("deleted_at", null)
            .is("logo_url", null)
            .is("logo_path", null);
          if (res.error) throw new Error(res.error.message);
          total += res.count ?? 0;
        } else if (sectionId === "shops.cover") {
          const res = await supabase
            .from("barbershops")
            .update({ cover_url: url, cover_path: null }, { count: "exact" })
            .is("deleted_at", null)
            .is("cover_url", null)
            .is("cover_path", null);
          if (res.error) throw new Error(res.error.message);
          total += res.count ?? 0;
        } else if (sectionId === "barbers.avatar") {
          const res = await supabase
            .from("barbers")
            .update({ avatar_url: url, avatar_path: null }, { count: "exact" })
            .is("deleted_at", null)
            .is("avatar_url", null)
            .is("avatar_path", null);
          if (res.error) throw new Error(res.error.message);
          total += res.count ?? 0;
        } else if (sectionId === "barbers.cover") {
          const res = await supabase
            .from("barbers")
            .update({ cover_url: url, cover_path: null }, { count: "exact" })
            .is("deleted_at", null)
            .is("cover_url", null)
            .is("cover_path", null);
          if (res.error) throw new Error(res.error.message);
          total += res.count ?? 0;
        } else if (sectionId === "services.image") {
          const res = await supabase.from("services").update({ image_url: url }, { count: "exact" }).is("deleted_at", null).is("image_url", null);
          if (res.error) throw new Error(res.error.message);
          total += res.count ?? 0;
        } else if (sectionId === "products.image") {
          const res = await supabase.from("products").update({ image_url: url }, { count: "exact" }).is("deleted_at", null).is("image_url", null);
          if (res.error) throw new Error(res.error.message);
          total += res.count ?? 0;
        } else if (sectionId === "reels.thumb") {
          const res = await supabase
            .from("reels")
            .update({ thumbnail_url: url, thumbnail_path: null }, { count: "exact" })
            .is("deleted_at", null)
            .is("thumbnail_url", null)
            .is("thumbnail_path", null);
          if (res.error) throw new Error(res.error.message);
          total += res.count ?? 0;
        } else if (sectionId === "posts.thumb") {
          const res = await supabase
            .from("posts")
            .update({ thumbnail_url: url, thumbnail_path: null }, { count: "exact" })
            .is("deleted_at", null)
            .is("thumbnail_url", null)
            .is("thumbnail_path", null);
          if (res.error) throw new Error(res.error.message);
          total += res.count ?? 0;
        }
      }
      redirect(`/missing-images?applied=${encodeURIComponent(`fix_all:${total}`)}`);
    } catch (e) {
      redirect(`/missing-images?error=${encodeURIComponent(e instanceof Error ? e.message : "Fix all failed")}`);
    }
  }

  const [
    profilesMissingAvatar,
    shopsMissingLogo,
    shopsMissingCover,
    barbersMissingAvatar,
    barbersMissingCover,
    servicesMissingImage,
    productsMissingImage,
    reelsMissingThumb,
    postsMissingThumb
  ] = await Promise.all([
    supabase
      .from("profiles")
      .select("id, full_name, email, avatar_url, avatar_path", { count: "exact" })
      .is("avatar_url", null)
      .is("avatar_path", null)
      .limit(25),
    supabase
      .from("barbershops")
      .select("id, name, logo_url, logo_path", { count: "exact" })
      .is("deleted_at", null)
      .is("logo_url", null)
      .is("logo_path", null)
      .limit(25),
    supabase
      .from("barbershops")
      .select("id, name, cover_url, cover_path", { count: "exact" })
      .is("deleted_at", null)
      .is("cover_url", null)
      .is("cover_path", null)
      .limit(25),
    supabase
      .from("barbers")
      .select("id, display_name, avatar_url, avatar_path", { count: "exact" })
      .is("deleted_at", null)
      .is("avatar_url", null)
      .is("avatar_path", null)
      .limit(25),
    supabase
      .from("barbers")
      .select("id, display_name, cover_url, cover_path", { count: "exact" })
      .is("deleted_at", null)
      .is("cover_url", null)
      .is("cover_path", null)
      .limit(25),
    supabase.from("services").select("id, name_en, name_ar, image_url", { count: "exact" }).is("deleted_at", null).is("image_url", null).limit(25),
    supabase.from("products").select("id, name, image_url", { count: "exact" }).is("deleted_at", null).is("image_url", null).limit(25),
    supabase
      .from("reels")
      .select("id, caption, media_type, thumbnail_url, thumbnail_path", { count: "exact" })
      .is("deleted_at", null)
      .is("thumbnail_url", null)
      .is("thumbnail_path", null)
      .limit(25)
    ,
    supabase
      .from("posts")
      .select("id, caption, media_type, thumbnail_url, thumbnail_path", { count: "exact" })
      .is("deleted_at", null)
      .is("thumbnail_url", null)
      .is("thumbnail_path", null)
      .limit(25)
  ]);

  const sections: Array<{
    id: string;
    title: string;
    count: number;
    rows: Array<{ id: string; label: string; href: string; entity_type: string; field: string }>;
  }> = [
    {
      id: "profiles.avatar",
      title: "Profiles without avatar",
      count: profilesMissingAvatar.count ?? 0,
      rows: ((profilesMissingAvatar.data ?? []) as Array<Record<string, unknown>>).map((r) => ({
        id: String(r.id),
        label: (String(r.full_name ?? "").trim() || String(r.email ?? "").trim() || "Profile").trim(),
        href: `/users/${encodeURIComponent(String(r.id))}`,
        entity_type: "profiles",
        field: "profile_avatar"
      }))
    },
    {
      id: "shops.logo",
      title: "Shops without logo",
      count: shopsMissingLogo.count ?? 0,
      rows: ((shopsMissingLogo.data ?? []) as Array<Record<string, unknown>>).map((r) => ({
        id: String(r.id),
        label: (String(r.name ?? "").trim() || "Shop").trim(),
        href: `/stores/${encodeURIComponent(String(r.id))}`,
        entity_type: "barbershops",
        field: "shop_logo"
      }))
    },
    {
      id: "shops.cover",
      title: "Shops without cover",
      count: shopsMissingCover.count ?? 0,
      rows: ((shopsMissingCover.data ?? []) as Array<Record<string, unknown>>).map((r) => ({
        id: String(r.id),
        label: (String(r.name ?? "").trim() || "Shop").trim(),
        href: `/stores/${encodeURIComponent(String(r.id))}`,
        entity_type: "barbershops",
        field: "shop_cover"
      }))
    },
    {
      id: "barbers.avatar",
      title: "Barbers without avatar",
      count: barbersMissingAvatar.count ?? 0,
      rows: ((barbersMissingAvatar.data ?? []) as Array<Record<string, unknown>>).map((r) => ({
        id: String(r.id),
        label: (String(r.display_name ?? "").trim() || "Barber").trim(),
        href: `/barbers/${encodeURIComponent(String(r.id))}`,
        entity_type: "barbers",
        field: "barber_avatar"
      }))
    },
    {
      id: "barbers.cover",
      title: "Barbers without cover",
      count: barbersMissingCover.count ?? 0,
      rows: ((barbersMissingCover.data ?? []) as Array<Record<string, unknown>>).map((r) => ({
        id: String(r.id),
        label: (String(r.display_name ?? "").trim() || "Barber").trim(),
        href: `/barbers/${encodeURIComponent(String(r.id))}`,
        entity_type: "barbers",
        field: "barber_cover"
      }))
    },
    {
      id: "services.image",
      title: "Services without image",
      count: servicesMissingImage.count ?? 0,
      rows: ((servicesMissingImage.data ?? []) as Array<Record<string, unknown>>).map((r) => ({
        id: String(r.id),
        label: (String(r.name_en ?? "").trim() || String(r.name_ar ?? "").trim() || "Service").trim(),
        href: `/services/${encodeURIComponent(String(r.id))}`,
        entity_type: "services",
        field: "service_image"
      }))
    },
    {
      id: "products.image",
      title: "Products without image",
      count: productsMissingImage.count ?? 0,
      rows: ((productsMissingImage.data ?? []) as Array<Record<string, unknown>>).map((r) => ({
        id: String(r.id),
        label: (String(r.name ?? "").trim() || "Product").trim(),
        href: `/products/${encodeURIComponent(String(r.id))}`,
        entity_type: "products",
        field: "product_image"
      }))
    },
    {
      id: "reels.thumb",
      title: "Reels without thumbnail",
      count: reelsMissingThumb.count ?? 0,
      rows: ((reelsMissingThumb.data ?? []) as Array<Record<string, unknown>>).map((r) => ({
        id: String(r.id),
        label: (String(r.caption ?? "").trim() || String(r.media_type ?? "Reel")).trim(),
        href: `/posts-reels/${encodeURIComponent(String(r.id))}`,
        entity_type: "reels",
        field: "reel_thumbnail"
      }))
    }
    ,
    {
      id: "posts.thumb",
      title: "Posts without thumbnail",
      count: postsMissingThumb.count ?? 0,
      rows: ((postsMissingThumb.data ?? []) as Array<Record<string, unknown>>).map((r) => ({
        id: String(r.id),
        label: (String(r.caption ?? "").trim() || String(r.media_type ?? "Post")).trim(),
        href: `/posts-reels/${encodeURIComponent(String(r.id))}`,
        entity_type: "posts",
        field: "post_thumbnail"
      }))
    }
  ];

  const metaBySectionId: Record<string, { entityType: string; field: string }> = {
    "profiles.avatar": { entityType: "profiles", field: "profile_avatar" },
    "shops.logo": { entityType: "barbershops", field: "shop_logo" },
    "shops.cover": { entityType: "barbershops", field: "shop_cover" },
    "barbers.avatar": { entityType: "barbers", field: "barber_avatar" },
    "barbers.cover": { entityType: "barbers", field: "barber_cover" },
    "services.image": { entityType: "services", field: "service_image" },
    "products.image": { entityType: "products", field: "product_image" },
    "reels.thumb": { entityType: "reels", field: "reel_thumbnail" },
    "posts.thumb": { entityType: "posts", field: "post_thumbnail" }
  };

  return (
    <PageFrame
      title="Missing Images Center"
      subtitle="Detects missing images across shops, barbers, services, products, reels, and profiles."
      actions={
        <>
          <form action={fixAllMissing}>
            <Button type="submit" size="sm">
              Fix All Missing
            </Button>
          </form>
          <Button asChild size="sm" variant="secondary">
            <Link href="/branding">Branding Center</Link>
          </Button>
        </>
      }
    >
      {errorMsg ? (
        <LuxuryCard className="mb-4 border border-rose-500/25 bg-rose-500/10 p-4 text-sm text-rose-200">{errorMsg}</LuxuryCard>
      ) : null}
      {appliedMsg ? (
        <LuxuryCard className="mb-4 border border-emerald-500/25 bg-emerald-500/10 p-4 text-sm text-emerald-200">
          Applied default: {appliedMsg}
        </LuxuryCard>
      ) : null}

      <div className="grid grid-cols-1 gap-4">
        {sections.map((s) => {
          const meta = metaBySectionId[s.id] ?? { entityType: s.rows[0]?.entity_type ?? "", field: s.rows[0]?.field ?? "" };
          return (
            <MissingSection
              key={s.id}
              title={s.title}
              sectionId={s.id}
              entityType={meta.entityType}
              field={meta.field}
              items={s.rows.map((r) => ({ id: r.id, title: r.label, subtitle: r.id, href: r.href }))}
              applyOne={applyDefault}
              applyBulkSelected={applyDefaultBulk}
              applyBulkMissing={applyDefaultsForSection}
            />
          );
        })}
      </div>
    </PageFrame>
  );
}

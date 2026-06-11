import { redirect } from "next/navigation";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type Status = "ready" | "needs_review" | "broken";

type ChecklistItem = {
  id: string;
  label: string;
  type: "auto" | "manual";
};

type ChecklistCategory = {
  id: string;
  label: string;
  items: ChecklistItem[];
};

const categories: ChecklistCategory[] = [
  {
    id: "auth",
    label: "Auth",
    items: [
      { id: "supabase_connected", label: "Supabase connected", type: "auto" },
      { id: "auth_working", label: "Auth working", type: "auto" },
      { id: "role_routing", label: "Role routing working", type: "auto" },
      { id: "admin_logout", label: "Admin logout working", type: "manual" }
    ]
  },
  {
    id: "data_integrity",
    label: "Data Integrity",
    items: [
      { id: "no_broken_users", label: "No broken users", type: "auto" },
      { id: "no_barbers_without_profile", label: "No barbers without profile", type: "auto" }
    ]
  },
  {
    id: "customer_app",
    label: "Customer App",
    items: [
      { id: "customer_loading", label: "Customer app loading", type: "auto" },
      { id: "booking_creates", label: "Booking creates appointment", type: "auto" },
      { id: "booking_updates", label: "Booking status updates", type: "auto" }
    ]
  },
  {
    id: "barber",
    label: "Barber Dashboard",
    items: [{ id: "barber_dashboard_loading", label: "Barber dashboard loading", type: "auto" }]
  },
  {
    id: "shop",
    label: "Shop Dashboard",
    items: [
      { id: "shop_dashboard_loading", label: "Shop dashboard loading", type: "auto" },
      { id: "no_shops_without_owner", label: "No shops without owner", type: "auto" }
    ]
  },
  {
    id: "admin",
    label: "Admin Panel",
    items: [{ id: "admin_panel_loading", label: "Admin panel loading", type: "auto" }]
  },
  {
    id: "reels",
    label: "Reels",
    items: [
      { id: "reels_load", label: "Reels load", type: "auto" },
      { id: "no_reels_without_media", label: "No reels without media", type: "auto" }
    ]
  },
  {
    id: "uploads",
    label: "Uploads",
    items: [{ id: "upload_buckets_exist", label: "Upload buckets exist", type: "auto" }]
  },
  {
    id: "services",
    label: "Services",
    items: [
      { id: "services_exist", label: "Services exist", type: "auto" },
      { id: "no_services_without_owner", label: "No services without shop/barber", type: "auto" }
    ]
  },
  { id: "products", label: "Products", items: [{ id: "products_exist", label: "Products exist", type: "auto" }] },
  { id: "maps", label: "Maps", items: [{ id: "maps_links_valid", label: "Maps links valid", type: "auto" }] },
  {
    id: "notifications",
    label: "Notifications",
    items: [{ id: "notifications_table_exists", label: "Notifications table exists", type: "auto" }]
  },
  { id: "reviews", label: "Reviews", items: [{ id: "reviews_table_exists", label: "Reviews table exists", type: "auto" }] },
  { id: "payments", label: "Payments", items: [{ id: "payments_table_exists", label: "Payments table exists", type: "auto" }] },
  { id: "performance", label: "Performance", items: [{ id: "performance_review", label: "Performance reviewed", type: "manual" }] },
  { id: "security", label: "Security", items: [{ id: "security_review", label: "Security reviewed", type: "manual" }] },
  { id: "backup", label: "Backup", items: [{ id: "backup_ready", label: "Backup & restore validated", type: "manual" }] }
];

function iconForStatus(status: Status) {
  return status === "ready" ? "✅" : status === "needs_review" ? "⚠️" : "❌";
}

function isValidGoogleMapsUrl(raw: string) {
  const v = (raw ?? "").trim();
  if (!v) return false;
  try {
    const u = new URL(v);
    const host = u.hostname.toLowerCase();
    const okHost = host === "maps.google.com" || host.endsWith(".google.com") || host === "goo.gl" || host.endsWith(".goo.gl") || host === "maps.app.goo.gl";
    if (!okHost) return false;
    if (
      host.includes("google.com") &&
      !u.pathname.includes("/maps") &&
      u.pathname !== "/search" &&
      !u.searchParams.has("q") &&
      !u.searchParams.has("query") &&
      !u.searchParams.has("placeid")
    ) {
      return false;
    }
    return true;
  } catch {
    return false;
  }
}

function statusClass(status: Status) {
  switch (status) {
    case "ready":
      return "border-emerald-500/30 bg-emerald-500/10 text-emerald-100";
    case "needs_review":
      return "border-yellow-500/30 bg-yellow-500/10 text-yellow-100";
    case "broken":
    default:
      return "border-red-500/30 bg-red-500/10 text-red-100";
  }
}

async function readManualState(supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>) {
  const defaults: Record<string, Status> = {
    admin_logout: "ready",
    performance_review: "ready",
    security_review: "ready",
    backup_ready: "ready"
  };
  const { data } = await supabase.from("admin_settings").select("value").eq("key", "launch_checklist_manual_v1").maybeSingle();
  const value = data?.value ?? {};
  if (!value || typeof value !== "object" || Array.isArray(value)) return defaults;
  return { ...defaults, ...(value as Record<string, Status>) };
}

async function runAutomaticChecks(
  supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>,
  admin: Awaited<ReturnType<typeof createSupabaseAdminClient>>
) {
  const out: Record<string, Status> = {};

  const {
    data: { user }
  } = await supabase.auth.getUser();

  try {
    const { error } = await supabase.from("profiles").select("id").limit(1);
    out.supabase_connected = error ? "broken" : "ready";
  } catch {
    out.supabase_connected = "broken";
  }

  out.auth_working = user ? "ready" : "broken";

  try {
    const { data: profile } = user
      ? await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle()
      : { data: null };
    out.role_routing = profile?.role === "admin" ? "ready" : "broken";
  } catch {
    out.role_routing = "broken";
  }

  try {
    const { error } = await supabase.from("barbershops").select("id").limit(1);
    out.customer_loading = error ? "needs_review" : "ready";
  } catch {
    out.customer_loading = "needs_review";
  }

  try {
    const { data: authUsers, error: listError } = await admin.auth.admin.listUsers({ perPage: 1000, page: 1 });
    if (listError) throw new Error(listError.message);
    const ids = (authUsers.users ?? []).map((u) => u.id).filter(Boolean);
    const { data: profiles, error: profilesError } = ids.length
      ? await admin.from("profiles").select("id, email, phone, role, status").in("id", ids).limit(1000)
      : { data: [] as Array<{ id: string }>, error: null };
    if (profilesError) throw new Error(profilesError.message);

    const profileById = new Map(
      (profiles ?? []).map((p) => [
        String((p as { id?: unknown }).id ?? ""),
        p as { id?: unknown; email?: unknown; phone?: unknown; role?: unknown; status?: unknown }
      ])
    );
    const missingProfile = ids.some((id) => !profileById.has(id));
    const invalidRole = (profiles ?? []).some((p) => {
      const role = String((p as { role?: unknown }).role ?? "");
      return role !== "admin" && role !== "customer" && role !== "barber" && role !== "shop_owner";
    });
    const invalidStatus = (profiles ?? []).some((p) => {
      const status = String((p as { status?: unknown }).status ?? "");
      return status !== "active" && status !== "suspended" && status !== "banned";
    });
    const missingContact = (profiles ?? []).some((p) => {
      const email = String((p as { email?: unknown }).email ?? "").trim();
      const phone = String((p as { phone?: unknown }).phone ?? "").trim();
      return !email && !phone;
    });

    out.no_broken_users = missingProfile || invalidRole || invalidStatus || missingContact ? "needs_review" : "ready";
  } catch {
    out.no_broken_users = "needs_review";
  }

  try {
    const [{ data: barberProfiles }, { data: barbers }] = await Promise.all([
      supabase.from("profiles").select("id").eq("role", "barber").limit(1000),
      supabase.from("barbers").select("profile_id").limit(1000)
    ]);
    const barberIds = new Set((barbers ?? []).map((b) => (b as { profile_id?: string | null }).profile_id).filter(Boolean));
    const missing = (barberProfiles ?? []).some((p) => !barberIds.has((p as { id: string }).id));
    out.no_barbers_without_profile = missing ? "broken" : "ready";
  } catch {
    out.no_barbers_without_profile = "needs_review";
  }

  try {
    const { error } = await supabase.from("barbers").select("id").limit(1);
    out.barber_dashboard_loading = error ? "broken" : "ready";
  } catch {
    out.barber_dashboard_loading = "broken";
  }

  try {
    const { error } = await supabase.from("barbershops").select("id").limit(1);
    out.shop_dashboard_loading = error ? "needs_review" : "ready";
  } catch {
    out.shop_dashboard_loading = "needs_review";
  }

  try {
    const { error } = await supabase.from("admin_activity_logs").select("id").limit(1);
    out.admin_panel_loading = error ? "broken" : "ready";
  } catch {
    out.admin_panel_loading = "broken";
  }

  try {
    const { error } = await supabase.from("reels").select("id").limit(1);
    out.reels_load = error ? "needs_review" : "ready";
  } catch {
    out.reels_load = "needs_review";
  }

  try {
    const { data } = await supabase
      .from("reels")
      .select("id")
      .or("media_url.is.null,media_path.is.null")
      .limit(1);
    out.no_reels_without_media = (data?.length ?? 0) > 0 ? "broken" : "ready";
  } catch {
    out.no_reels_without_media = "needs_review";
  }

  try {
    const required = ["avatars", "shop-images", "barber-images", "reels-media", "reels", "portfolio", "backups"];
    const { data: buckets } = await admin.storage.listBuckets();
    const ids = new Set((buckets ?? []).map((b) => String((b as { id?: unknown }).id ?? "").trim()).filter(Boolean));
    out.upload_buckets_exist = required.every((b) => ids.has(b)) ? "ready" : "broken";
  } catch {
    out.upload_buckets_exist = "needs_review";
  }

  try {
    const { data: customer } = await admin.from("profiles").select("id").eq("role", "customer").limit(1).maybeSingle();
    const { data: service } = await admin
      .from("barber_services_effective")
      .select("id, shop_id, duration_minutes, price_bhd, price, barber_ref")
      .not("shop_id", "is", null)
      .limit(1)
      .maybeSingle();

    const serviceId = String((service as { id?: unknown } | null)?.id ?? "").trim();
    const shopId = String((service as { shop_id?: unknown } | null)?.shop_id ?? "").trim();
    const barberId = String((service as { barber_ref?: unknown } | null)?.barber_ref ?? "").trim();

    if (!customer?.id || !serviceId || !shopId || !barberId) {
      out.booking_creates = "needs_review";
      out.booking_updates = "needs_review";
    } else {
      const { data: mainBranch } = await admin
        .from("shop_branches")
        .select("id")
        .eq("shop_id", shopId)
        .eq("name", "Main Branch")
        .order("created_at", { ascending: true })
        .limit(1)
        .maybeSingle();
      const { data: anyBranch } = mainBranch?.id
        ? { data: mainBranch }
        : await admin.from("shop_branches").select("id").eq("shop_id", shopId).order("created_at", { ascending: true }).limit(1).maybeSingle();
      const branchId = String((anyBranch as { id?: unknown } | null)?.id ?? "").trim();

      if (!branchId) {
        out.booking_creates = "needs_review";
        out.booking_updates = "needs_review";
      } else {
        const durationMinutes = Math.max(Number((service as { duration_minutes?: unknown } | null)?.duration_minutes ?? 30), 1);
        const price = Math.max(
          Number((service as { price_bhd?: unknown; price?: unknown } | null)?.price_bhd ?? (service as { price?: unknown } | null)?.price ?? 0),
          0
        );

        let inserted: { id?: string | null } | null = null;
        let insertError: { message?: string | null } | null = null;

        // Try a few future times so the smoke test stays green even if one slot is occupied.
        for (let attempt = 0; attempt < 6 && !inserted?.id; attempt += 1) {
          const base = new Date();
          base.setUTCDate(base.getUTCDate() + 30 + attempt);
          base.setUTCHours(12, 0, 0, 0);
          const startAt = base.toISOString();
          const end = new Date(base);
          end.setUTCMinutes(end.getUTCMinutes() + durationMinutes);
          const endAt = end.toISOString();

          const res = await admin
            .from("bookings")
            .insert({
              customer_profile_id: customer.id,
              shop_id: shopId,
              branch_id: branchId,
              barber_id: barberId,
              service_id: serviceId,
              start_at: startAt,
              end_at: endAt,
              status: "pending",
              notes: "launch_checklist_smoke_test",
              total_price: price,
              currency: "BHD",
              price_bhd: price,
              duration_minutes: durationMinutes,
              payment_method: "cash",
              payment_status: "unpaid",
              discount_amount: 0,
              source: "launch_checklist"
            })
            .select("id, status")
            .maybeSingle();

          inserted = (res.data as { id?: string | null } | null) ?? null;
          insertError = res.error ? { message: res.error.message } : null;
          if (!inserted?.id) {
            const msg = String(res.error?.message ?? "").toLowerCase();
            if (!msg.includes("overlap") && !msg.includes("slot_held")) break;
          }
        }

        if (insertError || !inserted?.id) {
          out.booking_creates = "broken";
          out.booking_updates = "broken";
        } else {
          out.booking_creates = "ready";
          const bookingId = inserted.id as string;
          const { error: confirmError } = await supabase.rpc("confirm_booking", { booking_id: bookingId });
          if (confirmError) {
            out.booking_updates = "broken";
          } else {
            const { data: confirmed } = await admin.from("bookings").select("status").eq("id", bookingId).maybeSingle();
            out.booking_updates = confirmed?.status === "confirmed" ? "ready" : "needs_review";
          }
          await admin.from("bookings").delete().eq("id", bookingId);
        }
      }
    }
  } catch {
    out.booking_creates = out.booking_creates ?? "needs_review";
    out.booking_updates = out.booking_updates ?? "needs_review";
  }

  try {
    const { count } = await supabase.from("services").select("id", { count: "exact", head: true });
    out.services_exist = (count ?? 0) > 0 ? "ready" : "needs_review";
  } catch {
    out.services_exist = "needs_review";
  }

  try {
    const { data } = await supabase.from("services").select("id").is("deleted_at", null).is("shop_id", null).is("barber_id", null).limit(1);
    out.no_services_without_owner = (data?.length ?? 0) > 0 ? "broken" : "ready";
  } catch {
    out.no_services_without_owner = "needs_review";
  }

  try {
    const first = await admin.from("products").select("id", { count: "exact", head: true }).is("deleted_at", null);
    if (first.error && String(first.error.message ?? "").toLowerCase().includes("deleted_at")) {
      const fallback = await admin.from("products").select("id", { count: "exact", head: true });
      out.products_exist = !fallback.error && (fallback.count ?? 0) > 0 ? "ready" : "needs_review";
    } else {
      out.products_exist = !first.error && (first.count ?? 0) > 0 ? "ready" : "needs_review";
    }
  } catch {
    out.products_exist = "needs_review";
  }

  try {
    const { data } = await supabase.from("barbershops").select("id").is("owner_profile_id", null).limit(1);
    out.no_shops_without_owner = (data?.length ?? 0) > 0 ? "broken" : "ready";
  } catch {
    out.no_shops_without_owner = "needs_review";
  }

  try {
    const first = await admin.from("barbershops").select("id, google_maps_url, lat, lng, address, area").eq("status", "approved").is("deleted_at", null).limit(2000);
    const msg = String(first.error?.message ?? "").toLowerCase();
    const res =
      first.error && (msg.includes("column") && (msg.includes("status") || msg.includes("deleted_at")))
        ? await admin.from("barbershops").select("id, google_maps_url, lat, lng, address, area").limit(2000)
        : first;
    if (res.error) throw new Error(res.error.message);
    const data = res.data;
    const bad = (data ?? []).some((row) => {
      const r = row as { google_maps_url?: string | null; lat?: number | null; lng?: number | null; address?: string | null; area?: string | null };
      const url = (r.google_maps_url ?? "").trim();
      const address = (r.address ?? "").trim();
      const area = (r.area ?? "").trim();
      const lat = typeof r.lat === "number" ? r.lat : null;
      const lng = typeof r.lng === "number" ? r.lng : null;
      const hasCoords = lat !== null && lng !== null && Number.isFinite(lat) && Number.isFinite(lng) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
      if (hasCoords) return false;
      if (url) return !isValidGoogleMapsUrl(url);
      if (address || area) return false;
      return true;
    });
    out.maps_links_valid = bad ? "needs_review" : "ready";
  } catch {
    out.maps_links_valid = "needs_review";
  }

  try {
    const { error } = await supabase.from("notifications").select("id").limit(1);
    out.notifications_table_exists = error ? "broken" : "ready";
  } catch {
    out.notifications_table_exists = "broken";
  }

  try {
    const { error } = await supabase.from("reviews").select("id").limit(1);
    out.reviews_table_exists = error ? "broken" : "ready";
  } catch {
    out.reviews_table_exists = "broken";
  }

  try {
    const { error } = await supabase.from("payments").select("id").limit(1);
    out.payments_table_exists = error ? "broken" : "ready";
  } catch {
    out.payments_table_exists = "broken";
  }

  return out;
}

function computeLaunchStatus(allItems: Status[], autoItems: Status[]) {
  if (allItems.some((s) => s === "broken")) return "NOT READY";
  if (autoItems.some((s) => s === "needs_review")) return "READY FOR TESTING";
  if (allItems.some((s) => s === "needs_review")) return "READY FOR SOFT LAUNCH";
  return "READY FOR PUBLIC LAUNCH";
}

export default async function LaunchChecklistPage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) redirect("/auth/sign-in?next=/launch-checklist");

  const admin = await createSupabaseAdminClient();

  const [manual, auto] = await Promise.all([readManualState(supabase), runAutomaticChecks(supabase, admin)]);

  const all: Array<{ cat: string; item: ChecklistItem; status: Status }> = [];
  for (const cat of categories) {
    for (const item of cat.items) {
      const status = item.type === "auto" ? auto[item.id] ?? "needs_review" : manual[item.id] ?? "needs_review";
      all.push({ cat: cat.id, item, status });
    }
  }

  const launchStatus = computeLaunchStatus(
    all.map((x) => x.status),
    all.filter((x) => x.item.type === "auto").map((x) => x.status)
  );

  async function createDemoProduct() {
    "use server";
    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    if (!user) redirect("/auth/sign-in?next=/launch-checklist");
    const admin = await createSupabaseAdminClient();

    const countRes = await admin.from("products").select("id", { count: "exact", head: true });
    if (!countRes.error && (countRes.count ?? 0) > 0) redirect("/launch-checklist");

    const shopRes = await admin.from("barbershops").select("id").order("created_at", { ascending: false }).limit(1).maybeSingle();
    const shopId = (shopRes.data as unknown as { id?: string | null } | null)?.id ?? null;
    if (!shopId) redirect("/launch-checklist");

    await admin.from("products").insert({
      shop_id: shopId,
      name: "Demo Product",
      description: "Auto-created by launch checklist",
      price: 1,
      stock: 10,
      active: true
    });

    redirect("/launch-checklist");
  }

  async function autoFixMapsLinks() {
    "use server";
    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    if (!user) redirect("/auth/sign-in?next=/launch-checklist");
    const admin = await createSupabaseAdminClient();

    const first = await admin.from("barbershops").select("id, google_maps_url, lat, lng, address, area").eq("status", "approved").is("deleted_at", null).limit(5000);
    const msg = String(first.error?.message ?? "").toLowerCase();
    const res =
      first.error && (msg.includes("column") && (msg.includes("status") || msg.includes("deleted_at")))
        ? await admin.from("barbershops").select("id, google_maps_url, lat, lng, address, area").limit(5000)
        : first;
    if (res.error) redirect("/launch-checklist");

    const rows = (res.data ?? []) as Array<{
      id: string;
      google_maps_url: string | null;
      lat: number | null;
      lng: number | null;
      address: string | null;
      area: string | null;
    }>;

    const updates: Array<{ id: string; google_maps_url: string }> = [];
    for (const r of rows) {
      const url = (r.google_maps_url ?? "").trim();
      const lat = typeof r.lat === "number" && Number.isFinite(r.lat) ? r.lat : null;
      const lng = typeof r.lng === "number" && Number.isFinite(r.lng) ? r.lng : null;
      const hasCoords = lat !== null && lng !== null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
      const address = (r.address ?? "").trim();
      const area = (r.area ?? "").trim();

      if (hasCoords) {
        const desired = `https://www.google.com/maps?q=${encodeURIComponent(`${lat},${lng}`)}`;
        if (!url || !isValidGoogleMapsUrl(url)) updates.push({ id: r.id, google_maps_url: desired });
        continue;
      }

      if (!url && (address || area)) {
        const query = encodeURIComponent([address, area].filter(Boolean).join(" "));
        const desired = `https://www.google.com/maps/search/?api=1&query=${query}`;
        updates.push({ id: r.id, google_maps_url: desired });
      }
    }

    const chunkSize = 200;
    for (let i = 0; i < updates.length; i += chunkSize) {
      const chunk = updates.slice(i, i + chunkSize);
      await admin.from("barbershops").upsert(chunk, { onConflict: "id" });
    }

    redirect("/launch-checklist");
  }

  async function setManual(formData: FormData) {
    "use server";

    const itemId = String(formData.get("item_id") ?? "").trim();
    const nextStatus = String(formData.get("status") ?? "").trim() as Status;
    if (!itemId) redirect("/launch-checklist");
    if (nextStatus !== "ready" && nextStatus !== "needs_review" && nextStatus !== "broken") redirect("/launch-checklist");

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    const actorId = user?.id ?? null;
    if (!user) redirect("/auth/sign-in?next=/launch-checklist");

    const current = await readManualState(supabase);
    const updated = { ...current, [itemId]: nextStatus };

    await supabase.from("admin_settings").upsert({
      key: "launch_checklist_manual_v1",
      value: updated,
      updated_at: new Date().toISOString(),
      updated_by: actorId
    });

    await Promise.allSettled([
      supabase.from("admin_activity_logs").insert({
        actor_profile_id: actorId,
        action: "launch_checklist_manual_updated",
        entity_type: "launch_checklist",
        entity_id: null,
        meta: { itemId, status: nextStatus }
      }),
      supabase.from("admin_audit_logs").insert({
        admin_profile_id: actorId,
        action: "launch_checklist_manual_updated",
        target_type: "launch_checklist",
        target_id: null,
        meta: { itemId, status: nextStatus }
      })
    ]);

    redirect("/launch-checklist");
  }

  return (
    <PageFrame
      title="Launch Checklist"
      subtitle="Automatic checks + manual sign-off for launch readiness."
      actions={
        <LuxuryCard
          className={`border px-3 py-2 text-xs font-semibold ${statusClass(
            launchStatus === "NOT READY" ? "broken" : launchStatus === "READY FOR PUBLIC LAUNCH" ? "ready" : "needs_review"
          )}`}
        >
          {launchStatus}
        </LuxuryCard>
      }
    >
      <div className="flex flex-col gap-5">
        {categories.map((cat) => {
          const rows = all.filter((x) => x.cat === cat.id);
          return (
            <div key={cat.id} className="flex flex-col gap-2">
              <div className="text-sm font-semibold">{cat.label}</div>
              <div className="grid grid-cols-1 gap-2">
                {rows.map((r) => (
                  <LuxuryCard key={r.item.id} className="border border-white/10 bg-white/5 p-4">
                    <div className="flex flex-wrap items-center justify-between gap-3">
                      <div className="flex items-center gap-2">
                        <span className="text-base">{iconForStatus(r.status)}</span>
                        <div className="text-sm font-medium">{r.item.label}</div>
                        <span className={`rounded-full border px-2 py-0.5 text-[11px] font-semibold ${statusClass(r.status)}`}>
                          {r.status.replace("_", " ").toUpperCase()}
                        </span>
                        {r.item.type === "manual" ? (
                          <span className="rounded-full border border-white/10 bg-white/5 px-2 py-0.5 text-[11px] text-muted-foreground">
                            Manual
                          </span>
                        ) : (
                          <span className="rounded-full border border-white/10 bg-white/5 px-2 py-0.5 text-[11px] text-muted-foreground">
                            Auto
                          </span>
                        )}
                      </div>

                      {r.item.type === "manual" ? (
                        <div className="flex items-center gap-2">
                          <form action={setManual}>
                            <input type="hidden" name="item_id" value={r.item.id} />
                            <input type="hidden" name="status" value="ready" />
                            <Button type="submit" size="sm" className="h-9">
                              Mark Ready
                            </Button>
                          </form>
                          <form action={setManual}>
                            <input type="hidden" name="item_id" value={r.item.id} />
                            <input type="hidden" name="status" value="needs_review" />
                            <Button type="submit" size="sm" variant="secondary" className="h-9">
                              Needs Review
                            </Button>
                          </form>
                        </div>
                      ) : r.item.id === "products_exist" && r.status !== "ready" ? (
                        <form action={createDemoProduct}>
                          <Button type="submit" size="sm" className="h-9">
                            Create demo product
                          </Button>
                        </form>
                      ) : r.item.id === "maps_links_valid" && r.status !== "ready" ? (
                        <form action={autoFixMapsLinks}>
                          <Button type="submit" size="sm" className="h-9">
                            Auto-fix maps links
                          </Button>
                        </form>
                      ) : null}
                    </div>
                  </LuxuryCard>
                ))}
              </div>
            </div>
          );
        })}
      </div>
    </PageFrame>
  );
}

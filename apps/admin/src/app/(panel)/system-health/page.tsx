import Link from "next/link";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { checkSupabaseConnection } from "@hallaq/supabase/health";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

import {
  fixCreateMissingProfile,
  fixDeactivateService,
  fixHideReel,
  fixMarkBarberIndependent,
  fixAssignRole,
  fixAssignShopOwner,
  fixReconnectServiceToShop,
  fixReconnectBookingToCustomer,
  runRefreshCache,
  runRebuildCounts
} from "./actions";
import { SystemHealthClient } from "./system-health-client";

export const dynamic = "force-dynamic";

type CardStatus = "ok" | "warning" | "broken";

function icon(status: CardStatus) {
  if (status === "ok") return "✅";
  if (status === "warning") return "⚠️";
  return "❌";
}

function tone(status: CardStatus) {
  if (status === "ok") return "text-emerald-200";
  if (status === "warning") return "text-amber-200";
  return "text-rose-200";
}

export default async function SystemHealthPage() {
  const supabase = await createSupabaseServerClient();
  const { data: authData } = await supabase.auth.getUser();
  const userId = authData.user?.id ?? null;

  const [connection, profileRes] = await Promise.all([
    checkSupabaseConnection(),
    userId ? supabase.from("profiles").select("role").eq("id", userId).maybeSingle() : Promise.resolve({ data: null, error: null })
  ]);

  const supabaseOk = connection.ok;
  const reason = connection.ok ? undefined : connection.reason;

  const role = profileRes.data?.role ?? null;
  const authOk = Boolean(userId);
  const adminOk = role === "admin";

  let adminClientReady = false;
  try {
    await createSupabaseAdminClient();
    adminClientReady = true;
  } catch {
    adminClientReady = false;
  }

  const tableChecks = await Promise.all([
    supabase.from("profiles").select("id", { count: "exact", head: true }).limit(1),
    supabase.from("barbershops").select("id", { count: "exact", head: true }).limit(1),
    supabase.from("barbers").select("id", { count: "exact", head: true }).limit(1),
    supabase.from("services").select("id", { count: "exact", head: true }).limit(1),
    supabase.from("products").select("id", { count: "exact", head: true }).limit(1),
    supabase.from("bookings").select("id", { count: "exact", head: true }).limit(1),
    supabase.from("reels").select("id", { count: "exact", head: true }).limit(1),
    supabase.from("reviews").select("id", { count: "exact", head: true }).limit(1),
    supabase.from("follows").select("id", { count: "exact", head: true }).limit(1),
    supabase.from("notifications").select("id", { count: "exact", head: true }).limit(1)
  ]);

  const [
    profilesCheck,
    shopsCheck,
    barbersCheck,
    servicesCheck,
    productsCheck,
    bookingsCheck,
    reelsCheck,
    reviewsCheck,
    followsCheck,
    notificationsCheck
  ] = tableChecks;

  const cards: Array<{ id: string; title: string; status: CardStatus; detail?: string }> = [
    {
      id: "supabase",
      title: "Supabase Connection",
      status: supabaseOk ? "ok" : "broken",
      detail: supabaseOk ? "OK" : reason
    },
    {
      id: "auth",
      title: "Auth Status",
      status: authOk ? "ok" : "broken",
      detail: authOk ? userId ?? "OK" : "No active session"
    },
    {
      id: "profiles",
      title: "Profiles Table",
      status: profilesCheck.error ? "broken" : "ok",
      detail: profilesCheck.error?.message
    },
    {
      id: "role-routing",
      title: "Role Routing",
      status: adminOk ? "ok" : "warning",
      detail: adminOk ? "Admin session" : `Role: ${role ?? "unknown"}`
    },
    { id: "shops", title: "Shops Table", status: shopsCheck.error ? "broken" : "ok", detail: shopsCheck.error?.message },
    { id: "barbers", title: "Barbers Table", status: barbersCheck.error ? "broken" : "ok", detail: barbersCheck.error?.message },
    { id: "services", title: "Services Table", status: servicesCheck.error ? "broken" : "ok", detail: servicesCheck.error?.message },
    { id: "products", title: "Products Table", status: productsCheck.error ? "broken" : "ok", detail: productsCheck.error?.message },
    { id: "bookings", title: "Bookings Table", status: bookingsCheck.error ? "broken" : "ok", detail: bookingsCheck.error?.message },
    { id: "reels", title: "Reels / Posts Table", status: reelsCheck.error ? "broken" : "ok", detail: reelsCheck.error?.message },
    { id: "reviews", title: "Reviews Table", status: reviewsCheck.error ? "broken" : "ok", detail: reviewsCheck.error?.message },
    { id: "follows", title: "Follows Table", status: followsCheck.error ? "broken" : "ok", detail: followsCheck.error?.message },
    { id: "notifications", title: "Notifications Table", status: notificationsCheck.error ? "broken" : "ok", detail: notificationsCheck.error?.message },
    { id: "storage", title: "Storage Buckets", status: adminClientReady ? "ok" : "warning", detail: adminClientReady ? "Service role available" : "Service role missing" },
    { id: "upload", title: "Upload System", status: adminClientReady ? "ok" : "warning", detail: adminClientReady ? "Use Full System Test upload check" : "Service role missing" },
    { id: "rls", title: "RLS Policies", status: adminOk ? "ok" : "warning", detail: "Use tests below for behavioral validation" },
    { id: "realtime", title: "Realtime Channels", status: "warning", detail: "See realtime section" },
    { id: "performance", title: "Performance Health", status: "warning", detail: "See performance section" },
    { id: "relationships", title: "Database Relationships", status: "ok", detail: "Broken data detector checks key FK assumptions" },
    { id: "routes", title: "App Routes", status: "ok", detail: "Route guards covered by middleware in each app" },
    { id: "logs", title: "Error Logs", status: "ok", detail: "system_logs" }
  ];

  const brokenBarbers = await supabase
    .from("barbers")
    .select("id, display_name, profile_id, shop_id, is_independent")
    .is("deleted_at", null)
    .is("shop_id", null)
    .eq("is_independent", false)
    .limit(15);

  const orphanServices = await supabase
    .from("services")
    .select("id, name_en, name_ar, shop_id, barber_id")
    .is("deleted_at", null)
    .is("shop_id", null)
    .is("barber_id", null)
    .limit(15);

  const bookingsNoService = await supabase
    .from("bookings")
    .select("id, customer_profile_id, shop_id, barber_id, start_at, status, service_id")
    .is("service_id", null)
    .limit(15);

  const reelsNoMedia = await supabase
    .from("reels")
    .select("id, caption, media_url, image_url, video_url, status")
    .is("deleted_at", null)
    .is("media_url", null)
    .is("image_url", null)
    .is("video_url", null)
    .limit(15);

  const barbersNoProfile = await supabase
    .from("barbers")
    .select("id, display_name, profile_id")
    .is("profile_id", null)
    .limit(15);

  const shopsNoOwner = await supabase
    .from("barbershops")
    .select("id, name, owner_profile_id")
    .is("owner_profile_id", null)
    .limit(15);

  const shopOwners = await supabase
    .from("profiles")
    .select("id, full_name, email")
    .eq("role", "shop_owner")
    .limit(200);
  const shopOwnerIds = (shopOwners.data ?? []).map((p) => p.id);
  const shopsForOwners = shopOwnerIds.length
    ? await supabase.from("barbershops").select("id, owner_profile_id").in("owner_profile_id", shopOwnerIds).limit(500)
    : { data: [] as Array<{ id: string; owner_profile_id: string }>, error: null as { message: string } | null };
  const ownerHasShop = new Set((shopsForOwners.data ?? []).map((s) => s.owner_profile_id));
  const shopOwnersWithoutShop = (shopOwners.data ?? []).filter((p) => !ownerHasShop.has(p.id)).slice(0, 15);

  const invalidRoles = await supabase
    .from("profiles")
    .select("id, full_name, role")
    .not("role", "in", '("customer","barber","shop_owner","admin")')
    .limit(15);

  const usersNoRole = await supabase.from("profiles").select("id, full_name, email, role").is("role", null).limit(15);

  const bookingsNoCustomer = await supabase
    .from("bookings")
    .select("id, customer_profile_id, service_id, shop_id, barber_id, status")
    .is("customer_profile_id", null)
    .limit(15);

  const productsNoShop = await supabase.from("products").select("id, name, shop_id").is("shop_id", null).limit(15);

  const reviewsNoCustomer = await supabase
    .from("reviews")
    .select("id, customer_profile_id, target_type, target_id, rating, status")
    .is("customer_profile_id", null)
    .limit(15);

  let systemLogs: Array<Record<string, unknown>> = [];
  let auditLogs: Array<Record<string, unknown>> = [];
  const systemLogsRes = await supabase
    .from("system_logs")
    .select("id,user_id,role,page,action,error_message,severity,created_at")
    .order("created_at", { ascending: false })
    .limit(20);
  if (!systemLogsRes.error) systemLogs = systemLogsRes.data ?? [];

  const auditLogsRes = await supabase
    .from("admin_audit_logs")
    .select("id,admin_profile_id,action,target_type,target_id,created_at")
    .order("created_at", { ascending: false })
    .limit(20);
  if (!auditLogsRes.error) auditLogs = auditLogsRes.data ?? [];

  const storageBuckets = [
    "avatars",
    "shop-images",
    "barber-images",
    "service-images",
    "product-images",
    "portfolio",
    "reels",
    "offer-images",
    "awards"
  ];

  let bucketStatus: Array<{ bucket: string; status: CardStatus; detail?: string }> = [];
  let referencedMediaStatus: Array<{ label: string; status: CardStatus; detail?: string }> = [];
  if (adminClientReady) {
    try {
      const admin = await createSupabaseAdminClient();
      bucketStatus = await Promise.all(
        storageBuckets.map(async (bucket) => {
          const { data, error } = await admin.storage.getBucket(bucket);
          if (error) return { bucket, status: "broken" as const, detail: error.message };
          return { bucket, status: "ok" as const, detail: data.public ? "public" : "private" };
        })
      );

      const isHttp = (v: string) => v.startsWith("http://") || v.startsWith("https://");
      const uniq = (arr: string[]) => Array.from(new Set(arr));
      const sample = (arr: string[], n: number) => arr.slice(0, n);

      const collectPaths = async (query: PromiseLike<{ data: unknown; error: unknown }>, keys: string[]) => {
        const res = await query;
        const e = res as unknown as { error?: { message?: string } | null };
        if (e.error) return { paths: [] as string[], error: e.error.message ?? "query_failed" };
        const rows = ((res as unknown as { data?: unknown[] }).data ?? []) as Array<Record<string, unknown>>;
        const out: string[] = [];
        for (const r of rows) {
          for (const k of keys) {
            const v = String(r[k] ?? "").trim();
            if (v && !isHttp(v)) out.push(v);
          }
        }
        return { paths: uniq(out), error: null as string | null };
      };

      const checkBucketRefs = async (label: string, bucket: string, paths: string[], err: string | null) => {
        if (err) return { label, status: "warning" as const, detail: err };
        const refs = sample(paths, 15);
        if (!refs.length) return { label, status: "ok" as const, detail: "No referenced paths" };
        let ok = 0;
        for (const p of refs) {
          const { data, error } = await admin.storage.from(bucket).createSignedUrl(p, 60);
          if (!error && data?.signedUrl) ok += 1;
        }
        const status: CardStatus = ok === refs.length ? "ok" : ok > 0 ? "warning" : "broken";
        return { label, status, detail: `${ok}/${refs.length} signed` };
      };

      const shopRefs = await collectPaths(
        admin.from("barbershops").select("logo_path, cover_path").limit(200),
        ["logo_path", "cover_path"]
      );
      const barberRefs = await collectPaths(
        admin.from("barbers").select("avatar_path, cover_path").limit(200),
        ["avatar_path", "cover_path"]
      );
      const portfolioRefs = await collectPaths(
        admin.from("portfolio_items").select("media_path, thumbnail_path").limit(200),
        ["media_path", "thumbnail_path"]
      );
      const reelsRefs = await collectPaths(
        admin.from("reels").select("media_path, thumbnail_path").limit(200),
        ["media_path", "thumbnail_path"]
      );
      const productRefs = await collectPaths(
        admin.from("product_images").select("storage_path, thumbnail_path").limit(200),
        ["storage_path", "thumbnail_path"]
      );

      referencedMediaStatus = [
        await checkBucketRefs("Shop media refs", "shop-images", shopRefs.paths, shopRefs.error),
        await checkBucketRefs("Barber media refs", "barber-images", barberRefs.paths, barberRefs.error),
        await checkBucketRefs("Portfolio media refs", "portfolio", portfolioRefs.paths, portfolioRefs.error),
        await checkBucketRefs("Reels media refs", "reels-media", reelsRefs.paths, reelsRefs.error),
        await checkBucketRefs("Product media refs", "products", productRefs.paths, productRefs.error)
      ];
    } catch {
      bucketStatus = storageBuckets.map((bucket) => ({ bucket, status: "warning" as const, detail: "Service role client failed" }));
      referencedMediaStatus = [{ label: "Referenced media paths", status: "warning", detail: "Service role client failed" }];
    }
  } else {
    bucketStatus = storageBuckets.map((bucket) => ({ bucket, status: "warning" as const, detail: "Service role missing" }));
    referencedMediaStatus = [{ label: "Referenced media paths", status: "warning", detail: "Service role missing" }];
  }

  async function measure<T>(label: string, run: () => PromiseLike<{ error: unknown } & T>) {
    const start = typeof performance !== "undefined" ? performance.now() : Date.now();
    const res = await run();
    const end = typeof performance !== "undefined" ? performance.now() : Date.now();
    const err = (res as unknown as { error?: { message?: string } | null }).error;
    const errorMessage = typeof err?.message === "string" ? err.message : null;
    return { label, ms: Math.round(end - start), error: errorMessage };
  }

  const performanceChecks = await Promise.all([
    measure("Home query time (shops)", () =>
      supabase.from("barbershops").select("id").is("deleted_at", null).limit(20)
    ),
    measure("Discover query time (reels)", () =>
      supabase.from("reels").select("id").is("deleted_at", null).limit(20)
    ),
    measure("Bookings query time", () => supabase.from("bookings").select("id").limit(20)),
    measure("Profile query time", () => (userId ? supabase.from("profiles").select("id").eq("id", userId).limit(1) : supabase.from("profiles").select("id").limit(1)))
  ]);

  {
    const maxMs = Math.max(0, ...performanceChecks.map((x) => x.ms));
    const anyError = performanceChecks.some((x) => Boolean(x.error));
    const perfStatus: CardStatus = anyError ? "broken" : maxMs <= 800 ? "ok" : "warning";
    const perfDetail = anyError
      ? performanceChecks.find((x) => x.error)?.error ?? "Query failed"
      : `${maxMs}ms worst of ${performanceChecks.length} checks`;
    const perfCard = cards.find((c) => c.id === "performance");
    if (perfCard) {
      perfCard.status = perfStatus;
      perfCard.detail = perfDetail;
    }
  }

  return (
    <PageFrame
      title="System Health"
      subtitle="Admin-only diagnostics, broken data detector, and fix tools."
      actions={
        <div className="flex items-center gap-2">
          <Button asChild variant="ghost" size="sm">
            <Link href="/diagnostics">Diagnostics</Link>
          </Button>
          <Button asChild variant="ghost" size="sm">
            <Link href="/health">Health</Link>
          </Button>
          <Button asChild variant="secondary" size="sm">
            <Link href="/system-health">Refresh</Link>
          </Button>
        </div>
      }
    >
      <SystemHealthClient />

      <div className="pt-6" id="dashboard">
        <LuxuryCard className="p-5">
          <div className="flex flex-col gap-4">
            <div>
              <div className="text-sm font-semibold">Main System Health Dashboard</div>
              <div className="text-xs text-muted-foreground">Click any card to jump to details.</div>
            </div>
            <div className="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-4">
              {cards.map((c) => (
                <Link
                  key={c.id}
                  href={`#${c.id}`}
                  className="rounded-xl border border-white/10 bg-white/5 p-4 transition hover:border-white/20 hover:bg-white/10"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="text-sm font-medium">{c.title}</div>
                    <div className={`text-xs ${tone(c.status)}`}>
                      {icon(c.status)} {c.status.toUpperCase()}
                    </div>
                  </div>
                  {c.detail ? <div className="pt-2 text-xs text-muted-foreground break-all">{c.detail}</div> : null}
                </Link>
              ))}
            </div>
          </div>
        </LuxuryCard>
      </div>

      <div className="pt-6" id="broken-data">
        <LuxuryCard className="p-5">
          <div className="flex flex-col gap-4">
            <div>
              <div className="text-sm font-semibold">Broken Data</div>
              <div className="text-xs text-muted-foreground">Detected inconsistencies that usually break flows.</div>
            </div>

            <div className="grid grid-cols-1 gap-4 xl:grid-cols-2">
              <LuxuryCard className="p-4">
                <div className="flex items-center justify-between gap-3">
                  <div className="text-sm font-semibold">Barbers without profile</div>
                  <div className="text-xs text-muted-foreground">{barbersNoProfile.data?.length ?? 0}</div>
                </div>
                {barbersNoProfile.error ? (
                  <div className="pt-2 text-xs text-rose-200">{barbersNoProfile.error.message}</div>
                ) : barbersNoProfile.data?.length ? (
                  <div className="pt-3 grid gap-2">
                    {barbersNoProfile.data.map((b) => (
                      <div key={b.id} className="flex items-center justify-between gap-3 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm">
                        <div className="min-w-0">
                          <div className="truncate">{b.display_name || b.id}</div>
                          <div className="text-xs text-muted-foreground break-all">ID: {b.id}</div>
                        </div>
                        <Button asChild size="sm" variant="ghost">
                          <Link href={`/data/barbers?id=${encodeURIComponent(b.id)}`}>Inspect</Link>
                        </Button>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="pt-2 text-xs text-muted-foreground">No issues detected.</div>
                )}
              </LuxuryCard>

              <LuxuryCard className="p-4">
                <div className="flex items-center justify-between gap-3">
                  <div className="text-sm font-semibold">Barbers without shop and not independent</div>
                  <div className="text-xs text-muted-foreground">{brokenBarbers.data?.length ?? 0}</div>
                </div>
                {brokenBarbers.error ? (
                  <div className="pt-2 text-xs text-rose-200">{brokenBarbers.error.message}</div>
                ) : brokenBarbers.data?.length ? (
                  <div className="pt-3 grid gap-2">
                    {brokenBarbers.data.map((b) => (
                      <div key={b.id} className="flex items-center justify-between gap-3 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm">
                        <div className="min-w-0">
                          <div className="truncate">{b.display_name || b.id}</div>
                          <div className="text-xs text-muted-foreground break-all">ID: {b.id}</div>
                        </div>
                        <form action={fixMarkBarberIndependent} className="shrink-0">
                          <input type="hidden" name="barberId" value={b.id} />
                          <Button type="submit" size="sm" variant="secondary">
                            Mark independent
                          </Button>
                        </form>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="pt-2 text-xs text-muted-foreground">No issues detected.</div>
                )}
              </LuxuryCard>

              <LuxuryCard className="p-4">
                <div className="flex items-center justify-between gap-3">
                  <div className="text-sm font-semibold">Shops without owner</div>
                  <div className="text-xs text-muted-foreground">{shopsNoOwner.data?.length ?? 0}</div>
                </div>
                {shopsNoOwner.error ? (
                  <div className="pt-2 text-xs text-rose-200">{shopsNoOwner.error.message}</div>
                ) : shopsNoOwner.data?.length ? (
                  <div className="pt-3 grid gap-2">
                    {shopsNoOwner.data.map((s) => (
                      <div key={s.id} className="flex items-center justify-between gap-3 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm">
                        <div className="min-w-0">
                          <div className="truncate">{s.name || s.id}</div>
                          <div className="text-xs text-muted-foreground break-all">ID: {s.id}</div>
                        </div>
                        <Button asChild size="sm" variant="ghost">
                          <Link href={`/data/barbershops?id=${encodeURIComponent(s.id)}`}>Inspect</Link>
                        </Button>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="pt-2 text-xs text-muted-foreground">No issues detected.</div>
                )}
              </LuxuryCard>

              <LuxuryCard className="p-4">
                <div className="flex items-center justify-between gap-3">
                  <div className="text-sm font-semibold">Services without owner</div>
                  <div className="text-xs text-muted-foreground">{orphanServices.data?.length ?? 0}</div>
                </div>
                {orphanServices.error ? (
                  <div className="pt-2 text-xs text-rose-200">{orphanServices.error.message}</div>
                ) : orphanServices.data?.length ? (
                  <div className="pt-3 grid gap-2">
                    {orphanServices.data.map((s) => (
                      <div key={s.id} className="flex items-center justify-between gap-3 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm">
                        <div className="min-w-0">
                          <div className="truncate">{s.name_en || s.name_ar || s.id}</div>
                          <div className="text-xs text-muted-foreground break-all">ID: {s.id}</div>
                        </div>
                        <form action={fixDeactivateService} className="shrink-0">
                          <input type="hidden" name="serviceId" value={s.id} />
                          <Button type="submit" size="sm" variant="secondary">
                            Deactivate
                          </Button>
                        </form>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="pt-2 text-xs text-muted-foreground">No issues detected.</div>
                )}
              </LuxuryCard>

              <LuxuryCard className="p-4">
                <div className="flex items-center justify-between gap-3">
                  <div className="text-sm font-semibold">Bookings without service</div>
                  <div className="text-xs text-muted-foreground">{bookingsNoService.data?.length ?? 0}</div>
                </div>
                {bookingsNoService.error ? (
                  <div className="pt-2 text-xs text-rose-200">{bookingsNoService.error.message}</div>
                ) : bookingsNoService.data?.length ? (
                  <div className="pt-3 grid gap-2">
                    {bookingsNoService.data.map((b) => (
                      <div key={b.id} className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm">
                        <div className="flex items-center justify-between gap-3">
                          <div className="min-w-0">
                            <div className="truncate">{b.id}</div>
                            <div className="text-xs text-muted-foreground break-all">Customer: {b.customer_profile_id}</div>
                          </div>
                          <Button asChild size="sm" variant="ghost">
                            <Link href={`/appointments?bookingId=${b.id}`}>Inspect</Link>
                          </Button>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="pt-2 text-xs text-muted-foreground">No issues detected.</div>
                )}
              </LuxuryCard>

              <LuxuryCard className="p-4">
                <div className="flex items-center justify-between gap-3">
                  <div className="text-sm font-semibold">Bookings without customer</div>
                  <div className="text-xs text-muted-foreground">{bookingsNoCustomer.data?.length ?? 0}</div>
                </div>
                {bookingsNoCustomer.error ? (
                  <div className="pt-2 text-xs text-rose-200">{bookingsNoCustomer.error.message}</div>
                ) : bookingsNoCustomer.data?.length ? (
                  <div className="pt-3 grid gap-2">
                    {bookingsNoCustomer.data.map((b) => (
                      <div key={b.id} className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm">
                        <div className="flex items-center justify-between gap-3">
                          <div className="min-w-0">
                            <div className="truncate">{b.id}</div>
                            <div className="text-xs text-muted-foreground break-all">Service: {String(b.service_id ?? "")}</div>
                          </div>
                          <Button asChild size="sm" variant="ghost">
                            <Link href={`/data/bookings?id=${encodeURIComponent(b.id)}`}>Inspect</Link>
                          </Button>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="pt-2 text-xs text-muted-foreground">No issues detected.</div>
                )}
              </LuxuryCard>

              <LuxuryCard className="p-4">
                <div className="flex items-center justify-between gap-3">
                  <div className="text-sm font-semibold">Reels without media</div>
                  <div className="text-xs text-muted-foreground">{reelsNoMedia.data?.length ?? 0}</div>
                </div>
                {reelsNoMedia.error ? (
                  <div className="pt-2 text-xs text-rose-200">{reelsNoMedia.error.message}</div>
                ) : reelsNoMedia.data?.length ? (
                  <div className="pt-3 grid gap-2">
                    {reelsNoMedia.data.map((r) => (
                      <div key={r.id} className="flex items-center justify-between gap-3 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm">
                        <div className="min-w-0">
                          <div className="truncate">{r.caption || r.id}</div>
                          <div className="text-xs text-muted-foreground break-all">ID: {r.id}</div>
                        </div>
                        <form action={fixHideReel} className="shrink-0">
                          <input type="hidden" name="reelId" value={r.id} />
                          <Button type="submit" size="sm" variant="secondary">
                            Hide
                          </Button>
                        </form>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="pt-2 text-xs text-muted-foreground">No issues detected.</div>
                )}
              </LuxuryCard>

              <LuxuryCard className="p-4">
                <div className="flex items-center justify-between gap-3">
                  <div className="text-sm font-semibold">Products without shop</div>
                  <div className="text-xs text-muted-foreground">{productsNoShop.data?.length ?? 0}</div>
                </div>
                {productsNoShop.error ? (
                  <div className="pt-2 text-xs text-rose-200">{productsNoShop.error.message}</div>
                ) : productsNoShop.data?.length ? (
                  <div className="pt-3 grid gap-2">
                    {productsNoShop.data.map((p) => (
                      <div key={p.id} className="flex items-center justify-between gap-3 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm">
                        <div className="min-w-0">
                          <div className="truncate">{p.name || p.id}</div>
                          <div className="text-xs text-muted-foreground break-all">ID: {p.id}</div>
                        </div>
                        <Button asChild size="sm" variant="ghost">
                          <Link href={`/data/products?id=${encodeURIComponent(p.id)}`}>Inspect</Link>
                        </Button>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="pt-2 text-xs text-muted-foreground">No issues detected.</div>
                )}
              </LuxuryCard>

              <LuxuryCard className="p-4">
                <div className="flex items-center justify-between gap-3">
                  <div className="text-sm font-semibold">Reviews without customer</div>
                  <div className="text-xs text-muted-foreground">{reviewsNoCustomer.data?.length ?? 0}</div>
                </div>
                {reviewsNoCustomer.error ? (
                  <div className="pt-2 text-xs text-rose-200">{reviewsNoCustomer.error.message}</div>
                ) : reviewsNoCustomer.data?.length ? (
                  <div className="pt-3 grid gap-2">
                    {reviewsNoCustomer.data.map((r) => (
                      <div key={r.id} className="flex items-center justify-between gap-3 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm">
                        <div className="min-w-0">
                          <div className="truncate">{r.id}</div>
                          <div className="text-xs text-muted-foreground break-all">{String(r.target_type ?? "")}:{String(r.target_id ?? "")}</div>
                        </div>
                        <Button asChild size="sm" variant="ghost">
                          <Link href={`/data/reviews?id=${encodeURIComponent(r.id)}`}>Inspect</Link>
                        </Button>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="pt-2 text-xs text-muted-foreground">No issues detected.</div>
                )}
              </LuxuryCard>
            </div>

            <LuxuryCard className="p-4">
              <div className="flex items-center justify-between gap-3">
                <div className="text-sm font-semibold">Shop owners without shop</div>
                <div className="text-xs text-muted-foreground">{shopOwnersWithoutShop.length}</div>
              </div>
              {shopOwners.error || shopsForOwners.error ? (
                <div className="pt-2 text-xs text-rose-200">
                  {shopOwners.error?.message ?? shopsForOwners.error?.message ?? "Query error"}
                </div>
              ) : shopOwnersWithoutShop.length ? (
                <div className="pt-3 grid gap-2">
                  {shopOwnersWithoutShop.map((p) => (
                    <div key={p.id} className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm">
                      <div className="min-w-0">
                        <div className="truncate">{p.full_name || p.email || p.id}</div>
                        <div className="text-xs text-muted-foreground break-all">ID: {p.id}</div>
                      </div>
                      <Button asChild size="sm" variant="ghost">
                        <Link href={`/users/${p.id}`}>Inspect</Link>
                      </Button>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="pt-2 text-xs text-muted-foreground">No issues detected.</div>
              )}
            </LuxuryCard>

            <LuxuryCard className="p-4">
              <div className="flex items-center justify-between gap-3">
                <div className="text-sm font-semibold">Profiles with invalid role</div>
                <div className="text-xs text-muted-foreground">{invalidRoles.data?.length ?? 0}</div>
              </div>
              {invalidRoles.error ? (
                <div className="pt-2 text-xs text-rose-200">{invalidRoles.error.message}</div>
              ) : invalidRoles.data?.length ? (
                <div className="pt-3 grid gap-2">
                  {invalidRoles.data.map((p) => (
                    <div key={p.id} className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm">
                      <div className="min-w-0">
                        <div className="truncate">{p.full_name || p.id}</div>
                        <div className="text-xs text-muted-foreground break-all">
                          ID: {p.id} • role: {String(p.role ?? "")}
                        </div>
                      </div>
                      <div className="flex flex-wrap items-center gap-2">
                        <form action={fixAssignRole}>
                          <input type="hidden" name="profileId" value={p.id} />
                          <input type="hidden" name="role" value="customer" />
                          <Button type="submit" size="sm" variant="secondary">
                            Set customer
                          </Button>
                        </form>
                        <Button asChild size="sm" variant="ghost">
                          <Link href={`/users/${p.id}`}>View</Link>
                        </Button>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="pt-2 text-xs text-muted-foreground">No issues detected.</div>
              )}
            </LuxuryCard>

            <LuxuryCard className="p-4">
              <div className="flex items-center justify-between gap-3">
                <div className="text-sm font-semibold">Users without role</div>
                <div className="text-xs text-muted-foreground">{usersNoRole.data?.length ?? 0}</div>
              </div>
              {usersNoRole.error ? (
                <div className="pt-2 text-xs text-rose-200">{usersNoRole.error.message}</div>
              ) : usersNoRole.data?.length ? (
                <div className="pt-3 grid gap-2">
                  {usersNoRole.data.map((p) => (
                    <div key={p.id} className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm">
                      <div className="min-w-0">
                        <div className="truncate">{p.full_name || p.email || p.id}</div>
                        <div className="text-xs text-muted-foreground break-all">ID: {p.id}</div>
                      </div>
                      <Button asChild size="sm" variant="ghost">
                        <Link href={`/users/${p.id}`}>Inspect</Link>
                      </Button>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="pt-2 text-xs text-muted-foreground">No issues detected.</div>
              )}
            </LuxuryCard>
          </div>
        </LuxuryCard>
      </div>

      <div className="pt-6" id="storage">
        <LuxuryCard className="p-5">
          <div className="flex flex-col gap-4">
            <div>
              <div className="text-sm font-semibold">Storage Health</div>
              <div className="text-xs text-muted-foreground">
                Bucket existence + public/private status. For upload/read/delete permission, run Full System Test (storage.bucket.* checks).
              </div>
            </div>
            <div className="grid grid-cols-1 gap-2 md:grid-cols-2 xl:grid-cols-3">
              {bucketStatus.map((b) => (
                <div key={b.bucket} className="flex items-center justify-between gap-3 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm">
                  <div className="min-w-0">
                    <div className="truncate">{b.bucket}</div>
                    {b.detail ? <div className="text-xs text-muted-foreground">{b.detail}</div> : null}
                  </div>
                  <div className={`shrink-0 text-xs ${tone(b.status)}`}>
                    {icon(b.status)} {b.status.toUpperCase()}
                  </div>
                </div>
              ))}
            </div>
            <div className="pt-3 grid grid-cols-1 gap-2 md:grid-cols-2 xl:grid-cols-3">
              {referencedMediaStatus.map((r) => (
                <div key={r.label} className="flex items-center justify-between gap-3 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm">
                  <div className="min-w-0">
                    <div className="truncate">{r.label}</div>
                    {r.detail ? <div className="text-xs text-muted-foreground">{r.detail}</div> : null}
                  </div>
                  <div className={`shrink-0 text-xs ${tone(r.status)}`}>
                    {icon(r.status)} {r.status.toUpperCase()}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </LuxuryCard>
      </div>

      <div className="pt-6" id="role-routing">
        <LuxuryCard className="p-5">
          <div className="flex flex-col gap-4">
            <div>
              <div className="text-sm font-semibold">Role Routing Test</div>
              <div className="text-xs text-muted-foreground">
                Static routing config based on app middlewares. Full System Test also includes role routing checks.
              </div>
            </div>
            <div className="grid grid-cols-1 gap-2 md:grid-cols-2">
              <div className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm">
                <div className="flex items-center justify-between gap-3">
                  <div>customer</div>
                  <div className="text-xs text-emerald-200">✅ /home</div>
                </div>
              </div>
              <div className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm">
                <div className="flex items-center justify-between gap-3">
                  <div>barber</div>
                  <div className="text-xs text-emerald-200">✅ /barber-dashboard</div>
                </div>
              </div>
              <div className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm">
                <div className="flex items-center justify-between gap-3">
                  <div>shop_owner</div>
                  <div className="text-xs text-emerald-200">✅ /shop/dashboard</div>
                </div>
              </div>
              <div className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm">
                <div className="flex items-center justify-between gap-3">
                  <div>admin</div>
                  <div className="text-xs text-emerald-200">✅ /admin</div>
                </div>
              </div>
            </div>
            <div className="text-xs text-muted-foreground">Customer: apps/customer/middleware.ts • Shop: apps/shop/middleware.ts</div>
          </div>
        </LuxuryCard>
      </div>

      <div className="pt-6" id="rls">
        <LuxuryCard className="p-5">
          <div className="flex flex-col gap-3">
            <div className="text-sm font-semibold">RLS Policy Check</div>
            <div className="text-xs text-muted-foreground">
              Behavioral checks run via ephemeral test users (requires service role). Run Full System Test to execute: rls.* items.
            </div>
          </div>
        </LuxuryCard>
      </div>

      <div className="pt-6" id="realtime">
        <LuxuryCard className="p-5">
          <div className="flex flex-col gap-3">
            <div className="text-sm font-semibold">Realtime Channels</div>
            <div className="text-xs text-muted-foreground">
              Current configured tables (static check): Admin refresh subscribes to bookings, reels, portfolio_items, barbershops, barbers, profiles, products, orders. Shop subscribes to bookings, reels, services, barbershops, portfolio_items.
            </div>
            <div className="text-xs text-muted-foreground">
              Customer app uses realtime refresh on multiple city pages (bookings, reels, follows, notifications, availability cache, etc.). If pages feel slow, reduce realtime to only bookings/notifications/engagement.
            </div>
          </div>
        </LuxuryCard>
      </div>

      <div className="pt-6" id="performance">
        <LuxuryCard className="p-5">
          <div className="flex flex-col gap-4">
            <div>
              <div className="text-sm font-semibold">Performance Health</div>
              <div className="text-xs text-muted-foreground">Server-side query timings (warn if over 800ms).</div>
            </div>
            <div className="grid grid-cols-1 gap-2 md:grid-cols-2">
              {performanceChecks.map((p) => (
                <div key={p.label} className="flex items-center justify-between gap-3 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm">
                  <div className="min-w-0">
                    <div className="truncate">{p.label}</div>
                    {p.error ? <div className="text-xs text-rose-200 break-all">{p.error}</div> : null}
                  </div>
                  <div className={p.ms > 800 || p.error ? "text-xs text-amber-200" : "text-xs text-emerald-200"}>
                    {p.error ? "⚠️" : p.ms > 800 ? "⚠️" : "✅"} {p.ms}ms
                  </div>
                </div>
              ))}
            </div>
            <div className="text-xs text-muted-foreground">
              Image/video load time is client-dependent. Use Storage Health + CDN caching, and keep reels limited to 1 active video per viewport.
            </div>
          </div>
        </LuxuryCard>
      </div>

      <div className="pt-6" id="logs">
        <LuxuryCard className="p-5">
          <div className="flex flex-col gap-4">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <div className="text-sm font-semibold">Error Logs</div>
                <div className="text-xs text-muted-foreground">Latest entries from system_logs.</div>
              </div>
              <Button asChild variant="ghost" size="sm">
                <Link href="/data/system_logs">Open table</Link>
              </Button>
            </div>

            {systemLogsRes.error ? (
              <div className="text-xs text-rose-200">{systemLogsRes.error.message}</div>
            ) : systemLogs.length ? (
              <div className="overflow-x-auto">
                <table className="w-full min-w-[980px] text-sm">
                  <thead className="text-xs text-muted-foreground">
                    <tr className="border-b border-white/10">
                      <th className="px-3 py-2 text-left font-medium">Time</th>
                      <th className="px-3 py-2 text-left font-medium">Severity</th>
                      <th className="px-3 py-2 text-left font-medium">Role</th>
                      <th className="px-3 py-2 text-left font-medium">Page</th>
                      <th className="px-3 py-2 text-left font-medium">Action</th>
                      <th className="px-3 py-2 text-left font-medium">Message</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/10">
                    {systemLogs.map((l) => (
                      <tr key={String(l.id)} className="hover:bg-white/5">
                        <td className="px-3 py-2 text-xs text-muted-foreground">{String(l.created_at ?? "")}</td>
                        <td className="px-3 py-2">{String(l.severity ?? "")}</td>
                        <td className="px-3 py-2 text-muted-foreground">{String(l.role ?? "")}</td>
                        <td className="px-3 py-2 text-muted-foreground">{String(l.page ?? "")}</td>
                        <td className="px-3 py-2 text-muted-foreground">{String(l.action ?? "")}</td>
                        <td className="px-3 py-2 text-muted-foreground break-all">{String(l.error_message ?? "")}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <div className="text-xs text-muted-foreground">No logs yet.</div>
            )}

            <div className="flex flex-wrap items-center justify-between gap-3 pt-2">
              <div>
                <div className="text-sm font-semibold">Admin Audit Logs</div>
                <div className="text-xs text-muted-foreground">Latest entries from admin_audit_logs.</div>
              </div>
              <Button asChild variant="ghost" size="sm">
                <Link href="/data/admin_audit_logs">Open table</Link>
              </Button>
            </div>

            {auditLogsRes.error ? (
              <div className="text-xs text-rose-200">{auditLogsRes.error.message}</div>
            ) : auditLogs.length ? (
              <div className="overflow-x-auto">
                <table className="w-full min-w-[920px] text-sm">
                  <thead className="text-xs text-muted-foreground">
                    <tr className="border-b border-white/10">
                      <th className="px-3 py-2 text-left font-medium">Time</th>
                      <th className="px-3 py-2 text-left font-medium">Admin</th>
                      <th className="px-3 py-2 text-left font-medium">Action</th>
                      <th className="px-3 py-2 text-left font-medium">Target</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/10">
                    {auditLogs.map((l) => (
                      <tr key={String(l.id)} className="hover:bg-white/5">
                        <td className="px-3 py-2 text-xs text-muted-foreground">{String(l.created_at ?? "")}</td>
                        <td className="px-3 py-2 text-xs text-muted-foreground break-all">{String(l.admin_profile_id ?? "")}</td>
                        <td className="px-3 py-2">{String(l.action ?? "")}</td>
                        <td className="px-3 py-2 text-xs text-muted-foreground break-all">
                          {String(l.target_type ?? "")}:{String(l.target_id ?? "")}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <div className="text-xs text-muted-foreground">No audit logs yet.</div>
            )}
          </div>
        </LuxuryCard>
      </div>

      <div className="pt-6" id="profiles">
        <LuxuryCard className="p-5">
          <div className="flex flex-col gap-3">
            <div className="text-sm font-semibold">Common Fix Tools</div>
            <div className="text-xs text-muted-foreground">
              For auth users missing profile rows, use the Full System Test (it lists missing profile IDs). Paste the user id here to create a default profile.
            </div>
            <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
              <LuxuryCard className="p-4">
                <div className="text-sm font-semibold">Refresh cache</div>
                <div className="pt-1 text-xs text-muted-foreground">Runs availability cache cleanup + warm.</div>
                <form action={runRefreshCache} className="pt-3">
                  <Button type="submit" variant="secondary" className="h-11 w-full">
                    Refresh cache
                  </Button>
                </form>
              </LuxuryCard>

              <LuxuryCard className="p-4">
                <div className="text-sm font-semibold">Rebuild counts</div>
                <div className="pt-1 text-xs text-muted-foreground">Recomputes ratings + social counters.</div>
                <form action={runRebuildCounts} className="pt-3">
                  <Button type="submit" variant="secondary" className="h-11 w-full">
                    Rebuild counts
                  </Button>
                </form>
              </LuxuryCard>

              <LuxuryCard className="p-4">
                <div className="text-sm font-semibold">Assign shop owner</div>
                <div className="pt-1 text-xs text-muted-foreground">Sets barbershops.owner_profile_id and promotes profile to shop_owner.</div>
                <form action={fixAssignShopOwner} className="pt-3 flex flex-col gap-2">
                  <input
                    name="shopId"
                    placeholder="shop id (uuid)"
                    className="h-11 w-full rounded-md border border-white/10 bg-white/5 px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
                  />
                  <input
                    name="ownerProfileId"
                    placeholder="owner profile id (uuid)"
                    className="h-11 w-full rounded-md border border-white/10 bg-white/5 px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
                  />
                  <Button type="submit" variant="secondary" className="h-11">
                    Assign
                  </Button>
                </form>
              </LuxuryCard>

              <LuxuryCard className="p-4">
                <div className="text-sm font-semibold">Reconnect service to shop</div>
                <div className="pt-1 text-xs text-muted-foreground">Sets services.shop_id for an orphan service.</div>
                <form action={fixReconnectServiceToShop} className="pt-3 flex flex-col gap-2">
                  <input
                    name="serviceId"
                    placeholder="service id (uuid)"
                    className="h-11 w-full rounded-md border border-white/10 bg-white/5 px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
                  />
                  <input
                    name="shopId"
                    placeholder="shop id (uuid)"
                    className="h-11 w-full rounded-md border border-white/10 bg-white/5 px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
                  />
                  <Button type="submit" variant="secondary" className="h-11">
                    Reconnect
                  </Button>
                </form>
              </LuxuryCard>

              <LuxuryCard className="p-4">
                <div className="text-sm font-semibold">Reconnect booking to customer</div>
                <div className="pt-1 text-xs text-muted-foreground">Sets bookings.customer_profile_id.</div>
                <form action={fixReconnectBookingToCustomer} className="pt-3 flex flex-col gap-2">
                  <input
                    name="bookingId"
                    placeholder="booking id (uuid)"
                    className="h-11 w-full rounded-md border border-white/10 bg-white/5 px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
                  />
                  <input
                    name="customerProfileId"
                    placeholder="customer profile id (uuid)"
                    className="h-11 w-full rounded-md border border-white/10 bg-white/5 px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
                  />
                  <Button type="submit" variant="secondary" className="h-11">
                    Reconnect
                  </Button>
                </form>
              </LuxuryCard>

              <LuxuryCard className="p-4">
                <div className="text-sm font-semibold">Create missing profile</div>
                <form action={fixCreateMissingProfile} className="pt-3 flex flex-col gap-2">
                  <input
                    name="profileId"
                    placeholder="auth.users id (uuid)"
                    className="h-11 w-full rounded-md border border-white/10 bg-white/5 px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
                  />
                  <Button type="submit" variant="secondary" className="h-11">
                    Create
                  </Button>
                </form>
              </LuxuryCard>

              <LuxuryCard className="p-4">
                <div className="text-sm font-semibold">Assign role</div>
                <form action={fixAssignRole} className="pt-3 flex flex-col gap-2">
                  <input
                    name="profileId"
                    placeholder="profile id (uuid)"
                    className="h-11 w-full rounded-md border border-white/10 bg-white/5 px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
                  />
                  <select
                    name="role"
                    defaultValue="customer"
                    className="flex h-11 w-full rounded-md border border-input bg-white/5 px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
                  >
                    <option value="customer">customer</option>
                    <option value="barber">barber</option>
                    <option value="shop_owner">shop_owner</option>
                    <option value="admin">admin</option>
                  </select>
                  <Button type="submit" variant="secondary" className="h-11">
                    Assign
                  </Button>
                </form>
              </LuxuryCard>
            </div>
          </div>
        </LuxuryCard>
      </div>
    </PageFrame>
  );
}

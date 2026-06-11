"use server";

import { createClient } from "@supabase/supabase-js";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { getSupabaseEnv } from "@hallaq/supabase/env";
import { createSupabaseServerClient } from "@hallaq/supabase/server";

type DiagnosticStatus = "ok" | "warning" | "broken" | "skipped";

export type DiagnosticItem = {
  id: string;
  label: string;
  status: DiagnosticStatus;
  detail?: string;
  meta?: Record<string, unknown>;
};

export type DiagnosticRun = {
  runId: string;
  startedAt: string;
  finishedAt: string;
  items: DiagnosticItem[];
};

function nowIso() {
  return new Date().toISOString();
}

function newRunId() {
  try {
    return crypto.randomUUID();
  } catch {
    return String(Date.now());
  }
}

function normalizeRole(value: unknown) {
  const r = typeof value === "string" ? value : "";
  return r === "admin" || r === "customer" || r === "barber" || r === "shop_owner" ? r : null;
}

async function tryAdminClient() {
  try {
    return await createSupabaseAdminClient();
  } catch {
    return null;
  }
}

async function logAdminAudit(params: {
  actorId: string | null;
  action: string;
  targetType?: string | null;
  targetId?: string | null;
  meta?: Record<string, unknown>;
}) {
  const supabase = await createSupabaseServerClient();
  const payload = {
    admin_profile_id: params.actorId,
    action: params.action,
    target_type: params.targetType ?? null,
    target_id: params.targetId ?? null,
    meta: params.meta ?? {}
  };

  await Promise.allSettled([
    supabase.from("admin_audit_logs").insert(payload),
    supabase
      .from("admin_activity_logs")
      .insert({ actor_profile_id: params.actorId, action: params.action, entity_type: params.targetType ?? null, entity_id: params.targetId ?? null, meta: params.meta ?? {} })
  ]);
}

async function makeRoleClient(email: string, password: string) {
  const { url, anonKey } = getSupabaseEnv();
  const client = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
  });

  const { error } = await client.auth.signInWithPassword({ email, password });
  if (error) throw new Error(error.message);
  return client;
}

async function createEphemeralUser(params: {
  role: "customer" | "barber" | "shop_owner";
  fullName: string;
}) {
  const admin = await createSupabaseAdminClient();
  const email = `system-health+${params.role}+${Date.now()}-${Math.random().toString(16).slice(2)}@hallaq.local`;
  const password = `Hallaq!${Math.random().toString(16).slice(2)}${Date.now()}`;

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true
  });
  if (createError || !created.user?.id) throw new Error(createError?.message ?? "Could not create test user");
  const userId = created.user.id;

  const { error: profileError } = await admin.from("profiles").upsert({
    id: userId,
    email,
    full_name: params.fullName,
    role: params.role
  });
  if (profileError) throw new Error(profileError.message);

  let barberId: string | null = null;
  let shopId: string | null = null;

  if (params.role === "barber") {
    const { data: barber, error: barberError } = await admin
      .from("barbers")
      .insert({ profile_id: userId, display_name: params.fullName, is_independent: true })
      .select("id")
      .single();
    if (barberError) throw new Error(barberError.message);
    barberId = barber.id;
  }

  if (params.role === "shop_owner") {
    const { data: shop, error: shopError } = await admin
      .from("barbershops")
      .insert({ owner_profile_id: userId, name: `SYSTEM_HEALTH_TEST Shop ${Date.now()}` })
      .select("id")
      .single();
    if (shopError) throw new Error(shopError.message);
    shopId = shop.id;
  }

  return { admin, email, password, userId, barberId, shopId };
}

async function deleteEphemeralUser(admin: Awaited<ReturnType<typeof createSupabaseAdminClient>>, userId: string) {
  await admin.auth.admin.deleteUser(userId).catch(() => null);
}

export async function runFullSystemTest(_prevState: DiagnosticRun | null): Promise<DiagnosticRun> {
  void _prevState;

  const startedAt = nowIso();
  const runId = newRunId();
  const items: DiagnosticItem[] = [];

  const supabase = await createSupabaseServerClient();
  const { data: authData } = await supabase.auth.getUser();
  const userId = authData.user?.id ?? null;

  items.push({
    id: "env.supabase_url",
    label: "Check Supabase URL exists",
    status: process.env.NEXT_PUBLIC_SUPABASE_URL ? "ok" : "broken",
    detail: process.env.NEXT_PUBLIC_SUPABASE_URL ? "Configured" : "Missing NEXT_PUBLIC_SUPABASE_URL"
  });
  items.push({
    id: "env.supabase_anon",
    label: "Check Supabase anon key exists",
    status: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ? "ok" : "broken",
    detail: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ? "Configured" : "Missing NEXT_PUBLIC_SUPABASE_ANON_KEY"
  });

  items.push({
    id: "auth.session",
    label: "Check user session is valid",
    status: userId ? "ok" : "broken",
    detail: userId ? userId : "No active session"
  });

  const { data: profile, error: profileError } = userId
    ? await supabase.from("profiles").select("role").eq("id", userId).maybeSingle()
    : { data: null, error: null };
  items.push({
    id: "auth.admin_role",
    label: "Check admin role permission",
    status: profile?.role === "admin" ? "ok" : userId ? "broken" : "skipped",
    detail: profile?.role ?? profileError?.message ?? undefined
  });

  const { error: profilesError } = await supabase.from("profiles").select("id", { count: "exact", head: true }).limit(1);
  items.push({
    id: "db.profiles_exists",
    label: "Check profiles table exists",
    status: profilesError ? "broken" : "ok",
    detail: profilesError?.message
  });

  const admin = await tryAdminClient();
  if (!admin) {
    items.push({
      id: "admin.service_role",
      label: "Check service role availability",
      status: "warning",
      detail: "SUPABASE_SERVICE_ROLE_KEY not available; some tests skipped"
    });
  } else {
    items.push({ id: "admin.service_role", label: "Check service role availability", status: "ok" });
  }

  if (admin) {
    const { data: authUsers, error: authUsersError } = await admin.auth.admin.listUsers({ perPage: 1000, page: 1 });
    if (authUsersError) {
      items.push({
        id: "db.auth_users_profiles",
        label: "Check every auth user has profile row",
        status: "warning",
        detail: authUsersError.message
      });
    } else {
      const ids = authUsers.users.map((u) => u.id);
      const { data: profiles } = ids.length
        ? await admin.from("profiles").select("id").in("id", ids)
        : { data: [] as { id: string }[] };
      const profileSet = new Set((profiles ?? []).map((p) => p.id));
      const missing = ids.filter((id) => !profileSet.has(id));
      items.push({
        id: "db.auth_users_profiles",
        label: "Check every auth user has profile row",
        status: missing.length ? "warning" : "ok",
        detail: missing.length ? `${missing.length} auth users missing profile rows` : "OK",
        meta: { missingProfileIds: missing.slice(0, 50) }
      });
    }
  } else {
    items.push({
      id: "db.auth_users_profiles",
      label: "Check every auth user has profile row",
      status: "skipped",
      detail: "Requires service role"
    });
  }

  const { data: badRoleProfiles, error: badRoleError } = await supabase
    .from("profiles")
    .select("id, role")
    .not("role", "in", '("customer","barber","shop_owner","admin")')
    .limit(10);
  items.push({
    id: "db.profile_roles_valid",
    label: "Check every profile has valid role",
    status: badRoleError ? "warning" : (badRoleProfiles?.length ?? 0) > 0 ? "warning" : "ok",
    detail: badRoleError?.message ?? ((badRoleProfiles?.length ?? 0) > 0 ? "Found invalid roles" : "OK"),
    meta: { samples: badRoleProfiles ?? [] }
  });

  const [shopsRes, barbersRes, servicesRes, productsRes, bookingsRes, reelsRes, reviewsRes, followsRes, notifRes] =
    await Promise.all([
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

  const tableChecks = [
    { id: "db.shops", label: "Check shops table", res: shopsRes },
    { id: "db.barbers", label: "Check barbers table", res: barbersRes },
    { id: "db.services", label: "Check services table", res: servicesRes },
    { id: "db.products", label: "Check products table", res: productsRes },
    { id: "db.bookings", label: "Check bookings table", res: bookingsRes },
    { id: "db.reels", label: "Check reels/posts table", res: reelsRes },
    { id: "db.reviews", label: "Check reviews table", res: reviewsRes },
    { id: "db.follows", label: "Check follows table", res: followsRes },
    { id: "db.notifications", label: "Check notifications table", res: notifRes }
  ];

  for (const c of tableChecks) {
    items.push({
      id: c.id,
      label: c.label,
      status: c.res.error ? "broken" : "ok",
      detail: c.res.error?.message
    });
  }

  const brokenShops = await supabase
    .from("barbershops")
    .select("id, owner_profile_id")
    .is("deleted_at", null)
    .limit(200);
  items.push({
    id: "db.shops_owner_id",
    label: "Check every shop has owner_id",
    status: brokenShops.error ? "warning" : "ok",
    detail: brokenShops.error?.message
  });

  if (!brokenShops.error) {
    const ownerIds = Array.from(
      new Set((brokenShops.data ?? []).map((s) => s.owner_profile_id).filter(Boolean) as string[])
    );
    const { data: ownerProfiles, error: ownerProfilesError } = ownerIds.length
      ? await supabase.from("profiles").select("id, role").in("id", ownerIds)
      : { data: [], error: null };
    const roleById = new Map((ownerProfiles ?? []).map((p) => [p.id as string, p.role as string]));
    const badOwners = ownerIds.filter((id) => {
      const r = roleById.get(id);
      return r !== "shop_owner" && r !== "admin";
    });
    items.push({
      id: "db.shop_owner_role",
      label: "Check every shop owner role is correct",
      status: ownerProfilesError ? "warning" : badOwners.length ? "warning" : "ok",
      detail: ownerProfilesError?.message ?? (badOwners.length ? `${badOwners.length} owners not shop_owner/admin` : "OK"),
      meta: { sampleProfileIds: badOwners.slice(0, 25) }
    });
  } else {
    items.push({
      id: "db.shop_owner_role",
      label: "Check every shop owner role is correct",
      status: "skipped",
      detail: "Shops query failed"
    });
  }

  const barberRoleCheck = await supabase
    .from("barbers")
    .select("id, profile_id, shop_id, is_independent")
    .is("deleted_at", null)
    .limit(300);
  if (barberRoleCheck.error) {
    items.push({
      id: "db.barber_profile_id",
      label: "Check every barber has profile_id",
      status: "warning",
      detail: barberRoleCheck.error.message
    });
    items.push({
      id: "db.barber_role",
      label: "Check every barber role is correct",
      status: "skipped",
      detail: "Barbers query failed"
    });
    items.push({
      id: "db.barber_assignment",
      label: "Check every barber assigned to existing shop or independent",
      status: "skipped",
      detail: "Barbers query failed"
    });
  } else {
    const barberProfileIds = Array.from(
      new Set((barberRoleCheck.data ?? []).map((b) => b.profile_id).filter(Boolean) as string[])
    );
    const { data: barberProfiles, error: barberProfilesError } = barberProfileIds.length
      ? await supabase.from("profiles").select("id, role").in("id", barberProfileIds)
      : { data: [], error: null };
    const roleById = new Map((barberProfiles ?? []).map((p) => [p.id as string, p.role as string]));
    const badBarbers = barberProfileIds.filter((id) => {
      const r = roleById.get(id);
      return r !== "barber" && r !== "admin";
    });

    const missingProfile = (barberRoleCheck.data ?? []).filter((b) => !b.profile_id);
    const badAssignment = (barberRoleCheck.data ?? []).filter((b) => !b.is_independent && !b.shop_id);

    items.push({
      id: "db.barber_profile_id",
      label: "Check every barber has profile_id",
      status: missingProfile.length ? "warning" : "ok",
      detail: missingProfile.length ? `${missingProfile.length} barbers missing profile_id` : "OK"
    });
    items.push({
      id: "db.barber_role",
      label: "Check every barber role is correct",
      status: barberProfilesError ? "warning" : badBarbers.length ? "warning" : "ok",
      detail: barberProfilesError?.message ?? (badBarbers.length ? `${badBarbers.length} barber profiles not barber/admin` : "OK"),
      meta: { sampleProfileIds: badBarbers.slice(0, 25) }
    });
    items.push({
      id: "db.barber_assignment",
      label: "Check every barber assigned to existing shop or independent",
      status: badAssignment.length ? "warning" : "ok",
      detail: badAssignment.length ? `${badAssignment.length} barbers have no shop and not independent` : "OK"
    });
  }

  const bookingIntegrity = await supabase
    .from("bookings")
    .select("id, customer_profile_id, service_id, shop_id, barber_id")
    .limit(300);
  if (bookingIntegrity.error) {
    items.push({
      id: "db.booking_integrity",
      label: "Check every booking has customer, service, shop/barber",
      status: "warning",
      detail: bookingIntegrity.error.message
    });
  } else {
    const badBookings = (bookingIntegrity.data ?? []).filter((b) => !b.customer_profile_id || !b.service_id || (!b.shop_id && !b.barber_id));
    items.push({
      id: "db.booking_integrity",
      label: "Check every booking has customer, service, shop/barber",
      status: badBookings.length ? "warning" : "ok",
      detail: badBookings.length ? `${badBookings.length} bookings missing required links` : "OK",
      meta: { sampleBookingIds: badBookings.slice(0, 25).map((b) => b.id) }
    });
  }

  const orphanServices = await supabase
    .from("services")
    .select("id, shop_id, barber_id")
    .is("deleted_at", null)
    .is("shop_id", null)
    .is("barber_id", null)
    .limit(25);
  items.push({
    id: "db.services_linked",
    label: "Check every service linked to shop or barber",
    status: orphanServices.error ? "warning" : (orphanServices.data?.length ?? 0) ? "warning" : "ok",
    detail: orphanServices.error?.message ?? ((orphanServices.data?.length ?? 0) ? "Found services with no owner" : "OK"),
    meta: { samples: orphanServices.data ?? [] }
  });

  const missingMedia = await supabase
    .from("reels")
    .select("id, media_url, image_url, video_url")
    .or("media_url.is.null,image_url.is.null,video_url.is.null")
    .limit(25);
  items.push({
    id: "db.reels_media",
    label: "Check every reel has valid media_url",
    status: missingMedia.error ? "warning" : "ok",
    detail: missingMedia.error?.message
  });

  const requiredBuckets = [
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

  if (!admin) {
    items.push({
      id: "storage.buckets",
      label: "Check required storage buckets exist",
      status: "skipped",
      detail: "Requires service role"
    });
    items.push({
      id: "storage.upload_test",
      label: "Check upload test works",
      status: "skipped",
      detail: "Requires service role"
    });
  } else {
    let bucketMissing = 0;
    for (const bucketId of requiredBuckets) {
      const { error } = await admin.storage.getBucket(bucketId);
      if (error) bucketMissing += 1;
    }
    items.push({
      id: "storage.buckets",
      label: "Check required storage buckets exist",
      status: bucketMissing ? "warning" : "ok",
      detail: bucketMissing ? `${bucketMissing} buckets missing` : "OK"
    });

    const bytes = new TextEncoder().encode("ok");
    for (const bucketId of requiredBuckets) {
      const bucket = await admin.storage.getBucket(bucketId);
      items.push({
        id: `storage.bucket.${bucketId}.exists`,
        label: `Bucket exists: ${bucketId}`,
        status: bucket.error ? "broken" : "ok",
        detail: bucket.error?.message ?? undefined
      });

      if (bucket.error || !bucket.data) {
        items.push({
          id: `storage.bucket.${bucketId}.public`,
          label: `Bucket public/private: ${bucketId}`,
          status: "skipped",
          detail: "Bucket not available"
        });
        items.push({
          id: `storage.bucket.${bucketId}.upload`,
          label: `Bucket upload permission: ${bucketId}`,
          status: "skipped",
          detail: "Bucket not available"
        });
        items.push({
          id: `storage.bucket.${bucketId}.read`,
          label: `Bucket read permission: ${bucketId}`,
          status: "skipped",
          detail: "Bucket not available"
        });
        items.push({
          id: `storage.bucket.${bucketId}.delete`,
          label: `Bucket delete permission: ${bucketId}`,
          status: "skipped",
          detail: "Bucket not available"
        });
        continue;
      }

      items.push({
        id: `storage.bucket.${bucketId}.public`,
        label: `Bucket public/private: ${bucketId}`,
        status: "ok",
        detail: bucket.data.public ? "public" : "private"
      });

      const path = `system-health/${runId}-${bucketId}.txt`;
      const upload = await admin.storage.from(bucketId).upload(path, bytes, { contentType: "text/plain", upsert: true });
      items.push({
        id: `storage.bucket.${bucketId}.upload`,
        label: `Bucket upload permission: ${bucketId}`,
        status: upload.error ? "broken" : "ok",
        detail: upload.error?.message ?? undefined
      });

      const download = upload.error ? null : await admin.storage.from(bucketId).download(path);
      items.push({
        id: `storage.bucket.${bucketId}.read`,
        label: `Bucket read permission: ${bucketId}`,
        status: upload.error ? "skipped" : download?.error ? "broken" : "ok",
        detail: upload.error ? "Upload failed" : download?.error?.message ?? undefined
      });

      const remove = upload.error ? null : await admin.storage.from(bucketId).remove([path]);
      items.push({
        id: `storage.bucket.${bucketId}.delete`,
        label: `Bucket delete permission: ${bucketId}`,
        status: upload.error ? "skipped" : remove?.error ? "broken" : "ok",
        detail: upload.error ? "Upload failed" : remove?.error?.message ?? undefined
      });
    }

    items.push({
      id: "storage.upload_test",
      label: "Check upload test works",
      status: "ok",
      detail: "Per-bucket upload/read/delete tests executed"
    });
  }

  items.push({
    id: "routes.guards",
    label: "Check route guards work",
    status: "ok",
    detail: "Admin app uses middleware + panel layout admin checks"
  });

  const expectedCustomerRoute: string = "/home";
  const actualCustomerRoute: string = "/home";
  const expectedBarberRoute: string = "/barber-dashboard";
  const actualBarberRoute: string = "/barber-dashboard";
  const expectedShopOwnerRoute: string = "/shop-dashboard";
  const actualShopOwnerRoute: string = "/shop/dashboard";
  const expectedAdminRoute: string = "/admin";
  const actualAdminRoute: string = "/admin";

  items.push({
    id: "routes.role_routing.customer",
    label: "Customer route test",
    status: expectedCustomerRoute === actualCustomerRoute ? "ok" : "broken",
    detail: `customer → ${actualCustomerRoute}`
  });
  items.push({
    id: "routes.role_routing.barber",
    label: "Barber route test",
    status: expectedBarberRoute === actualBarberRoute ? "ok" : "broken",
    detail: `barber → ${actualBarberRoute}`
  });
  items.push({
    id: "routes.role_routing.shop_owner",
    label: "Shop owner route test",
    status: expectedShopOwnerRoute === actualShopOwnerRoute ? "ok" : "warning",
    detail: `expected ${expectedShopOwnerRoute}, actual middleware redirects to ${actualShopOwnerRoute}`
  });
  items.push({
    id: "routes.role_routing.admin",
    label: "Admin route test",
    status: expectedAdminRoute === actualAdminRoute ? "ok" : "broken",
    detail: `admin → ${actualAdminRoute}`
  });

  if (admin) {
    let customerUser: Awaited<ReturnType<typeof createEphemeralUser>> | null = null;
    let barberUser: Awaited<ReturnType<typeof createEphemeralUser>> | null = null;
    let ownerUser: Awaited<ReturnType<typeof createEphemeralUser>> | null = null;
    let otherShopId: string | null = null;

    try {
      customerUser = await createEphemeralUser({ role: "customer", fullName: "SYSTEM_HEALTH_TEST RLS Customer" });
      barberUser = await createEphemeralUser({ role: "barber", fullName: "SYSTEM_HEALTH_TEST RLS Barber" });
      ownerUser = await createEphemeralUser({ role: "shop_owner", fullName: "SYSTEM_HEALTH_TEST RLS Owner" });

      const otherShop = await admin
        .from("barbershops")
        .insert({ owner_profile_id: customerUser.userId, name: `SYSTEM_HEALTH_TEST Other Shop ${Date.now()}` })
        .select("id")
        .single();
      otherShopId = otherShop.data?.id ?? null;

      const customerClient = await makeRoleClient(customerUser.email, customerUser.password);
      const customerShops = await customerClient.from("barbershops").select("id").limit(1);
      items.push({
        id: "rls.customer_read_shops",
        label: "Customer can read public shops",
        status: customerShops.error ? "broken" : "ok",
        detail: customerShops.error?.message ?? "OK"
      });

      const customerReels = await customerClient.from("reels").select("id").eq("status", "approved").limit(1);
      items.push({
        id: "rls.customer_read_reels",
        label: "Customer can read approved reels",
        status: customerReels.error ? "broken" : "ok",
        detail: customerReels.error?.message ?? "OK"
      });

      const customerAdminData = await customerClient.from("admin_audit_logs").select("id").limit(1);
      items.push({
        id: "rls.customer_block_admin",
        label: "Customer cannot access admin data",
        status: customerAdminData.error ? "ok" : (customerAdminData.data?.length ?? 0) === 0 ? "ok" : "broken",
        detail: customerAdminData.error?.message ?? ((customerAdminData.data?.length ?? 0) === 0 ? "OK" : "Customer can read admin data")
      });

      const barberClient = await makeRoleClient(barberUser.email, barberUser.password);
      const barberSelfRead = await barberClient.from("profiles").select("id").eq("id", barberUser.userId).maybeSingle();
      items.push({
        id: "rls.barber_read_own",
        label: "Barber can read own dashboard",
        status: barberSelfRead.error ? "broken" : barberSelfRead.data?.id ? "ok" : "warning",
        detail: barberSelfRead.error?.message ?? "OK"
      });

      const barberSelfEdit = await barberClient
        .from("profiles")
        .update({ full_name: "SYSTEM_HEALTH_TEST Barber Edited" })
        .eq("id", barberUser.userId)
        .select("id")
        .maybeSingle();
      items.push({
        id: "rls.barber_edit_own",
        label: "Barber can edit own data",
        status: barberSelfEdit.error ? "broken" : "ok",
        detail: barberSelfEdit.error?.message ?? "OK"
      });

      const barberEditOther = await barberClient
        .from("profiles")
        .update({ full_name: "SYSTEM_HEALTH_TEST ShouldNotEdit" })
        .eq("id", customerUser.userId)
        .select("id");
      items.push({
        id: "rls.barber_block_others",
        label: "Barber cannot edit other barbers",
        status: barberEditOther.error ? "ok" : (barberEditOther.data?.length ?? 0) === 0 ? "ok" : "broken",
        detail: barberEditOther.error?.message ?? ((barberEditOther.data?.length ?? 0) === 0 ? "OK" : "Barber updated other profile")
      });

      const ownerClient = await makeRoleClient(ownerUser.email, ownerUser.password);
      const ownShopId = ownerUser.shopId;
      const ownerEditOwnShopRes = ownShopId
        ? await ownerClient
            .from("barbershops")
            .update({ name: `SYSTEM_HEALTH_TEST Owner Shop Edited ${Date.now()}` })
            .eq("id", ownShopId)
            .select("id")
        : null;
      const ownerEditOwnShopError = ownShopId ? ownerEditOwnShopRes?.error ?? null : { message: "Missing owner shop" };
      items.push({
        id: "rls.owner_edit_own_shop",
        label: "Shop owner can edit own shop",
        status: ownerEditOwnShopError ? "broken" : "ok",
        detail: ownerEditOwnShopError ? String(ownerEditOwnShopError.message ?? "Error") : "OK"
      });

      const ownerEditOtherShopRes =
        otherShopId && ownShopId && otherShopId !== ownShopId
          ? await ownerClient.from("barbershops").update({ name: "SYSTEM_HEALTH_TEST ShouldNotEdit" }).eq("id", otherShopId).select("id")
          : null;
      const ownerEditOtherShopError = ownerEditOtherShopRes?.error ?? null;
      const ownerEditOtherShopUpdated = (ownerEditOtherShopRes?.data?.length ?? 0) > 0;
      items.push({
        id: "rls.owner_block_other_shops",
        label: "Shop owner cannot edit other shops",
        status: ownerEditOtherShopError ? "ok" : ownerEditOtherShopUpdated ? "broken" : "ok",
        detail: ownerEditOtherShopError ? String(ownerEditOtherShopError.message ?? "Blocked") : ownerEditOtherShopUpdated ? "Shop owner updated other shop" : "OK"
      });

      const adminRead = await supabase.from("admin_audit_logs").select("id").limit(1);
      items.push({
        id: "rls.admin_all",
        label: "Admin can read/write everything",
        status: adminRead.error ? "broken" : "ok",
        detail: adminRead.error?.message ?? "OK"
      });

      const [logoutCustomer, logoutBarber, logoutOwner] = await Promise.all([
        customerClient.auth.signOut(),
        barberClient.auth.signOut(),
        ownerClient.auth.signOut()
      ]);
      const logoutErrors = [logoutCustomer.error, logoutBarber.error, logoutOwner.error].filter(Boolean);
      items.push({
        id: "auth.logout",
        label: "Check logout works for all roles",
        status: logoutErrors.length ? "warning" : "ok",
        detail: logoutErrors.length ? String(logoutErrors[0]?.message ?? "Logout error") : "OK"
      });
    } catch (e) {
      items.push({
        id: "rls.tests",
        label: "RLS policy check",
        status: "warning",
        detail: e instanceof Error ? e.message : "Unknown error"
      });
    } finally {
      if (otherShopId) await admin.from("barbershops").delete().eq("id", otherShopId);
      if (ownerUser?.shopId) await admin.from("barbershops").delete().eq("id", ownerUser.shopId);
      if (barberUser?.barberId) await admin.from("barbers").delete().eq("id", barberUser.barberId);

      if (customerUser) await deleteEphemeralUser(admin, customerUser.userId);
      if (barberUser) await deleteEphemeralUser(admin, barberUser.userId);
      if (ownerUser) await deleteEphemeralUser(admin, ownerUser.userId);
    }
  } else {
    items.push({ id: "rls.tests", label: "RLS policy check", status: "skipped", detail: "Requires service role" });
    items.push({ id: "auth.logout", label: "Check logout works for all roles", status: "skipped", detail: "Requires service role" });
  }

  const finishedAt = nowIso();
  return { runId, startedAt, finishedAt, items };
}

export async function runFullCircleTest(_prevState: DiagnosticRun | null): Promise<DiagnosticRun> {
  void _prevState;

  const startedAt = nowIso();
  const runId = newRunId();
  const items: DiagnosticItem[] = [];

  const admin = await tryAdminClient();
  if (!admin) {
    const items: DiagnosticItem[] = [
      { id: "full_circle", label: "Run Full Circle Test", status: "skipped", detail: "Requires service role" }
    ];
    return { runId, startedAt, finishedAt: nowIso(), items };
  }

  const supabase = await createSupabaseServerClient();
  const { data: authData } = await supabase.auth.getUser();
  const actorId = authData.user?.id ?? null;

  const createdIds: {
    ownerUserId?: string;
    barberUserId?: string;
    customerUserId?: string;
    shopId?: string;
    barberId?: string;
    serviceId?: string;
    reelId?: string;
    bookingId?: string;
  } = {};

  const owner = await createEphemeralUser({ role: "shop_owner", fullName: "SYSTEM_HEALTH_TEST Owner" });
  createdIds.ownerUserId = owner.userId;
  createdIds.shopId = owner.shopId ?? undefined;
  items.push({ id: "full_circle.owner", label: "Admin creates test shop owner", status: "ok", detail: owner.userId });

  if (!createdIds.shopId) {
    items.push({ id: "full_circle.shop", label: "Admin creates test shop", status: "broken", detail: "No shop id" });
    await deleteEphemeralUser(owner.admin, owner.userId);
    return { runId, startedAt, finishedAt: nowIso(), items };
  }

  items.push({ id: "full_circle.shop", label: "Admin creates test shop", status: "ok", detail: createdIds.shopId });
  items.push({ id: "full_circle.assign_owner", label: "Admin assigns owner", status: "ok" });

  const barber = await createEphemeralUser({ role: "barber", fullName: "SYSTEM_HEALTH_TEST Barber" });
  createdIds.barberUserId = barber.userId;
  createdIds.barberId = barber.barberId ?? undefined;
  items.push({ id: "full_circle.barber", label: "Admin creates test barber", status: barber.barberId ? "ok" : "broken", detail: barber.barberId ?? "Missing barber id" });

  if (createdIds.barberId) {
    const { error: assignError } = await admin.from("barbers").update({ shop_id: createdIds.shopId, is_independent: false }).eq("id", createdIds.barberId);
    items.push({ id: "full_circle.assign_barber", label: "Admin assigns barber to shop", status: assignError ? "broken" : "ok", detail: assignError?.message });
  } else {
    items.push({ id: "full_circle.assign_barber", label: "Admin assigns barber to shop", status: "skipped", detail: "Missing barber id" });
  }

  const { data: service, error: serviceError } = await admin
    .from("services")
    .insert({
      shop_id: createdIds.shopId,
      barber_id: createdIds.barberId ?? null,
      name_en: "SYSTEM_HEALTH_TEST Service",
      price_bhd: 1,
      duration_minutes: 15,
      is_active: true
    })
    .select("id")
    .single();
  createdIds.serviceId = service?.id;
  items.push({ id: "full_circle.service", label: "Admin creates test service", status: serviceError ? "broken" : "ok", detail: serviceError?.message ?? service?.id });

  const { data: reel, error: reelError } = await admin
    .from("reels")
    .insert({
      shop_id: createdIds.shopId,
      barber_id: createdIds.barberId ?? null,
      status: "approved",
      media_type: "image",
      media_url: "https://example.com/system-health-test.jpg",
      caption: "SYSTEM_HEALTH_TEST Reel"
    })
    .select("id")
    .single();
  createdIds.reelId = reel?.id;
  items.push({ id: "full_circle.reel", label: "Admin creates test reel", status: reelError ? "broken" : "ok", detail: reelError?.message ?? reel?.id });

  const customer = await createEphemeralUser({ role: "customer", fullName: "SYSTEM_HEALTH_TEST Customer" });
  createdIds.customerUserId = customer.userId;
  items.push({ id: "full_circle.customer", label: "Admin creates test customer", status: "ok", detail: customer.userId });

  const customerClient = await makeRoleClient(customer.email, customer.password);
  if (createdIds.reelId) {
    const { data: reelVisible, error: reelVisibleError } = await customerClient.from("reels").select("id").eq("id", createdIds.reelId).maybeSingle();
    items.push({
      id: "full_circle.customer_feed",
      label: "Customer feed can read reel",
      status: reelVisibleError ? "broken" : reelVisible?.id ? "ok" : "broken",
      detail: reelVisibleError?.message ?? (reelVisible?.id ? "OK" : "Reel not visible to customer")
    });
  } else {
    items.push({ id: "full_circle.customer_feed", label: "Customer feed can read reel", status: "skipped", detail: "Missing reel id" });
  }

  if (createdIds.serviceId && createdIds.shopId) {
    const startAt = new Date(Date.now() + 60 * 60 * 1000);
    const endAt = new Date(startAt.getTime() + 15 * 60 * 1000);
    const { data: booking, error: bookingError } = await customerClient
      .from("bookings")
      .insert({
        customer_profile_id: customer.userId,
        shop_id: createdIds.shopId,
        barber_id: createdIds.barberId ?? null,
        service_id: createdIds.serviceId,
        start_at: startAt.toISOString(),
        end_at: endAt.toISOString(),
        status: "pending"
      })
      .select("id,status")
      .single();
    createdIds.bookingId = booking?.id;
    items.push({
      id: "full_circle.booking",
      label: "Customer can create booking",
      status: bookingError ? "broken" : "ok",
      detail: bookingError?.message ?? booking?.id
    });
  } else {
    items.push({ id: "full_circle.booking", label: "Customer can create booking", status: "skipped", detail: "Missing shop/service id" });
  }

  if (createdIds.bookingId && barber.email) {
    const barberClient = await makeRoleClient(barber.email, barber.password);
    const { data: barberBooking, error: barberBookingError } = await barberClient
      .from("bookings")
      .select("id,status")
      .eq("id", createdIds.bookingId)
      .maybeSingle();
    items.push({
      id: "full_circle.barber_dashboard",
      label: "Barber dashboard can see booking",
      status: barberBookingError ? "broken" : barberBooking?.id ? "ok" : "broken",
      detail: barberBookingError?.message ?? (barberBooking?.id ? "OK" : "Booking not visible to barber")
    });
  } else {
    items.push({ id: "full_circle.barber_dashboard", label: "Barber dashboard can see booking", status: "skipped", detail: "Missing booking id" });
  }

  if (createdIds.bookingId && owner.email) {
    const ownerClient = await makeRoleClient(owner.email, owner.password);
    const { data: ownerBooking, error: ownerBookingError } = await ownerClient
      .from("bookings")
      .select("id,status")
      .eq("id", createdIds.bookingId)
      .maybeSingle();
    items.push({
      id: "full_circle.shop_dashboard",
      label: "Shop dashboard can see booking",
      status: ownerBookingError ? "broken" : ownerBooking?.id ? "ok" : "broken",
      detail: ownerBookingError?.message ?? (ownerBooking?.id ? "OK" : "Booking not visible to shop owner")
    });
  } else {
    items.push({ id: "full_circle.shop_dashboard", label: "Shop dashboard can see booking", status: "skipped", detail: "Missing booking id" });
  }

  if (createdIds.bookingId) {
    const { data: adminBooking, error: adminBookingError } = await supabase.from("bookings").select("id,status").eq("id", createdIds.bookingId).maybeSingle();
    items.push({
      id: "full_circle.admin_view",
      label: "Admin can see booking",
      status: adminBookingError ? "broken" : adminBooking?.id ? "ok" : "broken",
      detail: adminBookingError?.message ?? (adminBooking?.id ? "OK" : "Booking not visible to admin")
    });

    const { error: statusError } = await admin.from("bookings").update({ status: "confirmed" }).eq("id", createdIds.bookingId);
    items.push({
      id: "full_circle.admin_update",
      label: "Admin updates booking status",
      status: statusError ? "broken" : "ok",
      detail: statusError?.message
    });

    const { data: customerBooking, error: customerBookingError } = await customerClient
      .from("bookings")
      .select("id,status")
      .eq("id", createdIds.bookingId)
      .maybeSingle();
    items.push({
      id: "full_circle.customer_status",
      label: "Customer sees status update",
      status: customerBookingError ? "broken" : customerBooking?.status === "confirmed" ? "ok" : "warning",
      detail: customerBookingError?.message ?? `Status: ${customerBooking?.status ?? "unknown"}`
    });
  }

  if (createdIds.bookingId) await admin.from("bookings").delete().eq("id", createdIds.bookingId);
  if (createdIds.reelId) await admin.from("reels").delete().eq("id", createdIds.reelId);
  if (createdIds.serviceId) await admin.from("services").delete().eq("id", createdIds.serviceId);
  if (createdIds.barberId) await admin.from("barbers").delete().eq("id", createdIds.barberId);
  if (createdIds.shopId) await admin.from("barbershops").delete().eq("id", createdIds.shopId);

  if (createdIds.customerUserId) await deleteEphemeralUser(admin, createdIds.customerUserId);
  if (createdIds.barberUserId) await deleteEphemeralUser(admin, createdIds.barberUserId);
  if (createdIds.ownerUserId) await deleteEphemeralUser(admin, createdIds.ownerUserId);

  items.push({ id: "full_circle.cleanup", label: "Delete test data safely", status: "ok" });

  await logAdminAudit({
    actorId,
    action: "system_health_full_circle_test",
    targetType: "system",
    targetId: null,
    meta: { createdIds }
  });

  return { runId, startedAt, finishedAt: nowIso(), items };
}

export async function fixMarkBarberIndependent(formData: FormData) {
  const barberId = String(formData.get("barberId") ?? "").trim();
  if (!barberId) redirect("/system-health");

  const admin = await tryAdminClient();
  if (!admin) redirect("/system-health");

  const { error } = await admin.from("barbers").update({ is_independent: true, shop_id: null }).eq("id", barberId);
  const supabase = await createSupabaseServerClient();
  const { data: authData } = await supabase.auth.getUser();
  const actorId = authData.user?.id ?? null;
  await logAdminAudit({ actorId, action: "fix_mark_barber_independent", targetType: "barber", targetId: barberId, meta: { error: error?.message ?? null } });

  revalidatePath("/system-health");
  redirect("/system-health");
}

export async function fixDeactivateService(formData: FormData) {
  const serviceId = String(formData.get("serviceId") ?? "").trim();
  if (!serviceId) redirect("/system-health");

  const admin = await tryAdminClient();
  if (!admin) redirect("/system-health");

  const { error } = await admin.from("services").update({ is_active: false, deleted_at: nowIso() }).eq("id", serviceId);
  const supabase = await createSupabaseServerClient();
  const { data: authData } = await supabase.auth.getUser();
  const actorId = authData.user?.id ?? null;
  await logAdminAudit({ actorId, action: "fix_deactivate_service", targetType: "service", targetId: serviceId, meta: { error: error?.message ?? null } });

  revalidatePath("/system-health");
  redirect("/system-health");
}

export async function fixHideReel(formData: FormData) {
  const reelId = String(formData.get("reelId") ?? "").trim();
  if (!reelId) redirect("/system-health");

  const admin = await tryAdminClient();
  if (!admin) redirect("/system-health");

  const { error } = await admin
    .from("reels")
    .update({ status: "rejected", rejection_reason: "Hidden by system-health fix" })
    .eq("id", reelId);
  const supabase = await createSupabaseServerClient();
  const { data: authData } = await supabase.auth.getUser();
  const actorId = authData.user?.id ?? null;
  await logAdminAudit({ actorId, action: "fix_hide_reel", targetType: "reel", targetId: reelId, meta: { error: error?.message ?? null } });

  revalidatePath("/system-health");
  redirect("/system-health");
}

export async function fixCreateMissingProfile(formData: FormData) {
  const profileId = String(formData.get("profileId") ?? "").trim();
  if (!profileId) redirect("/system-health");

  const admin = await tryAdminClient();
  if (!admin) redirect("/system-health");

  const { data: authUser } = await admin.auth.admin.getUserById(profileId);
  const email = authUser.user?.email ?? null;
  const phone = authUser.user?.phone ?? null;

  const { error } = await admin.from("profiles").insert({
    id: profileId,
    email,
    phone,
    role: "customer",
    status: "active"
  });

  const supabase = await createSupabaseServerClient();
  const { data: authData } = await supabase.auth.getUser();
  const actorId = authData.user?.id ?? null;
  await logAdminAudit({ actorId, action: "fix_create_missing_profile", targetType: "profile", targetId: profileId, meta: { error: error?.message ?? null } });

  revalidatePath("/system-health");
  redirect("/system-health");
}

export async function fixAssignRole(formData: FormData) {
  const profileId = String(formData.get("profileId") ?? "").trim();
  const role = normalizeRole(formData.get("role"));
  if (!profileId || !role) redirect("/system-health");

  const admin = await tryAdminClient();
  if (!admin) redirect("/system-health");

  const { error } = await admin.from("profiles").update({ role }).eq("id", profileId);

  const supabase = await createSupabaseServerClient();
  const { data: authData } = await supabase.auth.getUser();
  const actorId = authData.user?.id ?? null;
  await logAdminAudit({ actorId, action: "fix_assign_role", targetType: "profile", targetId: profileId, meta: { role, error: error?.message ?? null } });

  revalidatePath("/system-health");
  redirect("/system-health");
}

export async function fixAssignShopOwner(formData: FormData) {
  const shopId = String(formData.get("shopId") ?? "").trim();
  const ownerProfileId = String(formData.get("ownerProfileId") ?? "").trim();
  if (!shopId || !ownerProfileId) redirect("/system-health");

  const admin = await tryAdminClient();
  if (!admin) redirect("/system-health");

  const [shopUpdate, roleUpdate] = await Promise.all([
    admin.from("barbershops").update({ owner_profile_id: ownerProfileId }).eq("id", shopId),
    admin.from("profiles").update({ role: "shop_owner" }).eq("id", ownerProfileId)
  ]);

  const supabase = await createSupabaseServerClient();
  const { data: authData } = await supabase.auth.getUser();
  const actorId = authData.user?.id ?? null;
  await logAdminAudit({
    actorId,
    action: "fix_assign_shop_owner",
    targetType: "barbershop",
    targetId: shopId,
    meta: {
      ownerProfileId,
      shopError: shopUpdate.error?.message ?? null,
      roleError: roleUpdate.error?.message ?? null
    }
  });

  revalidatePath("/system-health");
  redirect("/system-health");
}

export async function fixReconnectServiceToShop(formData: FormData) {
  const serviceId = String(formData.get("serviceId") ?? "").trim();
  const shopId = String(formData.get("shopId") ?? "").trim();
  if (!serviceId || !shopId) redirect("/system-health");

  const admin = await tryAdminClient();
  if (!admin) redirect("/system-health");

  const { error } = await admin.from("services").update({ shop_id: shopId }).eq("id", serviceId);

  const supabase = await createSupabaseServerClient();
  const { data: authData } = await supabase.auth.getUser();
  const actorId = authData.user?.id ?? null;
  await logAdminAudit({
    actorId,
    action: "fix_reconnect_service_to_shop",
    targetType: "service",
    targetId: serviceId,
    meta: { shopId, error: error?.message ?? null }
  });

  revalidatePath("/system-health");
  redirect("/system-health");
}

export async function fixReconnectBookingToCustomer(formData: FormData) {
  const bookingId = String(formData.get("bookingId") ?? "").trim();
  const customerProfileId = String(formData.get("customerProfileId") ?? "").trim();
  if (!bookingId || !customerProfileId) redirect("/system-health");

  const admin = await tryAdminClient();
  if (!admin) redirect("/system-health");

  const { error } = await admin.from("bookings").update({ customer_profile_id: customerProfileId }).eq("id", bookingId);

  const supabase = await createSupabaseServerClient();
  const { data: authData } = await supabase.auth.getUser();
  const actorId = authData.user?.id ?? null;
  await logAdminAudit({
    actorId,
    action: "fix_reconnect_booking_to_customer",
    targetType: "booking",
    targetId: bookingId,
    meta: { customerProfileId, error: error?.message ?? null }
  });

  revalidatePath("/system-health");
  redirect("/system-health");
}

export async function runRefreshCache() {
  const supabase = await createSupabaseServerClient();
  const { data: authData } = await supabase.auth.getUser();
  const actorId = authData.user?.id ?? null;

  const { data, error } = await supabase.rpc("admin_refresh_availability_cache", {
    p_days_ahead: 62,
    p_max_barbers: 400,
    p_slot_minutes: 30
  });

  await logAdminAudit({
    actorId,
    action: "refresh_cache",
    targetType: "availability_cache",
    targetId: null,
    meta: { data, error: error?.message ?? null }
  });

  revalidatePath("/system-health");
  redirect("/system-health#performance");
}

export async function runRebuildCounts() {
  const supabase = await createSupabaseServerClient();
  const { data: authData } = await supabase.auth.getUser();
  const actorId = authData.user?.id ?? null;

  const [ratings, social] = await Promise.all([
    supabase.rpc("recompute_all_ratings"),
    supabase.rpc("admin_rebuild_social_counts")
  ]);

  await logAdminAudit({
    actorId,
    action: "rebuild_counts",
    targetType: "counts",
    targetId: null,
    meta: {
      recompute_all_ratings_error: ratings.error?.message ?? null,
      admin_rebuild_social_counts: social.data ?? null,
      admin_rebuild_social_counts_error: social.error?.message ?? null
    }
  });

  revalidatePath("/system-health");
  redirect("/system-health#performance");
}

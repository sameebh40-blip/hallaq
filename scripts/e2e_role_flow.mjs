import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { createClient } from "@supabase/supabase-js";

function parseEnvValue(value) {
  const trimmed = String(value ?? "").trim();
  if (!trimmed) return "";
  const unquoted =
    (trimmed.startsWith('"') && trimmed.endsWith('"')) || (trimmed.startsWith("'") && trimmed.endsWith("'"))
      ? trimmed.slice(1, -1)
      : trimmed;
  return unquoted.trim();
}

function decodeJwtPayload(jwt) {
  const parts = String(jwt ?? "").split(".");
  if (parts.length < 2) return null;
  const raw = parts[1].replace(/-/g, "+").replace(/_/g, "/");
  const pad = raw.length % 4 === 0 ? "" : "=".repeat(4 - (raw.length % 4));
  const json = Buffer.from(raw + pad, "base64").toString("utf8");
  try {
    return JSON.parse(json);
  } catch {
    return null;
  }
}

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return;
  const raw = fs.readFileSync(filePath, "utf8");
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const idx = trimmed.indexOf("=");
    if (idx <= 0) continue;
    const key = trimmed.slice(0, idx).trim();
    const val = parseEnvValue(trimmed.slice(idx + 1));
    if (!key) continue;
    if (process.env[key]) continue;
    process.env[key] = val;
  }
}

function randomEmail(prefix) {
  const ts = new Date().toISOString().replace(/[-:.TZ]/g, "");
  const rnd = Math.random().toString(16).slice(2, 8);
  return `${prefix}+${ts}${rnd}@hallaq.test`;
}

async function getProfileRole(supabase, userId) {
  const { data, error } = await supabase.from("profiles").select("role").eq("id", userId).maybeSingle();
  if (error) throw error;
  return data?.role ?? null;
}

async function ensureProfile(supabase, { id, email, full_name }) {
  const { data, error } = await supabase.from("profiles").select("id").eq("id", id).maybeSingle();
  if (error) throw error;
  if (data?.id) return;
  const { error: insertError } = await supabase
    .from("profiles")
    .insert({ id, email: email ?? null, full_name: full_name ?? "", role: "customer", status: "active" });
  if (insertError) throw insertError;
}

async function setRole(supabase, userId, role) {
  const { error } = await supabase.from("profiles").update({ role }).eq("id", userId);
  if (error) throw error;
}

async function upsertBarber(supabase, userId) {
  const { data: p, error: pErr } = await supabase.from("profiles").select("full_name, area").eq("id", userId).maybeSingle();
  if (pErr) throw pErr;
  const displayName = typeof p?.full_name === "string" ? p.full_name : "";
  const area = typeof p?.area === "string" ? p.area : null;

  const { error } = await supabase.from("barbers").upsert(
    {
      profile_id: userId,
      display_name: displayName,
      area,
      is_independent: true
    },
    { onConflict: "profile_id" }
  );
  if (error) throw error;
}

async function ensureShop(supabase, userId) {
  const { data: existing, error: eErr } = await supabase
    .from("barbershops")
    .select("id")
    .eq("owner_profile_id", userId)
    .order("created_at", { ascending: true })
    .limit(1)
    .maybeSingle();
  if (eErr) throw eErr;
  if (existing?.id) return existing.id;

  const { data: p, error: pErr } = await supabase.from("profiles").select("full_name").eq("id", userId).maybeSingle();
  if (pErr) throw pErr;
  const name = typeof p?.full_name === "string" ? p.full_name : "";

  const { data, error } = await supabase.from("barbershops").insert({ owner_profile_id: userId, name }).select("id").single();
  if (error) throw error;
  return data.id;
}

async function insertRepairLog(supabase, adminId, repairType, targetTable, targetId, beforeData, afterData, status = "success") {
  const { error } = await supabase.from("repair_logs").insert({
    admin_id: adminId,
    repair_type: repairType,
    target_table: targetTable,
    target_id: targetId,
    before_data: beforeData,
    after_data: afterData,
    status
  });
  if (error) throw error;
}

async function main() {
  const repoRoot = path.resolve(process.cwd());
  loadEnvFile(path.join(repoRoot, "apps", "admin", ".env.local"));
  loadEnvFile(path.join(repoRoot, ".env.local"));
  loadEnvFile(path.join(repoRoot, ".env"));

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";
  if (!url) throw new Error("Missing NEXT_PUBLIC_SUPABASE_URL in env.");
  if (!serviceRoleKey) throw new Error("Missing SUPABASE_SERVICE_ROLE_KEY in env. Add it to apps/admin/.env.local");

  const payload = decodeJwtPayload(serviceRoleKey);
  const jwtRole = payload?.role ?? null;
  if (jwtRole !== "service_role") {
    throw new Error(
      `SUPABASE_SERVICE_ROLE_KEY is not a service_role JWT (detected role=${jwtRole ?? "unknown"}). Replace it with the real Supabase service_role key.`
    );
  }

  const supabase = createClient(url, serviceRoleKey, {
    global: {
      headers: {
        Authorization: `Bearer ${serviceRoleKey}`,
        apikey: serviceRoleKey
      }
    },
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
  });

  const password = "HallaqTest!1234";
  const adminEmail = randomEmail("e2e-admin");
  const userEmail = randomEmail("e2e-user");

  const { data: adminUser, error: adminErr } = await supabase.auth.admin.createUser({
    email: adminEmail,
    password,
    email_confirm: true,
    user_metadata: { full_name: "E2E Admin" }
  });
  if (adminErr) throw adminErr;
  const adminId = adminUser.user.id;

  const { data: normalUser, error: userErr } = await supabase.auth.admin.createUser({
    email: userEmail,
    password,
    email_confirm: true,
    user_metadata: { full_name: "E2E User" }
  });
  if (userErr) throw userErr;
  const userId = normalUser.user.id;

  await ensureProfile(supabase, { id: adminId, email: adminEmail, full_name: "E2E Admin" });
  await ensureProfile(supabase, { id: userId, email: userEmail, full_name: "E2E User" });

  await setRole(supabase, adminId, "admin");
  await insertRepairLog(supabase, adminId, "e2e_setup", "profiles", adminId, { role: "customer" }, { role: "admin" }, "success");

  const initialRole = await getProfileRole(supabase, userId);

  await setRole(supabase, userId, "barber");
  await upsertBarber(supabase, userId);
  await insertRepairLog(
    supabase,
    adminId,
    "e2e_promote_barber",
    "profiles",
    userId,
    { role: initialRole },
    { role: "barber", barber_row: true },
    "success"
  );

  const barberRole = await getProfileRole(supabase, userId);

  await setRole(supabase, userId, "customer");
  await insertRepairLog(
    supabase,
    adminId,
    "e2e_demote_customer",
    "profiles",
    userId,
    { role: barberRole },
    { role: "customer" },
    "success"
  );

  await setRole(supabase, userId, "shop_owner");
  const shopId = await ensureShop(supabase, userId);
  await insertRepairLog(
    supabase,
    adminId,
    "e2e_promote_shop_owner",
    "barbershops",
    shopId,
    { role: "customer" },
    { role: "shop_owner", shop_id: shopId },
    "success"
  );

  await setRole(supabase, userId, "admin");
  await insertRepairLog(
    supabase,
    adminId,
    "e2e_promote_admin",
    "profiles",
    userId,
    { role: "shop_owner" },
    { role: "admin" },
    "success"
  );

  const finalRole = await getProfileRole(supabase, userId);

  const { data: repairCount, error: countErr } = await supabase
    .from("repair_logs")
    .select("id", { count: "exact", head: true })
    .eq("admin_id", adminId);
  if (countErr) throw countErr;

  console.log(JSON.stringify({ adminEmail, userEmail, password, userId, adminId, initialRole, finalRole, repairLogsWritten: repairCount }, null, 2));
}

main().catch((e) => {
  console.error(JSON.stringify({ message: e?.message ?? String(e), details: e }, null, 2));
  process.exitCode = 1;
});

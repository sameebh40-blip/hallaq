import "server-only";

import { createClient } from "@supabase/supabase-js";

import { SupabaseNotConfiguredError } from "./env";

export class SupabaseServiceRoleNotConfiguredError extends Error {
  name = "SupabaseServiceRoleNotConfiguredError";

  constructor(message?: string) {
    super(message ?? "Supabase service role key is not configured.");
  }
}

function parseEnvValue(value: string) {
  const trimmed = value.trim();
  if (!trimmed) return "";
  const unquoted =
    (trimmed.startsWith('"') && trimmed.endsWith('"')) || (trimmed.startsWith("'") && trimmed.endsWith("'"))
      ? trimmed.slice(1, -1)
      : trimmed;
  return unquoted.trim();
}

function tryReadServiceRoleFromEnvFile(fs: typeof import("node:fs"), filePath: string) {
  try {
    if (!fs.existsSync(filePath)) return "";
    const raw = fs.readFileSync(filePath, "utf8");
    for (const line of raw.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const idx = trimmed.indexOf("=");
      if (idx <= 0) continue;
      const key = trimmed.slice(0, idx).trim();
      if (key !== "SUPABASE_SERVICE_ROLE_KEY") continue;
      return parseEnvValue(trimmed.slice(idx + 1));
    }
    return "";
  } catch {
    return "";
  }
}

export async function createSupabaseAdminClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
  let serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";
  if (!url) throw new SupabaseNotConfiguredError();
  if (!serviceRoleKey) {
    try {
      const fs = await import("node:fs");
      const path = await import("node:path");

      const baseDirs: string[] = [];
      const pushDir = (value: string | undefined) => {
        const v = (value ?? "").trim();
        if (v) baseDirs.push(v);
      };

      pushDir(process.cwd());
      pushDir(process.env.INIT_CWD);

      const candidates: string[] = [];
      for (const base of baseDirs) {
        let current = base;
        for (let i = 0; i < 6; i += 1) {
          candidates.push(path.join(current, ".env.local"));
          candidates.push(path.join(current, ".env"));
          candidates.push(path.join(current, "apps", "admin", ".env.local"));
          candidates.push(path.join(current, "apps", "admin", ".env"));
          const parent = path.resolve(current, "..");
          if (parent === current) break;
          current = parent;
        }
      }

      for (const filePath of candidates) {
        const value = tryReadServiceRoleFromEnvFile(fs, filePath);
        if (value) {
          serviceRoleKey = value;
          break;
        }
      }
    } catch {
      serviceRoleKey = "";
    }
  }
  if (!serviceRoleKey) {
    throw new SupabaseServiceRoleNotConfiguredError(
      "Supabase service role key is not configured. Add SUPABASE_SERVICE_ROLE_KEY to apps/admin/.env.local and restart the dev server."
    );
  }

  return createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false
    }
  });
}

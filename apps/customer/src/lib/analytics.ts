"use client";

import { createAppSupabaseBrowserClient } from "@/lib/supabase-browser";

function randomId() {
  try {
    if (typeof crypto !== "undefined" && "randomUUID" in crypto) return (crypto as Crypto).randomUUID();
  } catch {}
  return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

export function getSessionId() {
  if (typeof window === "undefined") return "server";
  const key = "hallaq_session_id_v1";
  const existing = window.localStorage.getItem(key);
  if (existing && existing.trim()) return existing;
  const next = randomId();
  window.localStorage.setItem(key, next);
  return next;
}

function detectOs(userAgent: string) {
  const ua = userAgent.toLowerCase();
  if (ua.includes("android")) return { os_name: "android", os_version: "" };
  if (ua.includes("iphone") || ua.includes("ipad") || ua.includes("ios")) return { os_name: "ios", os_version: "" };
  if (ua.includes("windows")) return { os_name: "windows", os_version: "" };
  if (ua.includes("mac os")) return { os_name: "macos", os_version: "" };
  if (ua.includes("linux")) return { os_name: "linux", os_version: "" };
  return { os_name: "unknown", os_version: "" };
}

export async function trackAnalyticsEvent({
  event_name,
  entity_type,
  entity_id,
  meta
}: {
  event_name: string;
  entity_type?: string | null;
  entity_id?: string | null;
  meta?: Record<string, unknown>;
}) {
  const supabase = createAppSupabaseBrowserClient();
  const ua = typeof navigator !== "undefined" ? navigator.userAgent : "";
  const os = detectOs(ua);

  await supabase.from("analytics_events").insert({
    event_name,
    entity_type: entity_type ?? "generic",
    entity_id: entity_id ?? null,
    meta: meta ?? {},
    session_id: getSessionId(),
    platform: "web",
    app_version: process.env.NEXT_PUBLIC_APP_VERSION ?? "unknown",
    os_name: os.os_name,
    os_version: os.os_version,
    device_model: ua || "unknown"
  });
}

export async function trackOnce(key: string, payload: Parameters<typeof trackAnalyticsEvent>[0]) {
  if (typeof window === "undefined") return;
  const storageKey = `hallaq_analytics_once_${key}`;
  if (window.sessionStorage.getItem(storageKey) === "1") return;
  window.sessionStorage.setItem(storageKey, "1");
  try {
    await trackAnalyticsEvent(payload);
  } catch {}
}


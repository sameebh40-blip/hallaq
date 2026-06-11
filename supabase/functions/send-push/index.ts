import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type Payload = {
  notification_id?: string;
  profile_id: string;
  type?: string;
  title?: string;
  body?: string;
  data?: Record<string, unknown> | null;
  created_at?: string;
};

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type, x-hallaq-secret",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json",
    },
  });
}

async function getDeviceTokens(profileId: string) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceKey) {
    throw new Error("Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY");
  }

  const url = new URL("/rest/v1/device_tokens", supabaseUrl);
  url.searchParams.set("select", "token,platform");
  url.searchParams.set("profile_id", `eq.${profileId}`);
  url.searchParams.set("enabled", "eq.true");

  const res = await fetch(url.toString(), {
    headers: {
      apikey: serviceKey,
      authorization: `Bearer ${serviceKey}`,
    },
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`device_tokens query failed: ${res.status} ${text}`);
  }
  const rows = (await res.json()) as Array<{ token: string; platform: string }>;
  return rows.map((r) => r.token).filter((t) => (t ?? "").trim().length > 0);
}

async function sendFcm(tokens: string[], payload: Payload) {
  const serverKey = Deno.env.get("FCM_SERVER_KEY") ?? "";
  if (!serverKey) throw new Error("Missing FCM_SERVER_KEY");
  if (tokens.length === 0) return { sent: 0, success: 0, failure: 0 };

  const title = payload.title ?? "";
  const body = payload.body ?? "";
  const data: Record<string, string> = {};
  const raw = payload.data ?? {};
  for (const [k, v] of Object.entries(raw)) {
    if (v === null || v === undefined) continue;
    data[k] = typeof v === "string" ? v : JSON.stringify(v);
  }
  if (payload.notification_id) data.notification_id = payload.notification_id;
  if (payload.type) data.type = payload.type;

  const res = await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      authorization: `key=${serverKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      registration_ids: tokens,
      priority: "high",
      notification: { title, body },
      data,
    }),
  });

  const text = await res.text();
  if (!res.ok) {
    throw new Error(`FCM send failed: ${res.status} ${text}`);
  }
  const out = JSON.parse(text) as { success?: number; failure?: number };
  return {
    sent: tokens.length,
    success: out.success ?? 0,
    failure: out.failure ?? 0,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const expectedSecret = (Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "").trim();
  if (expectedSecret) {
    const got = (req.headers.get("x-hallaq-secret") ?? "").trim();
    if (got !== expectedSecret) return jsonResponse({ error: "unauthorized" }, 401);
  }

  let payload: Payload;
  try {
    payload = (await req.json()) as Payload;
  } catch (_) {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const profileId = (payload.profile_id ?? "").trim();
  if (!profileId) return jsonResponse({ error: "missing_profile_id" }, 400);

  try {
    const tokens = await getDeviceTokens(profileId);
    const result = await sendFcm(tokens, payload);
    return jsonResponse({ ok: true, ...result });
  } catch (e) {
    return jsonResponse({ ok: false, error: String(e) }, 500);
  }
});


import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { SignJWT, importPKCS8 } from "https://esm.sh/jose@5.9.6";

type PushRequest = {
  notification_id: string;
  profile_id: string;
  type?: string;
  title?: string;
  body?: string;
  data?: Record<string, unknown> | null;
  created_at?: string;
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

async function sendFcmLegacy({
  serverKey,
  tokens,
  title,
  body,
  data,
}: {
  serverKey: string;
  tokens: string[];
  title: string;
  body: string;
  data: Record<string, unknown>;
}) {
  const res = await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      authorization: `key=${serverKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      registration_ids: tokens,
      priority: "high",
      notification: {
        title,
        body,
      },
      data,
    }),
  });

  const text = await res.text();
  if (!res.ok) {
    throw new Error(`FCM_ERROR_${res.status}:${text}`);
  }
  return text;
}

type ServiceAccount = {
  project_id?: string;
  client_email?: string;
  private_key?: string;
};

function baseData(payload: PushRequest) {
  return {
    notification_id: payload.notification_id,
    type: payload.type ?? "generic",
    ...(payload.data ?? {}),
  } as Record<string, unknown>;
}

async function getGoogleAccessTokenFromServiceAccount(sa: ServiceAccount) {
  const clientEmail = (sa.client_email ?? "").trim();
  const privateKey = (sa.private_key ?? "").trim();
  if (!clientEmail || !privateKey) throw new Error("SERVICE_ACCOUNT_INVALID");
  const key = await importPKCS8(privateKey, "RS256");
  const now = Math.floor(Date.now() / 1000);
  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(clientEmail)
    .setSubject(clientEmail)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const json = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`GOOGLE_TOKEN_ERROR_${res.status}:${JSON.stringify(json)}`);
  const token = (json?.access_token ?? "").toString();
  if (!token) throw new Error("GOOGLE_TOKEN_MISSING");
  return token;
}

async function sendFcmV1({
  accessToken,
  projectId,
  tokens,
  title,
  body,
  data,
}: {
  accessToken: string;
  projectId: string;
  tokens: string[];
  title: string;
  body: string;
  data: Record<string, unknown>;
}) {
  let sent = 0;
  for (const token of tokens) {
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
        },
      }),
    });

    const text = await res.text();
    if (!res.ok) throw new Error(`FCM_V1_ERROR_${res.status}:${text}`);
    sent += 1;
  }
  return sent;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return jsonResponse(405, { error: "METHOD_NOT_ALLOWED" });

  const secretHeader = req.headers.get("x-hallaq-secret") ?? "";
  const expectedSecret = Deno.env.get("PUSH_SECRET") ?? "";
  if (expectedSecret && secretHeader !== expectedSecret) return jsonResponse(401, { error: "UNAUTHORIZED" });

  let payload: PushRequest;
  try {
    payload = (await req.json()) as PushRequest;
  } catch (_) {
    return jsonResponse(400, { error: "BAD_JSON" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRoleKey) return jsonResponse(500, { error: "SUPABASE_ENV_MISSING" });

  const supabase = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } });

  const { data: tokensRows, error: tokensError } = await supabase
    .from("device_tokens")
    .select("token, enabled")
    .eq("profile_id", payload.profile_id)
    .eq("enabled", true);

  if (tokensError) return jsonResponse(500, { error: "TOKENS_QUERY_FAILED", details: String(tokensError.message ?? tokensError) });

  const tokens = (tokensRows ?? []).map((r) => r.token).filter((t) => typeof t === "string" && t.length > 0);
  if (tokens.length == 0) return jsonResponse(200, { ok: true, sent: 0 });

  const title = (payload.title ?? "").trim() || "Hallaq";
  const body = (payload.body ?? "").trim();
  const data = baseData(payload);

  const fcmServerKey = Deno.env.get("FCM_SERVER_KEY") ?? "";
  const serviceAccountJson = (Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") ?? "").trim();

  try {
    if (fcmServerKey) {
      await sendFcmLegacy({ serverKey: fcmServerKey, tokens, title, body, data });
      return jsonResponse(200, { ok: true, sent: tokens.length, mode: "legacy" });
    }
    if (serviceAccountJson) {
      const sa = JSON.parse(serviceAccountJson) as ServiceAccount;
      const projectId = (sa.project_id ?? "").trim();
      if (!projectId) throw new Error("SERVICE_ACCOUNT_PROJECT_ID_MISSING");
      const accessToken = await getGoogleAccessTokenFromServiceAccount(sa);
      const sent = await sendFcmV1({ accessToken, projectId, tokens, title, body, data });
      return jsonResponse(200, { ok: true, sent, mode: "v1" });
    }
    return jsonResponse(200, { ok: true, sent: 0, note: "FCM_CONFIG_MISSING" });
  } catch (e) {
    return jsonResponse(500, { error: "PUSH_SEND_FAILED", details: String(e) });
  }
});

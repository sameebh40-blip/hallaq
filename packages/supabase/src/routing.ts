export type HallaqRoutingMode = "path" | "subdomain";

export type HallaqRole = "customer" | "barber" | "shop_owner" | "receptionist" | "admin";

export type HallaqAppKey = "landing" | "app" | "business" | "admin" | "api";

function normalizeOrigin(v: string | undefined | null) {
  const out = (v ?? "").trim().replace(/\/+$/, "");
  return out.length ? out : null;
}

function ensureLeadingSlash(v: string) {
  if (!v.startsWith("/")) return `/${v}`;
  return v;
}

export function getHallaqRoutingMode(): HallaqRoutingMode {
  const raw = (process.env.NEXT_PUBLIC_HALLAQ_ROUTING_MODE ?? "").trim().toLowerCase();
  if (raw === "subdomain") return "subdomain";
  return "path";
}

export function getHallaqAppOrigins() {
  const landing = normalizeOrigin(process.env.NEXT_PUBLIC_LANDING_URL);
  const app = normalizeOrigin(process.env.NEXT_PUBLIC_APP_URL);
  const business = normalizeOrigin(process.env.NEXT_PUBLIC_BUSINESS_URL);
  const admin = normalizeOrigin(process.env.NEXT_PUBLIC_ADMIN_URL);
  const api = normalizeOrigin(process.env.NEXT_PUBLIC_API_URL);

  return { landing, app, business, admin, api };
}

export function getHallaqBasePaths() {
  const shopBasePath = ensureLeadingSlash((process.env.NEXT_PUBLIC_SHOP_BASE_PATH ?? "/shop").trim() || "/shop");
  const adminBasePath = ensureLeadingSlash((process.env.NEXT_PUBLIC_ADMIN_BASE_PATH ?? "/admin").trim() || "/admin");
  return { shopBasePath, adminBasePath };
}

export function getRoleHomePath(role: string | null | undefined, opts?: { shopBasePath?: string; adminBasePath?: string }) {
  const { shopBasePath, adminBasePath } = { ...getHallaqBasePaths(), ...(opts ?? {}) };

  switch (role) {
    case "admin":
      return adminBasePath;
    case "shop_owner":
      return `${shopBasePath}/dashboard`;
    case "receptionist":
      return `${shopBasePath}/reception`;
    case "barber":
      return "/barber-dashboard";
    case "customer":
    default:
      return "/home";
  }
}

export function getRoleHomeUrl(role: string | null | undefined, requestUrl: string | URL) {
  const mode = getHallaqRoutingMode();
  const base = typeof requestUrl === "string" ? new URL(requestUrl) : new URL(requestUrl);

  if (mode === "path") {
    return new URL(getRoleHomePath(role), base);
  }

  const { landing, app, business, admin } = getHallaqAppOrigins();

  if (role === "admin" && admin) return new URL("/", admin);
  if ((role === "shop_owner" || role === "receptionist") && business) return new URL("/", business);
  if (role === "customer" && app) return new URL("/home", app);
  if (role === "barber" && app) return new URL("/barber-dashboard", app);
  if (app) return new URL("/home", app);
  if (landing) return new URL("/", landing);
  return new URL(getRoleHomePath(role), base);
}

export function getAppOrigin(key: HallaqAppKey, requestUrl: string | URL) {
  const mode = getHallaqRoutingMode();
  const { landing, app, business, admin, api } = getHallaqAppOrigins();
  const base = typeof requestUrl === "string" ? new URL(requestUrl) : new URL(requestUrl);

  if (mode === "path") return base.origin;

  switch (key) {
    case "landing":
      return landing ?? base.origin;
    case "app":
      return app ?? base.origin;
    case "business":
      return business ?? base.origin;
    case "admin":
      return admin ?? base.origin;
    case "api":
      return api ?? base.origin;
  }
}


import type { NextConfig } from "next";
import path from "node:path";

const routingMode = (process.env.NEXT_PUBLIC_HALLAQ_ROUTING_MODE ?? "path").toLowerCase();
const configuredBasePath = (process.env.NEXT_PUBLIC_SHOP_BASE_PATH ?? "/shop").trim() || "/shop";
const basePath = routingMode === "subdomain" ? "" : configuredBasePath;

const nextConfig: NextConfig = {
  ...(basePath ? { basePath } : {}),
  outputFileTracingRoot: path.join(__dirname, "../.."),
  transpilePackages: ["@hallaq/ui", "@hallaq/supabase", "@hallaq/brand-assets"],
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "**.supabase.co" },
      { protocol: "https", hostname: "**.supabase.in" }
    ]
  }
};

export default nextConfig;

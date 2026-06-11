import type { NextConfig } from "next";
import path from "node:path";

const enableAdminRedirect = process.env.ADMIN_ENABLE_ADMIN_REDIRECT !== "false";

const nextConfig: NextConfig = {
  distDir: process.env.NODE_ENV === "production" ? ".next-build" : ".next",
  outputFileTracingRoot: path.join(__dirname, "../.."),
  transpilePackages: ["@hallaq/ui", "@hallaq/supabase", "@hallaq/feature-flags", "@hallaq/brand-assets"],
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "**.supabase.co" },
      { protocol: "https", hostname: "**.supabase.in" }
    ]
  },
  async redirects() {
    if (!enableAdminRedirect) return [];
    return [{ source: "/admin/:path*", destination: "/:path*", permanent: false }];
  }
};

export default nextConfig;

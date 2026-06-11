import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  const base = process.env.NEXT_PUBLIC_LANDING_URL ?? "https://hallaq.com";
  return {
    rules: [{ userAgent: "*", allow: "/" }],
    sitemap: `${base.replace(/\/+$/, "")}/sitemap.xml`
  };
}


import type { ReactNode } from "react";
import { cookies } from "next/headers";

import "@hallaq/ui/styles.css";
import "./globals.css";

import { HallaqProviders } from "@hallaq/ui/providers";

import { FeatureFlagsBootstrap } from "@/components/feature-flags-bootstrap";
import { ServiceWorkerRegister } from "@/components/service-worker-register";

export const viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#000000"
};

export const metadata = {
  applicationName: "Hallaq Admin",
  manifest: "/manifest.webmanifest",
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "Hallaq Admin"
  },
  icons: {
    icon: [
      { url: "/pwa/icon-192", sizes: "192x192", type: "image/png" },
      { url: "/pwa/icon-512", sizes: "512x512", type: "image/png" }
    ],
    apple: [{ url: "/pwa/apple-touch-icon", sizes: "180x180", type: "image/png" }]
  }
};

export default async function RootLayout({ children }: { children: ReactNode }) {
  const cookieStore = await cookies();
  const locale = cookieStore.get("hallaq_locale")?.value === "en" ? "en" : "ar";
  const dir = locale === "ar" ? "rtl" : "ltr";

  return (
    <html lang={locale} dir={dir} suppressHydrationWarning>
      <body>
        <HallaqProviders locale={locale}>
          <ServiceWorkerRegister />
          <FeatureFlagsBootstrap>{children}</FeatureFlagsBootstrap>
        </HallaqProviders>
      </body>
    </html>
  );
}

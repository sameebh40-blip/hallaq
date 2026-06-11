import type { ReactNode } from "react";
import { cookies } from "next/headers";

import "@hallaq/ui/styles.css";
import "./theme.css";
import "./globals.css";

import { HallaqProviders } from "@hallaq/ui/providers";

import { FeatureFlagsBootstrap } from "@/components/feature-flags-bootstrap";
import { QaModeBanner } from "@/components/qa-mode-banner";
import { ServiceWorkerRegister } from "@/components/service-worker-register";

export const viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#000000"
};

export const metadata = {
  applicationName: "Hallaq City",
  manifest: "/manifest.webmanifest",
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "Hallaq City"
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
  const qaActive = cookieStore.get("hallaq_qa_active")?.value === "1";

  return (
    <html lang={locale} dir={dir} suppressHydrationWarning>
      <body className={qaActive ? "pt-10" : undefined}>
        <HallaqProviders locale={locale}>
          <ServiceWorkerRegister />
          {qaActive ? <QaModeBanner exitTo="/admin/qa-mode" /> : null}
          <FeatureFlagsBootstrap>
            <div className="min-h-dvh bg-background text-foreground">
              <div className="mx-auto min-h-dvh w-full max-w-[430px] lg:my-6 lg:min-h-[calc(100dvh-3rem)] lg:overflow-hidden lg:rounded-[28px] lg:border lg:border-border lg:bg-background lg:shadow-[0_30px_80px_rgba(0,0,0,0.55)]">
                {children}
              </div>
            </div>
          </FeatureFlagsBootstrap>
        </HallaqProviders>
      </body>
    </html>
  );
}

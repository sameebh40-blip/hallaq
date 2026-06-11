import type { ReactNode } from "react";

import "@hallaq/ui/styles.css";
import "./globals.css";

const landingUrl = process.env.NEXT_PUBLIC_LANDING_URL ?? "https://hallaq.com";

export const viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#000000"
};

export const metadata = {
  metadataBase: new URL(landingUrl),
  title: {
    default: "HALLAQ",
    template: "%s • HALLAQ"
  },
  description: "Book barbers, discover shops, and manage your business with HALLAQ.",
  alternates: { canonical: "/" },
  openGraph: {
    type: "website",
    url: landingUrl,
    title: "HALLAQ",
    description: "Book barbers, discover shops, and manage your business with HALLAQ.",
    siteName: "HALLAQ"
  },
  twitter: {
    card: "summary_large_image",
    title: "HALLAQ",
    description: "Book barbers, discover shops, and manage your business with HALLAQ."
  }
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" dir="ltr" suppressHydrationWarning>
      <body>
        <div className="min-h-dvh bg-background text-foreground">{children}</div>
      </body>
    </html>
  );
}


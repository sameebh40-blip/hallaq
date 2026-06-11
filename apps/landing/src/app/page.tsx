import Link from "next/link";

import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

const appUrl = process.env.NEXT_PUBLIC_APP_URL ?? "https://app.hallaq.com";
const businessUrl = process.env.NEXT_PUBLIC_BUSINESS_URL ?? "https://business.hallaq.com";

export default function LandingPage() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "Organization",
    name: "HALLAQ",
    url: process.env.NEXT_PUBLIC_LANDING_URL ?? "https://hallaq.com",
    sameAs: [],
    description: "Book barbers, discover shops, and manage your business with HALLAQ."
  };

  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-6xl flex-col gap-10 px-6 py-12">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />

      <header className="flex flex-col gap-4">
        <div className="text-xs font-semibold tracking-[0.3em] text-primary">HALLAQ</div>
        <h1 className="text-3xl font-semibold tracking-tight sm:text-5xl">
          The platform for bookings, barbers, and modern shop operations
        </h1>
        <p className="max-w-2xl text-base text-muted-foreground sm:text-lg">
          Customers book instantly. Shops manage schedules, services, staff, and media. Admins keep the ecosystem healthy
          and secure.
        </p>
        <div className="flex flex-wrap gap-3 pt-2">
          <Button asChild size="lg">
            <Link href={appUrl}>Open App</Link>
          </Button>
          <Button asChild size="lg" variant="secondary">
            <Link href={businessUrl}>Business Portal</Link>
          </Button>
        </div>
      </header>

      <section className="grid gap-4 md:grid-cols-3">
        <LuxuryCard className="p-5">
          <div className="text-sm font-semibold">Customer app</div>
          <div className="pt-1 text-sm text-muted-foreground">
            Discover shops, browse barbers, and manage bookings with a mobile-first experience.
          </div>
        </LuxuryCard>
        <LuxuryCard className="p-5">
          <div className="text-sm font-semibold">Business dashboard</div>
          <div className="pt-1 text-sm text-muted-foreground">
            Desktop-optimized operations hub with calendar, bookings, staff, services, products, and analytics.
          </div>
        </LuxuryCard>
        <LuxuryCard className="p-5">
          <div className="text-sm font-semibold">Admin center</div>
          <div className="pt-1 text-sm text-muted-foreground">
            Roles, audits, diagnostics, media health, and platform governance for production.
          </div>
        </LuxuryCard>
      </section>

      <footer className="flex flex-col gap-2 border-t border-border/50 pt-6 text-sm text-muted-foreground">
        <div className="flex flex-wrap gap-4">
          <Link href={`${appUrl}/auth/sign-in`} className="underline underline-offset-4">
            Sign in
          </Link>
          <Link href={`${businessUrl}/auth/sign-in`} className="underline underline-offset-4">
            Business sign in
          </Link>
          <Link href="mailto:support@hallaq.com" className="underline underline-offset-4">
            support@hallaq.com
          </Link>
        </div>
        <div>© {new Date().getFullYear()} HALLAQ</div>
      </footer>
    </main>
  );
}


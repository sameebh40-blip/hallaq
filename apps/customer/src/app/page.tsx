import Link from "next/link";
import { cookies } from "next/headers";

import { Button } from "@hallaq/ui/button";
import { HallaqGoldLogo } from "@hallaq/ui/hallaq-logo";
import { getT } from "@hallaq/ui/translations-server";

import { AnalyticsTrack } from "@/components/analytics-track";
import { SafeImageLocalized } from "@hallaq/brand-assets/react";

export default async function HomePage() {
  const t = await getT();
  const cookieStore = await cookies();
  const locale = cookieStore.get("hallaq_locale")?.value === "en" ? "en" : "ar";
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col px-4 py-8">
      <AnalyticsTrack eventName="home_view" />
      <div className="flex items-center justify-center pb-6">
        <HallaqGoldLogo className="h-16 w-16" />
      </div>

      <div className="relative overflow-hidden rounded-[28px] border bg-white shadow-soft">
        <div className="absolute inset-0">
          <SafeImageLocalized
            src={null}
            fallbackBaseKey="default_home_hero_banner"
            locale={locale}
            alt="Hallaq"
            className="h-full w-full object-cover"
          />
          <div className="absolute inset-0 bg-black/35" />
        </div>

        <div className="relative flex min-h-[520px] flex-col justify-between p-6 text-white">
          <div className="flex flex-col gap-2">
            <div className="text-xs tracking-[0.2em] opacity-90">{t("home.title")}</div>
            <div className="text-3xl font-semibold leading-tight">HALLAQ</div>
            <div className="max-w-xs text-sm opacity-90">{t("home.subtitle")}</div>
          </div>

          <div className="flex flex-col gap-3">
            <Button asChild className="h-12 w-full rounded-2xl">
              <Link href="/choose-experience">Get Started</Link>
            </Button>
            <Button asChild variant="secondary" className="h-12 w-full rounded-2xl bg-white/90 text-black hover:bg-white">
              <Link href="/auth/sign-in">I already have an account</Link>
            </Button>
          </div>
        </div>
      </div>
    </main>
  );
}

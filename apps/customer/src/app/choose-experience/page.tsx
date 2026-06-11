import Link from "next/link";

import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { SafeImage } from "@/components/safe-image";

export const dynamic = "force-dynamic";

function ExperienceCard({
  title,
  subtitle,
  href,
  imageUrl,
  fallbackKey
}: {
  title: string;
  subtitle: string;
  href: string;
  imageUrl: string;
  fallbackKey: string;
}) {
  return (
    <LuxuryCard className="overflow-hidden bg-[#111111]">
      <Link href={href} className="flex items-center gap-4 p-4">
        <div className="h-14 w-14 overflow-hidden rounded-2xl border border-[#2A2A2A] bg-black/30">
          <SafeImage src={imageUrl} fallbackKey={fallbackKey} alt="" className="h-full w-full object-cover" />
        </div>
        <div className="flex flex-1 flex-col gap-0.5">
          <div className="text-sm font-semibold text-white">{title}</div>
          <div className="text-xs font-semibold text-[#9E9E9E]">{subtitle}</div>
        </div>
        <div className="text-sm font-semibold text-[#9E9E9E]">→</div>
      </Link>
    </LuxuryCard>
  );
}

export default async function ChooseExperiencePage({
  searchParams
}: {
  searchParams?: Promise<{ barberId?: string; shopId?: string; serviceId?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const bookingHint = Boolean((params?.barberId ?? "").trim() || (params?.shopId ?? "").trim());

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-6 bg-black px-4 py-8 text-white">
      <div className="flex flex-col gap-1">
        <div className="text-sm font-semibold text-[#9E9E9E]">Welcome to HALLAQ</div>
        <h1 className="text-2xl font-extrabold">Choose your experience</h1>
        <div className="text-sm font-semibold text-[#9E9E9E]">Select how you want to continue.</div>
      </div>

      {bookingHint ? (
        <LuxuryCard className="bg-[#111111] p-4 text-white">
          <div className="text-sm font-extrabold">Booking</div>
          <div className="pt-1 text-sm font-semibold text-[#9E9E9E]">
            Booking is currently handled in the Hallaq mobile app.
          </div>
          <div className="pt-3">
            <Button asChild variant="secondary" className="w-full">
              <Link href="/home">Continue browsing</Link>
            </Button>
          </div>
        </LuxuryCard>
      ) : null}

      <div className="flex flex-col gap-3">
        <ExperienceCard
          title="I’m a Customer"
          subtitle="Book your next haircut"
          href="/home"
          imageUrl=""
          fallbackKey="default_reel_thumbnail"
        />
        <ExperienceCard
          title="I’m a Barber"
          subtitle="Manage your work & bookings"
          href="/barber-dashboard"
          imageUrl=""
          fallbackKey="default_barber_avatar"
        />
        <ExperienceCard
          title="I’m a Shop Owner"
          subtitle="Manage your shop dashboard"
          href="/shop/dashboard"
          imageUrl=""
          fallbackKey="default_shop_cover"
        />
      </div>

      <div className="pt-2">
        <Button asChild variant="ghost" className="w-full">
          <Link href="/auth/sign-in">Sign in</Link>
        </Button>
      </div>
    </main>
  );
}

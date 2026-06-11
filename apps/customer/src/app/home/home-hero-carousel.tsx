"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";

import { cn } from "@hallaq/ui/cn";
import { SafeImage } from "@/components/safe-image";

export type HomeHeroSlide = {
  id: string;
  title: string;
  subtitle: string;
  imageUrl: string | null;
  href: string;
  buttonText: string;
  fallbackKey?: string;
};

export function HomeHeroCarousel({ slides }: { slides: HomeHeroSlide[] }) {
  const [index, setIndex] = useState(0);
  const count = slides.length;
  const safeIndex = count ? ((index % count) + count) % count : 0;
  const active = slides[safeIndex];
  const ids = useMemo(() => slides.map((s) => s.id).join("|"), [slides]);

  useEffect(() => {
    if (!count) return;
    const timer = window.setInterval(() => setIndex((v) => v + 1), 5000);
    return () => window.clearInterval(timer);
  }, [count, ids]);

  if (!active) return null;

  return (
    <section className="relative">
      <Link href={active.href} className="group block overflow-hidden rounded-[24px] border border-[#2A2A2A] bg-[#111111] shadow-[0_22px_60px_rgba(0,0,0,0.55)]">
        <div className="relative aspect-[16/9] w-full overflow-hidden">
          <SafeImage
            src={active.imageUrl}
            fallbackKey={active.fallbackKey ?? "default_home_hero_banner"}
            alt={active.title}
            className="h-full w-full object-cover transition-transform duration-700 ease-out group-hover:scale-[1.02]"
          />
          <div className="absolute inset-0 bg-gradient-to-r from-black/70 via-black/20 to-transparent" />
          <div className="absolute inset-0 p-5">
            <div className="flex h-full flex-col justify-between">
              <div className="max-w-[68%]">
                <div className="text-sm font-semibold text-white/90">{active.title}</div>
                <div className="mt-2 text-3xl font-black leading-[1.0] text-[hsl(var(--gold))]">{active.subtitle}</div>
                <div className="mt-2 text-sm font-semibold text-white/70">Top barbers. Premium services. All in HALLAQ.</div>
              </div>
              <div>
                <span className="inline-flex items-center justify-center rounded-[14px] bg-[hsl(var(--gold))] px-5 py-3 text-sm font-bold text-black shadow-[0_18px_42px_rgba(212,175,55,0.28)]">
                  {active.buttonText}
                </span>
              </div>
            </div>
          </div>
        </div>
      </Link>

      <div className="mt-3 flex items-center justify-center gap-2">
        {slides.map((s, i) => {
          const selected = i === safeIndex;
          return (
            <button
              key={s.id}
              type="button"
              aria-label={s.title}
              onClick={() => setIndex(i)}
              className={cn("h-1.5 rounded-full transition-all", selected ? "w-6 bg-[hsl(var(--gold))]" : "w-2.5 bg-[#2A2A2A]")}
            />
          );
        })}
      </div>
    </section>
  );
}


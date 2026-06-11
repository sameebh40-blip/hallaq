"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";

import { cn } from "@hallaq/ui/cn";

import { SafeImage } from "@/components/safe-image";

export type HeroCarouselItem = {
  id: string;
  title: string;
  subtitle: string;
  imageUrl: string;
  href: string;
  fallbackKey?: string;
};

export function HeroCarousel({ items }: { items: HeroCarouselItem[] }) {
  const [index, setIndex] = useState(0);
  const count = items.length;
  const safeIndex = ((index % count) + count) % count;
  const active = items[safeIndex];

  const ids = useMemo(() => items.map((i) => i.id).join("|"), [items]);

  useEffect(() => {
    if (!count) return;
    const timer = window.setInterval(() => setIndex((v) => v + 1), 4500);
    return () => window.clearInterval(timer);
  }, [count, ids]);

  if (!active) return null;

  return (
    <section className="relative">
      <Link
        href={active.href}
        className="group block overflow-hidden rounded-[28px] border bg-white shadow-[0_22px_60px_rgba(17,17,17,0.10)]"
      >
        <div className="relative aspect-[16/9] w-full overflow-hidden">
          <SafeImage
            src={active.imageUrl}
            fallbackKey={active.fallbackKey ?? "default_hallaq_city_banner"}
            alt={active.title}
            className="h-full w-full object-cover transition-transform duration-700 ease-out group-hover:scale-[1.02]"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-black/10 to-transparent" />
          <div className="absolute bottom-0 left-0 right-0 p-4">
            <div className="text-[11px] font-semibold tracking-[0.24em] text-white/90">{active.title.toUpperCase()}</div>
            <div className="mt-1 text-base font-semibold leading-snug text-white">{active.subtitle}</div>
            <div className="mt-3 inline-flex items-center gap-2 rounded-full bg-white/14 px-3 py-1 text-[11px] font-semibold text-white backdrop-blur">
              <span className="h-1.5 w-1.5 rounded-full bg-[hsl(var(--gold))]" />
              View
            </div>
          </div>
        </div>
      </Link>

      <div className="mt-3 flex items-center justify-center gap-1.5">
        {items.map((it, i) => {
          const selected = i === safeIndex;
          return (
            <button
              key={it.id}
              type="button"
              aria-label={it.title}
              onClick={() => setIndex(i)}
              className={cn(
                "h-1.5 rounded-full transition-all",
                selected ? "w-5 bg-[hsl(var(--gold))]" : "w-2.5 bg-black/10 hover:bg-black/20"
              )}
            />
          );
        })}
      </div>
    </section>
  );
}

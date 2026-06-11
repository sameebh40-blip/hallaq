"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { cn } from "@hallaq/ui/cn";

type Filter = {
  key: string;
  label: string;
  href: string;
  match: (pathname: string) => boolean;
};

export function CityFilters({
  labels
}: {
  labels: {
    all: string;
    barbers: string;
    shops: string;
    styles: string;
    offers: string;
    awards: string;
    reels: string;
  };
}) {
  const pathname = usePathname();

  const filters: Filter[] = [
    { key: "all", label: labels.all, href: "/city", match: (p) => p === "/city" || p.startsWith("/city/search") },
    { key: "barbers", label: labels.barbers, href: "/city/barbers", match: (p) => p.startsWith("/city/barbers") },
    { key: "shops", label: labels.shops, href: "/city/shops/new", match: (p) => p.startsWith("/city/shops") },
    { key: "styles", label: labels.styles, href: "/city/styles", match: (p) => p.startsWith("/city/styles") },
    { key: "offers", label: labels.offers, href: "/city/offers", match: (p) => p.startsWith("/city/offers") },
    { key: "awards", label: labels.awards, href: "/city/awards", match: (p) => p.startsWith("/city/awards") },
    { key: "reels", label: labels.reels, href: "/city/reels", match: (p) => p.startsWith("/city/reels") }
  ];

  return (
    <div className="flex gap-2 overflow-x-auto pb-1">
      {filters.map((f) => {
        const active = f.match(pathname);
        return (
          <Link
            key={f.key}
            href={f.href}
            className={cn(
              "shrink-0 rounded-full border px-3 py-2 text-[12px] font-semibold leading-none transition",
              active
                ? "border-[hsl(var(--gold))] bg-[hsl(var(--gold))/0.10] text-[#111111]"
                : "border-black/10 bg-white text-muted-foreground hover:border-black/20"
            )}
          >
            {f.label}
          </Link>
        );
      })}
    </div>
  );
}


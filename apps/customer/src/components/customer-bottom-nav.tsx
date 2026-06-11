"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { cn } from "@hallaq/ui/cn";
import { useT } from "@hallaq/ui/translations-client";
import { Building2, CalendarDays, Compass, Home, User } from "lucide-react";

export function CustomerBottomNav() {
  const pathname = usePathname();
  const t = useT();

  const items = [
    { href: "/home", label: t("customer.nav.home"), Icon: Home },
    { href: "/bookings", label: t("customer.nav.bookings"), Icon: CalendarDays },
    { href: "/hallaq-city", label: "HALLAQ CITY", Icon: Building2 },
    { href: "/discover", label: t("customer.nav.discover"), Icon: Compass },
    { href: "/profile", label: t("customer.nav.profile"), Icon: User }
  ] as const;

  return (
    <nav className="fixed inset-x-0 bottom-0 z-50">
      <div className="mx-auto max-w-md px-4 pb-3">
        <div className="relative overflow-visible rounded-t-[28px] border border-[#2A2A2A] bg-[#111111]/95 px-2 pt-2 shadow-[0_-18px_44px_rgba(0,0,0,0.60)] backdrop-blur supports-[backdrop-filter]:bg-[#111111]/75">
          <div className="grid grid-cols-5">
        {items.map(({ href, label, Icon }) => {
          const active = pathname === href || pathname.startsWith(`${href}/`);
          const isCity = href === "/hallaq-city";
          const activeColor = isCity ? "text-[hsl(var(--gold))]" : "text-white";
          return (
            <Link
              key={href}
              href={href}
              className={cn(
                "flex flex-col items-center justify-end gap-1 rounded-2xl px-2 py-2 text-[11px]",
                isCity ? "pb-1 pt-0" : "pt-2",
                active ? activeColor : "text-[#9E9E9E]"
              )}
            >
              {isCity ? (
                <div
                  className={cn(
                    "-mt-6 grid h-14 w-14 place-items-center rounded-full border shadow-[0_18px_42px_rgba(17,17,17,0.14)]",
                    active
                      ? "border-[hsl(var(--gold))/0.55] bg-[#111111] text-[hsl(var(--gold))] shadow-[0_18px_42px_rgba(212,175,55,0.26)]"
                      : "border-[hsl(var(--gold))/0.35] bg-[#111111] text-[hsl(var(--gold))]"
                  )}
                >
                  <Icon className="h-6 w-6" />
                </div>
              ) : (
                <Icon className={cn("h-5 w-5", active ? "text-[hsl(var(--gold))]" : "text-[#9E9E9E]")} />
              )}
              <span className={cn("leading-none", active ? "font-semibold" : "font-medium")}>{label}</span>
            </Link>
          );
        })}
          </div>
        </div>
      </div>
    </nav>
  );
}

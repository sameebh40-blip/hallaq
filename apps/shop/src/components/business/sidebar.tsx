"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { cn } from "@hallaq/ui/cn";
import { BadgeCheck, ChevronsLeft, ChevronsRight, LogOut, Plus, Upload } from "lucide-react";

import type { BusinessNavItem } from "./nav";

export function BusinessSidebar({
  shop,
  nav,
  collapsed,
  onToggleCollapsed
}: {
  shop: { name: string; logoUrl: string | null; isVerified: boolean; area: string | null };
  nav: BusinessNavItem[];
  collapsed: boolean;
  onToggleCollapsed: () => void;
}) {
  const pathname = usePathname();

  return (
    <aside
      className={cn(
        "relative flex h-dvh shrink-0 flex-col border-r border-white/10 bg-[linear-gradient(180deg,rgba(15,15,15,0.98),rgba(5,5,5,0.98))] shadow-[28px_0_80px_rgba(0,0,0,0.45)] backdrop-blur-2xl",
        collapsed ? "w-[92px]" : "w-[308px]"
      )}
    >
      <div className={cn("flex items-center gap-3 border-b border-white/10 px-5 py-5", collapsed ? "justify-center px-3" : "")}>
        <div className="flex h-12 w-12 items-center justify-center rounded-2xl border border-[hsl(var(--gold)/0.3)] bg-[linear-gradient(180deg,rgba(255,214,77,0.28),rgba(255,214,77,0.06))] shadow-[0_18px_40px_rgba(0,0,0,0.28)]">
          <span className="text-lg font-semibold text-primary">H</span>
        </div>
        {collapsed ? null : (
          <div className="flex min-w-0 flex-col">
            <div className="flex items-center gap-2 truncate text-sm font-semibold tracking-tight text-white">
              <span className="truncate">{shop.name}</span>
              {shop.isVerified ? <BadgeCheck className="h-4 w-4 text-primary" /> : null}
            </div>
            <div className="truncate text-[11px] uppercase tracking-[0.22em] text-white/45">{shop.area ?? "Bahrain"}</div>
          </div>
        )}
        <button
          type="button"
          onClick={onToggleCollapsed}
          className={cn(
            "absolute top-5 rounded-xl border border-white/10 bg-white/[0.05] p-2 text-white/55 transition hover:bg-white/10 hover:text-white",
            collapsed ? "right-3" : "right-5"
          )}
          aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
        >
          {collapsed ? <ChevronsRight className="h-4 w-4" /> : <ChevronsLeft className="h-4 w-4" />}
        </button>
      </div>

      <div className={cn("px-5 pb-4 pt-4", collapsed ? "px-3" : "")}>
        <div className={cn("grid gap-2", collapsed ? "grid-cols-1" : "grid-cols-2")}>
          <Link
            href="/business/bookings/new"
            className={cn(
              "inline-flex h-10 items-center justify-center rounded-xl border border-[hsl(var(--gold)/0.18)] bg-[linear-gradient(180deg,hsl(var(--gold)),hsl(var(--gold)/0.8))] px-3 text-sm font-semibold text-black shadow-[0_14px_30px_rgba(215,170,40,0.24)] transition hover:opacity-95",
              collapsed ? "justify-center" : ""
            )}
          >
            <Plus className={cn("h-4 w-4", collapsed ? "" : "mr-2")} />
            {collapsed ? null : "New Booking"}
          </Link>
          <Link
            href="/business/reels/upload"
            className={cn(
              "inline-flex h-10 items-center justify-center rounded-xl border border-white/10 bg-white/[0.04] px-3 text-sm font-medium text-white transition hover:bg-white/[0.09]",
              collapsed ? "justify-center" : ""
            )}
          >
            <Upload className={cn("h-4 w-4", collapsed ? "" : "mr-2")} />
            {collapsed ? null : "Upload Reel"}
          </Link>
        </div>
      </div>

      <nav className={cn("flex-1 overflow-y-auto px-3 pb-6", collapsed ? "px-2" : "px-4")}>
        {collapsed ? null : (
          <div className="px-2 pb-3 text-[11px] uppercase tracking-[0.26em] text-white/32">Workspace</div>
        )}
        <div className="grid gap-1">
          {nav
            .filter((i) => i.key !== "logout")
            .map((item) => {
              const active = pathname === item.href || pathname.startsWith(`${item.href}/`);
              const Icon = item.icon;
              return (
                <Link
                  key={item.key}
                  href={item.href}
                  className={cn(
                    "group flex items-center gap-3 rounded-2xl border px-3 py-3 text-sm transition",
                    active
                      ? "border-[hsl(var(--gold)/0.2)] bg-[linear-gradient(90deg,rgba(255,214,77,0.14),rgba(255,214,77,0.04))] text-white shadow-[0_18px_40px_rgba(0,0,0,0.22)]"
                      : "border-transparent text-white/55 hover:border-white/10 hover:bg-white/[0.05] hover:text-white"
                  )}
                >
                  {Icon ? (
                    <Icon className={cn("h-4 w-4 transition", active ? "text-primary" : "text-white/45 group-hover:text-white")} />
                  ) : null}
                  {collapsed ? null : <span className="truncate">{item.label}</span>}
                </Link>
              );
            })}
        </div>
      </nav>

      <div className={cn("border-t border-white/10 p-4", collapsed ? "px-2" : "px-4")}>
        <form action="/auth/sign-out" method="post">
          <button
            type="submit"
            className={cn(
              "flex w-full items-center gap-3 rounded-2xl border border-white/10 bg-white/[0.04] px-3 py-3 text-sm text-white/60 transition hover:bg-white/[0.08] hover:text-white",
              collapsed ? "justify-center" : ""
            )}
          >
            <LogOut className="h-4 w-4" />
            {collapsed ? null : <span>Logout</span>}
          </button>
        </form>
      </div>
    </aside>
  );
}

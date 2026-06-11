"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { cn } from "@hallaq/ui/cn";
import { HallaqGoldLogo } from "@hallaq/ui/hallaq-logo";
import { Button } from "@hallaq/ui/button";
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
        "relative flex h-dvh flex-col border-r border-border bg-background/60 backdrop-blur-xl",
        collapsed ? "w-[84px]" : "w-[288px]"
      )}
    >
      <div className={cn("flex items-center gap-3 px-4 py-4", collapsed ? "justify-center" : "")}>
        <div className="flex h-11 w-11 items-center justify-center rounded-2xl border border-white/10 bg-white/5 shadow-soft">
          <HallaqGoldLogo className="h-6 w-6" />
        </div>
        {collapsed ? null : (
          <div className="flex min-w-0 flex-col">
            <div className="flex items-center gap-2 truncate text-sm font-semibold tracking-tight">
              <span className="truncate">{shop.name}</span>
              {shop.isVerified ? <BadgeCheck className="h-4 w-4 text-primary" /> : null}
            </div>
            <div className="truncate text-xs text-muted-foreground">{shop.area ?? "Bahrain"}</div>
          </div>
        )}
        <button
          type="button"
          onClick={onToggleCollapsed}
          className={cn(
            "absolute top-4 rounded-md border border-white/10 bg-white/5 p-2 text-muted-foreground transition hover:bg-white/10 hover:text-foreground",
            collapsed ? "right-3" : "right-4"
          )}
          aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
        >
          {collapsed ? <ChevronsRight className="h-4 w-4" /> : <ChevronsLeft className="h-4 w-4" />}
        </button>
      </div>

      <div className={cn("px-4 pb-3", collapsed ? "px-3" : "")}>
        <div className={cn("grid gap-2", collapsed ? "grid-cols-1" : "grid-cols-2")}>
          <Button asChild variant="secondary" size="sm" className={collapsed ? "justify-center" : ""}>
            <Link href="/business/bookings/new">
              <Plus className={cn("h-4 w-4", collapsed ? "" : "mr-2")} />
              {collapsed ? null : "New Booking"}
            </Link>
          </Button>
          <Button asChild variant="ghost" size="sm" className={collapsed ? "justify-center" : ""}>
            <Link href="/business/reels/upload">
              <Upload className={cn("h-4 w-4", collapsed ? "" : "mr-2")} />
              {collapsed ? null : "Upload Reel"}
            </Link>
          </Button>
        </div>
      </div>

      <nav className={cn("flex-1 overflow-y-auto px-2 pb-6", collapsed ? "px-2" : "px-3")}>
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
                    "group flex items-center gap-3 rounded-xl border border-transparent px-3 py-2 text-sm text-muted-foreground transition",
                    active
                      ? "border-white/10 bg-white/10 text-foreground shadow-soft"
                      : "hover:border-white/10 hover:bg-white/5 hover:text-foreground"
                  )}
                >
                  {Icon ? (
                    <Icon className={cn("h-4 w-4 text-muted-foreground transition", active ? "text-primary" : "group-hover:text-foreground")} />
                  ) : null}
                  {collapsed ? null : <span className="truncate">{item.label}</span>}
                </Link>
              );
            })}
        </div>
      </nav>

      <div className={cn("border-t border-border p-3", collapsed ? "px-2" : "px-3")}>
        <form action="/auth/sign-out" method="post">
          <button
            type="submit"
            className={cn(
              "flex w-full items-center gap-3 rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-muted-foreground transition hover:bg-white/10 hover:text-foreground",
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

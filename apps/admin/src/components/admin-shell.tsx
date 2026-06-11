"use client";

import { useMemo, useState, type ReactNode } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";

import {
  Activity,
  BadgeCheck,
  BarChart3,
  BookOpen,
  CalendarClock,
  CalendarDays,
  CheckCircle2,
  ChevronsLeft,
  ChevronsRight,
  FileText,
  LogOut,
  Package,
  Scissors,
  Settings,
  ShoppingCart,
  Store,
  ShieldCheck,
  ToggleLeft,
  UserRound,
  Users,
  Video
} from "lucide-react";

import { Button } from "@hallaq/ui/button";
import { cn } from "@hallaq/ui/cn";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { useT } from "@hallaq/ui/translations-client";

import { CommandPalette } from "@/components/command-palette";
import { NotificationsBell } from "@/components/notifications-bell";
import { RealtimeRefresh } from "@/components/realtime-refresh";

import { HallaqGoldLogo } from "./hallaq-logo";

type NavItem = {
  href: string;
  label: string;
  icon: (props: { className?: string }) => ReactNode;
};

function SidebarLink({
  item,
  collapsed,
  active
}: {
  item: NavItem;
  collapsed: boolean;
  active: boolean;
}) {
  return (
    <Link
      href={item.href}
      className={cn(
        "group flex items-center gap-3 rounded-lg border border-transparent px-3 py-2 text-sm transition",
        "hover:border-white/10 hover:bg-white/5",
        active ? "border-white/10 bg-white/5 shadow-glow" : "text-muted-foreground"
      )}
    >
      <span
        className={cn(
          "grid h-9 w-9 place-items-center rounded-md border border-white/10 bg-white/5",
          "text-primary transition group-hover:border-white/20 group-hover:bg-white/10"
        )}
      >
        {item.icon({ className: "h-4 w-4" })}
      </span>
      <span className={cn("truncate", collapsed ? "sr-only" : "")}>{item.label}</span>
    </Link>
  );
}

export function AdminShell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);
  const t = useT();

  const nav: NavItem[] = useMemo(
    () => [
      { href: "/dashboard", label: t("admin.nav.dashboard"), icon: (p) => <Activity {...p} /> },
      { href: "/users", label: t("admin.nav.users"), icon: (p) => <Users {...p} /> },
      { href: "/admin/role-relationship-audit", label: "Role Audit", icon: (p) => <ShieldCheck {...p} /> },
      { href: "/admin/connections-audit", label: "Connections Audit", icon: (p) => <ShieldCheck {...p} /> },
      { href: "/create-shop", label: "Create Shop", icon: (p) => <Store {...p} /> },
      { href: "/stores", label: t("admin.nav.stores"), icon: (p) => <Store {...p} /> },
      { href: "/create-barber", label: "Create Barber", icon: (p) => <UserRound {...p} /> },
      { href: "/barbers", label: t("admin.nav.barbers"), icon: (p) => <UserRound {...p} /> },
      { href: "/shop-barber-map", label: "Shop ↔ Barber Map", icon: (p) => <Users {...p} /> },
      { href: "/barber-requests", label: "Barber Requests", icon: (p) => <Users {...p} /> },
      { href: "/appointments", label: t("admin.nav.appointments"), icon: (p) => <CalendarClock {...p} /> },
      { href: "/calendar", label: "Calendar", icon: (p) => <CalendarDays {...p} /> },
      { href: "/posts-reels", label: t("admin.nav.postsReels"), icon: (p) => <Video {...p} /> },
      { href: "/approvals", label: "Approvals", icon: (p) => <CheckCircle2 {...p} /> },
      { href: "/services", label: "Services", icon: (p) => <Scissors {...p} /> },
      { href: "/products", label: "Products", icon: (p) => <Package {...p} /> },
      { href: "/orders", label: "Orders", icon: (p) => <ShoppingCart {...p} /> },
      { href: "/reviews", label: t("admin.nav.reviews"), icon: (p) => <BookOpen {...p} /> },
      { href: "/verification", label: t("admin.nav.verification"), icon: (p) => <BadgeCheck {...p} /> },
      { href: "/analytics", label: t("admin.nav.analytics"), icon: (p) => <BarChart3 {...p} /> },
      { href: "/reports", label: t("admin.nav.reports"), icon: (p) => <FileText {...p} /> },
      { href: "/admin/moderation", label: "Moderation", icon: (p) => <ShieldCheck {...p} /> },
      { href: "/qa-mode", label: "QA Mode", icon: (p) => <Activity {...p} /> },
      { href: "/launch-checklist", label: "Launch Checklist", icon: (p) => <CheckCircle2 {...p} /> },
      { href: "/diagnostics", label: "Diagnostics", icon: (p) => <Activity {...p} /> },
      { href: "/booking-qa", label: "Booking QA", icon: (p) => <CheckCircle2 {...p} /> },
      { href: "/push-health", label: "Push Health", icon: (p) => <Activity {...p} /> },
      { href: "/system-health-center", label: "System Health Center", icon: (p) => <Activity {...p} /> },
      { href: "/media-health-center", label: "Media Health Center", icon: (p) => <Activity {...p} /> },
      { href: "/error-center", label: "Error Center", icon: (p) => <Activity {...p} /> },
      { href: "/missing-images", label: "Missing Images", icon: (p) => <Activity {...p} /> },
      { href: "/data-integrity", label: "Data Integrity", icon: (p) => <Activity {...p} /> },
      { href: "/performance", label: "Performance", icon: (p) => <Activity {...p} /> },
      { href: "/security-center", label: "Security Center", icon: (p) => <ShieldCheck {...p} /> },
      { href: "/client-health", label: "Client Health", icon: (p) => <Activity {...p} /> },
      { href: "/shop-health", label: "Shop Health", icon: (p) => <Store {...p} /> },
      { href: "/barber-health", label: "Barber Health", icon: (p) => <UserRound {...p} /> },
      { href: "/brand-assets", label: "Brand Assets", icon: (p) => <Settings {...p} /> },
      { href: "/ai-assistant", label: "AI Assistant", icon: (p) => <Activity {...p} /> },
      { href: "/system-logs", label: "System Logs", icon: (p) => <Activity {...p} /> },
      { href: "/system-health", label: "System Health", icon: (p) => <Activity {...p} /> },
      { href: "/audit-logs", label: "Audit Logs", icon: (p) => <FileText {...p} /> },
      { href: "/backups", label: "Backups", icon: (p) => <FileText {...p} /> },
      { href: "/data-repair", label: "Data Repair", icon: (p) => <FileText {...p} /> },
      { href: "/data", label: "Data", icon: (p) => <FileText {...p} /> },
      { href: "/admin/feature-flags", label: "Feature Flags", icon: (p) => <ToggleLeft {...p} /> },
      { href: "/settings", label: t("admin.nav.settings"), icon: (p) => <Settings {...p} /> }
    ],
    [t]
  );

  return (
    <div className="relative min-h-dvh">
      <RealtimeRefresh tables={["bookings", "reels", "portfolio_items", "barbershops", "barbers", "profiles", "products", "orders"]} />
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(900px_600px_at_20%_0%,hsl(var(--gold)/0.16),transparent_60%),radial-gradient(800px_500px_at_85%_10%,hsl(var(--gold)/0.10),transparent_55%)]" />
      <div className="relative mx-auto grid min-h-dvh max-w-[1600px] grid-cols-1 gap-4 px-3 py-3 md:grid-cols-[auto,1fr] md:px-4 md:py-4">
        <aside
          className={cn(
            "sticky top-4 hidden h-[calc(100dvh-2rem)] md:flex",
            collapsed ? "w-[86px]" : "w-[292px]"
          )}
        >
          <LuxuryCard className="flex h-full w-full flex-col gap-4 p-3">
            <div className="flex items-center justify-between gap-2 px-1">
              <Link href="/dashboard" className="flex items-center gap-3">
                <HallaqGoldLogo className="h-9 w-9" />
                <div className={cn("flex flex-col leading-tight", collapsed ? "sr-only" : "")}>
                  <div className="text-sm font-semibold tracking-wide">HALLAQ</div>
                  <div className="text-xs text-muted-foreground">Super Admin</div>
                </div>
              </Link>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                onClick={() => setCollapsed((v) => !v)}
                className="h-9 w-9 px-0"
                aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
              >
                {collapsed ? (
                  <ChevronsRight className="h-4 w-4 text-muted-foreground" />
                ) : (
                  <ChevronsLeft className="h-4 w-4 text-muted-foreground" />
                )}
              </Button>
            </div>

            <nav className="flex flex-1 flex-col gap-1 px-1">
              {nav.map((item) => (
                <SidebarLink
                  key={item.href}
                  item={item}
                  collapsed={collapsed}
                  active={pathname === item.href || pathname?.startsWith(`${item.href}/`)}
                />
              ))}
            </nav>

            <div className="px-1">
              <LuxuryCard className={cn("p-3", collapsed ? "px-2" : "")}>
                <div className={cn("flex items-center justify-between gap-2", collapsed ? "" : "")}>
                  <div className={cn("flex flex-col gap-1", collapsed ? "sr-only" : "")}>
                    <div className="text-xs font-medium">Admin session</div>
                    <div className="text-[11px] text-muted-foreground">Protected routes enabled</div>
                  </div>
                  <form action="/auth/sign-out" method="post">
                    <Button
                      type="submit"
                      variant="ghost"
                      size="sm"
                      className={cn("h-9 gap-2", collapsed ? "w-9 px-0" : "")}
                    >
                      <LogOut className="h-4 w-4" />
                      <span className={cn(collapsed ? "sr-only" : "")}>{t("admin.nav.logout")}</span>
                    </Button>
                  </form>
                </div>
              </LuxuryCard>
            </div>
          </LuxuryCard>
        </aside>

        <div className="flex min-h-dvh flex-col gap-4">
          <header className="sticky top-3 z-10 md:top-4">
            <LuxuryCard className="flex items-center justify-between gap-3 px-4 py-3">
              <div className="flex items-center gap-3 md:hidden">
                <HallaqGoldLogo className="h-9 w-9" />
                <div className="flex flex-col leading-tight">
                  <div className="text-sm font-semibold tracking-wide">HALLAQ</div>
                  <div className="text-xs text-muted-foreground">Super Admin</div>
                </div>
              </div>

              <div className="hidden flex-1 items-center md:flex">
                <CommandPalette />
              </div>

              <div className="flex items-center gap-2">
                <NotificationsBell />
                <Button asChild variant="secondary" size="sm" className="h-11">
                  <Link href="/create-shop">
                    <Users className="h-4 w-4" />
                    <span className="hidden md:inline">{t("admin.common.create")}</span>
                  </Link>
                </Button>
                <Button asChild variant="ghost" size="sm" className="h-11">
                  <Link href="/analytics">
                    <BarChart3 className="h-4 w-4" />
                    <span className="hidden md:inline">{t("admin.common.live")}</span>
                  </Link>
                </Button>
              </div>
            </LuxuryCard>
          </header>

          <main className="flex-1 pb-6">{children}</main>
        </div>
      </div>
    </div>
  );
}

"use client";

import type { ReactNode } from "react";
import { useState } from "react";

import { cn } from "@hallaq/ui/cn";

import { businessNav } from "./nav";
import { BusinessHeader } from "./header";
import { BusinessSidebar } from "./sidebar";

export function BusinessShell({
  shop,
  unreadNotifications,
  unreadMessages,
  children
}: {
  shop: { name: string; logoUrl: string | null; isVerified: boolean; area: string | null };
  unreadNotifications: number;
  unreadMessages: number;
  children: ReactNode;
}) {
  const [collapsed, setCollapsed] = useState(false);

  return (
    <div
      dir="ltr"
      className="flex min-h-dvh w-full bg-[radial-gradient(1200px_700px_at_10%_-10%,hsl(var(--gold)/0.18),transparent_52%),radial-gradient(1000px_580px_at_100%_0%,hsl(var(--gold)/0.10),transparent_48%),linear-gradient(180deg,rgba(18,18,18,0.98),rgba(7,7,7,1))]"
    >
      <BusinessSidebar
        shop={shop}
        nav={businessNav}
        collapsed={collapsed}
        onToggleCollapsed={() => setCollapsed((v) => !v)}
      />
      <div className="flex min-h-dvh flex-1 flex-col overflow-hidden">
        <BusinessHeader
          shopName={shop.name}
          shopArea={shop.area}
          isVerified={shop.isVerified}
          unreadNotifications={unreadNotifications}
          unreadMessages={unreadMessages}
        />
        <div
          className={cn(
            "flex-1 overflow-y-auto px-4 py-4 sm:px-6 sm:py-6 xl:px-8",
            "bg-[radial-gradient(900px_540px_at_15%_-10%,hsl(var(--gold)/0.10),transparent_55%),radial-gradient(800px_420px_at_90%_0%,hsl(var(--gold)/0.08),transparent_55%)]"
          )}
        >
          <div className="mx-auto w-full max-w-[1680px]">{children}</div>
        </div>
      </div>
    </div>
  );
}

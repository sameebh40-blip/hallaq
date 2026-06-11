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
    <div className="flex min-h-dvh w-full">
      <BusinessSidebar
        shop={shop}
        nav={businessNav}
        collapsed={collapsed}
        onToggleCollapsed={() => setCollapsed((v) => !v)}
      />
      <div className="flex min-h-dvh flex-1 flex-col overflow-hidden">
        <BusinessHeader
          shopName={shop.name}
          unreadNotifications={unreadNotifications}
          unreadMessages={unreadMessages}
        />
        <div
          className={cn(
            "flex-1 overflow-y-auto px-6 py-6",
            "bg-[radial-gradient(900px_500px_at_10%_-10%,hsl(var(--gold)/0.10),transparent_55%),radial-gradient(800px_420px_at_90%_0%,hsl(var(--gold)/0.06),transparent_55%)]"
          )}
        >
          <div className="mx-auto w-full max-w-[1680px]">{children}</div>
        </div>
      </div>
    </div>
  );
}

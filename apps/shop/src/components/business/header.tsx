"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef } from "react";

import { cn } from "@hallaq/ui/cn";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Bell, MessageCircle, Plus, Search, Upload } from "lucide-react";

export function BusinessHeader({
  shopName,
  unreadNotifications,
  unreadMessages
}: {
  shopName: string;
  unreadNotifications: number;
  unreadMessages: number;
}) {
  const router = useRouter();
  const inputRef = useRef<HTMLInputElement | null>(null);

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        inputRef.current?.focus();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  return (
    <header className="sticky top-0 z-20 flex items-center justify-between gap-4 border-b border-border bg-background/50 px-6 py-4 backdrop-blur-xl">
      <div className="flex min-w-0 items-center gap-4">
        <div className="min-w-0">
          <div className="truncate text-sm font-semibold tracking-tight">{shopName}</div>
          <div className="truncate text-xs text-muted-foreground">Business Dashboard</div>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault();
            const formData = new FormData(e.currentTarget);
            const q = String(formData.get("q") ?? "").trim();
            if (!q) return;
            router.push(`/business/search?q=${encodeURIComponent(q)}`);
          }}
          className="hidden min-w-[520px] max-w-[720px] flex-1 items-center gap-2 lg:flex"
        >
          <div className="relative w-full">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              ref={inputRef}
              name="q"
              placeholder="Search bookings, customers, services…"
              className="h-11 w-full rounded-2xl border-white/10 bg-white/5 pl-10"
            />
            <div className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 rounded-md border border-white/10 bg-white/5 px-2 py-1 text-[10px] text-muted-foreground">
              Ctrl K
            </div>
          </div>
        </form>
      </div>

      <div className="flex items-center gap-2">
        <Button asChild variant="secondary" size="sm" className="hidden md:inline-flex">
          <Link href="/business/bookings/new">
            <Plus className="mr-2 h-4 w-4" />
            New Booking
          </Link>
        </Button>
        <Button asChild variant="ghost" size="sm" className="hidden md:inline-flex">
          <Link href="/business/reels/upload">
            <Upload className="mr-2 h-4 w-4" />
            Upload Reel
          </Link>
        </Button>

        <Link
          href="/business/messages"
          className={cn(
            "relative flex h-10 w-10 items-center justify-center rounded-xl border border-white/10 bg-white/5 text-muted-foreground transition hover:bg-white/10 hover:text-foreground"
          )}
        >
          <MessageCircle className="h-4 w-4" />
          {unreadMessages > 0 ? (
            <span className="absolute -right-1 -top-1 flex h-5 min-w-5 items-center justify-center rounded-full bg-primary px-1 text-[10px] font-semibold text-primary-foreground">
              {Math.min(unreadMessages, 99)}
            </span>
          ) : null}
        </Link>
        <Link
          href="/business/notifications"
          className={cn(
            "relative flex h-10 w-10 items-center justify-center rounded-xl border border-white/10 bg-white/5 text-muted-foreground transition hover:bg-white/10 hover:text-foreground"
          )}
        >
          <Bell className="h-4 w-4" />
          {unreadNotifications > 0 ? (
            <span className="absolute -right-1 -top-1 flex h-5 min-w-5 items-center justify-center rounded-full bg-primary px-1 text-[10px] font-semibold text-primary-foreground">
              {Math.min(unreadNotifications, 99)}
            </span>
          ) : null}
        </Link>
      </div>
    </header>
  );
}

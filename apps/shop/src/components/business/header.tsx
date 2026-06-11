"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef } from "react";

import { cn } from "@hallaq/ui/cn";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { BadgeCheck, Bell, Command, MessageCircle, Plus, Search, Upload } from "lucide-react";

export function BusinessHeader({
  shopName,
  shopArea,
  isVerified,
  unreadNotifications,
  unreadMessages
}: {
  shopName: string;
  shopArea: string | null;
  isVerified: boolean;
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
    <header className="sticky top-0 z-20 border-b border-white/10 bg-black/35 px-4 py-4 backdrop-blur-2xl sm:px-6 xl:px-8">
      <div className="mx-auto flex w-full max-w-[1680px] flex-col gap-4 xl:flex-row xl:items-center xl:justify-between">
        <div className="flex min-w-0 items-center gap-4">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl border border-[hsl(var(--gold)/0.28)] bg-[linear-gradient(180deg,rgba(255,215,64,0.22),rgba(255,215,64,0.06))] text-lg font-semibold text-primary shadow-[0_20px_40px_rgba(0,0,0,0.28)]">
            H
          </div>
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <div className="truncate text-base font-semibold tracking-tight text-white">{shopName}</div>
              {isVerified ? <BadgeCheck className="h-4 w-4 text-primary" /> : null}
            </div>
            <div className="truncate text-xs uppercase tracking-[0.22em] text-white/45">
              {shopArea ?? "Bahrain"} • Business Dashboard
            </div>
          </div>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault();
            const formData = new FormData(e.currentTarget);
            const q = String(formData.get("q") ?? "").trim();
            if (!q) return;
            router.push(`/business/search?q=${encodeURIComponent(q)}`);
          }}
          className="hidden min-w-[460px] max-w-[760px] flex-1 items-center gap-2 xl:flex"
        >
          <div className="relative w-full overflow-hidden rounded-2xl border border-white/10 bg-white/[0.04] shadow-[inset_0_1px_0_rgba(255,255,255,0.06)]">
            <Search className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-white/40" />
            <Input
              ref={inputRef}
              name="q"
              placeholder="Search bookings, customers, services…"
              className="h-12 w-full rounded-2xl border-0 bg-transparent pl-11 pr-20 text-white placeholder:text-white/35 focus-visible:ring-0"
            />
            <div className="pointer-events-none absolute right-3 top-1/2 inline-flex -translate-y-1/2 items-center gap-1 rounded-xl border border-white/10 bg-white/[0.05] px-2.5 py-1 text-[10px] uppercase tracking-[0.18em] text-white/50">
              <Command className="h-3 w-3" />
              Ctrl K
            </div>
          </div>
        </form>

        <div className="flex items-center gap-2 self-end xl:self-auto">
          <Button asChild variant="secondary" size="sm" className="hidden border-white/10 bg-white/10 text-white hover:bg-white/15 md:inline-flex">
            <Link href="/business/reels/upload">
              <Upload className="mr-2 h-4 w-4" />
              Upload Reel
            </Link>
          </Button>
          <Button
            asChild
            size="sm"
            className="h-10 rounded-xl bg-[linear-gradient(180deg,hsl(var(--gold)),hsl(var(--gold)/0.82))] px-4 text-black shadow-[0_14px_30px_rgba(215,170,40,0.30)] hover:opacity-95"
          >
            <Link href="/business/bookings/new">
              <Plus className="mr-2 h-4 w-4" />
              New Booking
            </Link>
          </Button>

          <Link
            href="/business/messages"
            className={cn(
              "relative flex h-10 w-10 items-center justify-center rounded-xl border border-white/10 bg-white/[0.05] text-white/65 transition hover:bg-white/10 hover:text-white"
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
              "relative flex h-10 w-10 items-center justify-center rounded-xl border border-white/10 bg-white/[0.05] text-white/65 transition hover:bg-white/10 hover:text-white"
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
      </div>
    </header>
  );
}

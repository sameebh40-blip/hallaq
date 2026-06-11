"use client";

import { useEffect, useMemo, useState } from "react";

import { Bell } from "lucide-react";

import type { RealtimeChannel } from "@supabase/supabase-js";

import { createSupabaseBrowserClient } from "@hallaq/supabase/browser";
import { Button } from "@hallaq/ui/button";
import { cn } from "@hallaq/ui/cn";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

type NotificationRow = {
  id: string;
  type: string;
  title: string;
  body: string;
  read: boolean;
  created_at: string;
};

export function NotificationsBell() {
  const [open, setOpen] = useState(false);
  const [items, setItems] = useState<NotificationRow[]>([]);
  const [loading, setLoading] = useState(true);
  const unread = useMemo(() => items.filter((i) => !i.read).length, [items]);

  useEffect(() => {
    const supabase = createSupabaseBrowserClient();
    let sub: RealtimeChannel | null = null;
    let alive = true;

    (async () => {
      try {
        const { data } = await supabase.auth.getUser();
        const pid = data.user?.id ?? "";
        if (!pid) {
          if (alive) setLoading(false);
          return;
        }

        const { data: rows } = await supabase
          .from("notifications")
          .select("id, type, title, body, read, created_at")
          .eq("profile_id", pid)
          .order("created_at", { ascending: false })
          .limit(12);

        if (alive) setItems((rows ?? []) as NotificationRow[]);

        if (alive) setLoading(false);

        sub = supabase
          .channel(`admin-notifications-${pid}`)
          .on(
            "postgres_changes",
            { event: "INSERT", schema: "public", table: "notifications", filter: `profile_id=eq.${pid}` },
            (payload) => {
              const row = payload.new as NotificationRow;
              setItems((prev) => [row, ...prev].slice(0, 12));
            }
          )
          .on(
            "postgres_changes",
            { event: "UPDATE", schema: "public", table: "notifications", filter: `profile_id=eq.${pid}` },
            (payload) => {
              const row = payload.new as NotificationRow;
              setItems((prev) => prev.map((p) => (p.id === row.id ? row : p)));
            }
          )
          .subscribe();
      } catch {
        if (alive) {
          setItems([]);
          setLoading(false);
        }
      }
    })();

    return () => {
      alive = false;
      if (sub) supabase.removeChannel(sub);
    };
  }, []);

  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") setOpen(false);
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  async function markRead(id: string) {
    const supabase = createSupabaseBrowserClient();
    await supabase.from("notifications").update({ read: true }).eq("id", id);
  }

  return (
    <div className="relative">
      <Button
        type="button"
        variant="ghost"
        size="sm"
        className="relative h-11 w-11 px-0"
        onClick={() => setOpen((v) => !v)}
        aria-label="Notifications"
      >
        <Bell className="h-4 w-4" />
        {unread ? <span className="absolute right-2 top-2 h-2 w-2 rounded-full bg-primary shadow-glow" /> : null}
      </Button>

      {open ? (
        <div className="absolute end-0 top-12 z-20 w-[340px]" onMouseLeave={() => setOpen(false)}>
          <LuxuryCard className="overflow-hidden p-0">
            <div className="flex items-center justify-between gap-4 border-b border-white/10 px-4 py-3">
              <div className="text-sm font-semibold">Notifications</div>
              <div className="text-xs text-muted-foreground">
                {loading ? "Loading…" : unread ? `${unread} unread` : "All caught up"}
              </div>
            </div>

            <div className="max-h-[420px] overflow-auto">
              {loading ? (
                <div className="space-y-3 px-4 py-4">
                  {Array.from({ length: 4 }).map((_, idx) => (
                    <div key={idx} className="animate-pulse rounded-lg border border-white/10 bg-white/5 px-3 py-3">
                      <div className="h-3 w-2/3 rounded bg-white/10" />
                      <div className="mt-2 h-3 w-full rounded bg-white/10" />
                    </div>
                  ))}
                </div>
              ) : items.length ? (
                items.map((n) => (
                  <button
                    key={n.id}
                    type="button"
                    onClick={() => markRead(n.id)}
                    className={cn("w-full px-4 py-3 text-left transition hover:bg-white/5", n.read ? "opacity-70" : "")}
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div className="flex flex-col gap-1">
                        <div className="text-sm font-medium">{n.title}</div>
                        <div className="text-xs text-muted-foreground">{n.body}</div>
                      </div>
                      <div className="text-[10px] text-muted-foreground">
                        {Intl.DateTimeFormat("en", { month: "short", day: "2-digit" }).format(new Date(n.created_at))}
                      </div>
                    </div>
                  </button>
                ))
              ) : (
                <div className="px-4 py-10 text-center text-sm text-muted-foreground">
                  No notifications yet.
                </div>
              )}
            </div>
          </LuxuryCard>
        </div>
      ) : null}
    </div>
  );
}

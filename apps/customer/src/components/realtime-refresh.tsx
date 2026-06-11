"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

import { tryCreateSupabaseBrowserClient } from "@hallaq/supabase/browser";

import { trackAnalyticsEvent } from "@/lib/analytics";

type RealtimeSubscription = {
  table: string;
  event?: "*" | "INSERT" | "UPDATE" | "DELETE";
  filter?: string;
};

export function RealtimeRefresh({
  tables,
  subscriptions
}: {
  tables?: string[];
  subscriptions?: RealtimeSubscription[];
}) {
  const router = useRouter();
  const subsKey = JSON.stringify(subscriptions ?? (tables ?? []).map((table) => ({ table })));

  useEffect(() => {
    const supabase = tryCreateSupabaseBrowserClient();
    if (!supabase) return;
    const list = JSON.parse(subsKey) as RealtimeSubscription[];
    let channel = supabase.channel("customer_refresh");

    for (const sub of list) {
      channel = channel.on(
        "postgres_changes",
        { event: sub.event ?? "*", schema: "public", table: sub.table, ...(sub.filter ? { filter: sub.filter } : {}) },
        () => router.refresh()
      );
    }

    channel = channel.subscribe();
    void trackAnalyticsEvent({
      event_name: "realtime_channels",
      meta: { channels: 1, subscriptions: list.length, app: "customer" }
    }).catch(() => null);
    return () => {
      supabase.removeChannel(channel);
    };
  }, [router, subsKey]);

  return null;
}

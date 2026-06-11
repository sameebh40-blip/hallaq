"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

import { tryCreateSupabaseBrowserClient } from "@hallaq/supabase/browser";

type RealtimeSubscription = {
  table: string;
  event?: string;
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
    const channel = supabase.channel("shop_refresh");
    const ch = channel as unknown as {
      on: (
        type: "postgres_changes",
        filter: Record<string, unknown>,
        callback: () => void
      ) => unknown;
    };

    const list = JSON.parse(subsKey) as RealtimeSubscription[];
    for (const sub of list) {
      ch.on(
        "postgres_changes",
        {
          event: sub.event ?? "*",
          schema: "public",
          table: sub.table,
          ...(sub.filter ? { filter: sub.filter } : {})
        } as Record<string, unknown>,
        () => router.refresh()
      );
    }

    channel.subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [router, subsKey]);

  return null;
}

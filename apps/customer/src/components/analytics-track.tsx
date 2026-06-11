"use client";

import { useEffect } from "react";

import { trackOnce } from "@/lib/analytics";

export function AnalyticsTrack({
  eventName,
  entityType,
  entityId,
  metaKey,
  meta
}: {
  eventName: string;
  entityType?: string;
  entityId?: string | null;
  metaKey?: string;
  meta?: Record<string, unknown>;
}) {
  useEffect(() => {
    const key = metaKey ?? `${eventName}:${entityType ?? "generic"}:${entityId ?? "none"}`;
    void trackOnce(key, { event_name: eventName, entity_type: entityType, entity_id: entityId ?? null, meta });
  }, [entityId, entityType, eventName, metaKey, meta]);

  return null;
}


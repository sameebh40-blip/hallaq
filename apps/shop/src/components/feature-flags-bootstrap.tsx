"use client";

import type { ReactNode } from "react";
import { useEffect } from "react";

import { FeatureFlagsProvider } from "@hallaq/feature-flags";

import { createAppSupabaseBrowserClient } from "@/lib/supabase-browser";

function getErrorMessage(value: unknown) {
  if (value instanceof Error) return value.message;
  if (typeof value === "string") return value;
  if (value && typeof value === "object") {
    const maybe = value as { message?: unknown };
    if (typeof maybe.message === "string") return maybe.message;
  }
  return null;
}

function getErrorStack(value: unknown) {
  if (value instanceof Error) return value.stack ?? null;
  if (value && typeof value === "object") {
    const maybe = value as { stack?: unknown };
    if (typeof maybe.stack === "string") return maybe.stack;
  }
  return null;
}

export function FeatureFlagsBootstrap({ children }: { children: ReactNode }) {
  useEffect(() => {
    let lastSignature: string | null = null;
    let lastAt = 0;

    const send = (payload: Record<string, unknown>) => {
      try {
        const now = Date.now();
        const signature = JSON.stringify(payload).slice(0, 1200);
        if (signature === lastSignature && now - lastAt < 3000) return;
        lastSignature = signature;
        lastAt = now;

        void fetch("/shop/api/system-logs", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify(payload)
        }).catch(() => null);
      } catch {}
    };

    const onError = (event: ErrorEvent) => {
      send({
        page: window.location.pathname,
        action: "window_error",
        error_message: event.message,
        stack_trace: event.error?.stack ?? null,
        platform: "web",
        device: navigator.userAgent,
        meta: { filename: event.filename, lineno: event.lineno, colno: event.colno }
      });
    };

    const onUnhandledRejection = (event: PromiseRejectionEvent) => {
      const errorMessage = getErrorMessage(event.reason) ?? "Unhandled promise rejection";
      send({
        page: window.location.pathname,
        action: "unhandled_rejection",
        error_message: errorMessage,
        stack_trace: getErrorStack(event.reason),
        platform: "web",
        device: navigator.userAgent,
        meta: { reason: typeof event.reason === "string" ? event.reason : null }
      });
    };

    window.addEventListener("error", onError);
    window.addEventListener("unhandledrejection", onUnhandledRejection);
    return () => {
      window.removeEventListener("error", onError);
      window.removeEventListener("unhandledrejection", onUnhandledRejection);
    };
  }, []);

  return <FeatureFlagsProvider createClient={() => createAppSupabaseBrowserClient()}>{children}</FeatureFlagsProvider>;
}

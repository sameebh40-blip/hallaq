"use client";

import type { ReactNode } from "react";
import { useEffect } from "react";
import { usePathname } from "next/navigation";

import { FeatureFlagsProvider } from "@hallaq/feature-flags";

import { trackAnalyticsEvent, trackOnce } from "@/lib/analytics";
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
  const pathname = usePathname();

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

        void fetch("/api/system-logs", {
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

  useEffect(() => {
    if (typeof window === "undefined") return;

    const nav = performance.getEntriesByType("navigation")[0];
    const duration = nav && "duration" in nav ? Number((nav as PerformanceNavigationTiming).duration) : null;
    const ms = Number.isFinite(duration) && duration != null ? Math.round(duration) : null;
    void trackOnce("page_load_initial", {
      event_name: "page_load",
      meta: { ms, path: window.location.pathname }
    });
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const start = performance.now();
    const id = window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => {
        const ms = Math.round(performance.now() - start);
        void trackAnalyticsEvent({ event_name: "page_load", meta: { ms, path: pathname, nav: "spa" } }).catch(() => null);
      });
    });
    return () => window.cancelAnimationFrame(id);
  }, [pathname]);

  useEffect(() => {
    if (typeof window === "undefined") return;

    const originalFetch = window.fetch.bind(window);
    window.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
      const startedAt = performance.now();
      try {
        const res = await originalFetch(input, init);
        const ms = Math.round(performance.now() - startedAt);

        if (ms > 800) {
          const rawUrl = typeof input === "string" ? input : input instanceof URL ? input.toString() : (input as Request).url;
          const url = rawUrl ? new URL(rawUrl, window.location.origin) : null;
          const method = (init?.method ?? (input instanceof Request ? input.method : "GET")).toUpperCase();

          void trackAnalyticsEvent({
            event_name: "slow_api",
            meta: {
              ms,
              method,
              host: url?.host ?? null,
              path: url ? `${url.pathname}${url.search}` : null,
              status: res.status
            }
          }).catch(() => null);
        }

        return res;
      } catch (err) {
        const ms = Math.round(performance.now() - startedAt);
        if (ms > 800) {
          const rawUrl = typeof input === "string" ? input : input instanceof URL ? input.toString() : (input as Request).url;
          const url = rawUrl ? new URL(rawUrl, window.location.origin) : null;
          const method = (init?.method ?? (input instanceof Request ? input.method : "GET")).toUpperCase();

          void trackAnalyticsEvent({
            event_name: "slow_api",
            meta: {
              ms,
              method,
              host: url?.host ?? null,
              path: url ? `${url.pathname}${url.search}` : null,
              status: "failed"
            }
          }).catch(() => null);
        }
        throw err;
      }
    }) as typeof window.fetch;

    return () => {
      window.fetch = originalFetch;
    };
  }, []);

  return <FeatureFlagsProvider createClient={() => createAppSupabaseBrowserClient()}>{children}</FeatureFlagsProvider>;
}

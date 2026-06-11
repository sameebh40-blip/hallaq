"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";

import { Search, X } from "lucide-react";

import { Button } from "@hallaq/ui/button";
import { cn } from "@hallaq/ui/cn";
import { Input } from "@hallaq/ui/input";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { useT } from "@hallaq/ui/translations-client";

type Result = { type: string; title: string; subtitle: string; href: string };

export function CommandPalette() {
  const t = useT();
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");
  const [results, setResults] = useState<Result[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [retryIndex, setRetryIndex] = useState(0);
  const inputRef = useRef<HTMLInputElement | null>(null);

  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setOpen(true);
      }
      if (e.key === "Escape") setOpen(false);
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  useEffect(() => {
    if (!open) return;
    const tId = window.setTimeout(() => inputRef.current?.focus(), 20);
    return () => window.clearTimeout(tId);
  }, [open]);

  useEffect(() => {
    if (!open) return;
    if (q.trim().length < 2) {
      setResults([]);
      setError(null);
      return;
    }

    const controller = new AbortController();
    const handle = window.setTimeout(async () => {
      try {
        setLoading(true);
        setError(null);
        const res = await fetch(`/api/search?q=${encodeURIComponent(q.trim())}`, {
          signal: controller.signal
        });
        if (!res.ok) throw new Error("SearchFailed");
        const json = (await res.json()) as { results: Result[] };
        setResults(json.results ?? []);
      } catch {
        if (controller.signal.aborted) return;
        setResults([]);
        setError("Couldn’t load search results. Please try again.");
      } finally {
        setLoading(false);
      }
    }, 180);

    return () => {
      controller.abort();
      window.clearTimeout(handle);
    };
  }, [open, q, retryIndex]);

  const hint = useMemo(() => (open ? "" : "Ctrl K"), [open]);

  return (
    <>
      <div className="relative w-full max-w-xl">
        <Input
          placeholder={`${t("admin.common.search")}: ${t("admin.nav.users")}, ${t("admin.nav.stores")}, ${t("admin.nav.barbers")}…`}
          className="h-11 bg-white/5 ps-10 text-sm"
          onFocus={() => setOpen(true)}
          readOnly
        />
        <Search className="pointer-events-none absolute inset-y-0 start-3 my-auto h-4 w-4 text-muted-foreground" />
        <div className="pointer-events-none absolute inset-y-0 end-3 my-auto flex items-center gap-2">
          <span className="rounded-md border border-white/10 bg-white/5 px-2 py-1 text-[10px] text-muted-foreground">
            {hint}
          </span>
        </div>
      </div>

      {open ? (
        <div
          className="fixed inset-0 z-50 grid place-items-start bg-black/60 px-4 py-10 backdrop-blur"
          onMouseDown={() => setOpen(false)}
        >
          <LuxuryCard
            className="mx-auto w-full max-w-2xl p-4"
            onMouseDown={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between gap-3">
              <div className="relative flex-1">
                <Search className="pointer-events-none absolute inset-y-0 start-3 my-auto h-4 w-4 text-muted-foreground" />
                <Input
                  ref={inputRef}
                  value={q}
                  onChange={(e) => setQ(e.target.value)}
                  placeholder={`${t("admin.common.search")}…`}
                  className="h-11 bg-white/5 ps-10"
                />
              </div>
              <Button type="button" variant="ghost" size="sm" className="h-11 w-11 px-0" onClick={() => setOpen(false)}>
                <X className="h-4 w-4" />
              </Button>
            </div>

            <div className="mt-3 overflow-hidden rounded-lg border border-white/10 bg-white/5">
              <div className="flex items-center justify-between gap-3 border-b border-white/10 px-4 py-2 text-xs text-muted-foreground">
                <div>
                  {loading
                    ? "Searching…"
                    : error
                      ? error
                      : results.length
                        ? `${results.length} results`
                        : "Type to search"}
                </div>
                <div className="rounded-md border border-white/10 bg-white/5 px-2 py-1">Esc</div>
              </div>
              <div className="max-h-[420px] overflow-auto">
                {results.length ? (
                  results.map((r) => (
                    <Link
                      key={`${r.type}-${r.href}`}
                      href={r.href}
                      onClick={() => setOpen(false)}
                      className={cn(
                        "flex items-start justify-between gap-4 px-4 py-3 text-sm transition",
                        "hover:bg-white/5"
                      )}
                    >
                      <div className="flex flex-col gap-1">
                        <div className="font-medium">{r.title}</div>
                        <div className="text-xs text-muted-foreground">{r.subtitle}</div>
                      </div>
                      <div className="rounded-full border border-white/10 bg-white/5 px-2.5 py-1 text-[10px] text-muted-foreground">
                        {r.type}
                      </div>
                    </Link>
                  ))
                ) : (
                  <div className="px-4 py-10 text-center text-sm text-muted-foreground">
                    {q.trim().length < 2 ? (
                      "Start typing…"
                    ) : error ? (
                      <Button type="button" variant="secondary" size="sm" onClick={() => setRetryIndex((v) => v + 1)}>
                        Retry
                      </Button>
                    ) : (
                      "No results"
                    )}
                  </div>
                )}
              </div>
            </div>
          </LuxuryCard>
        </div>
      ) : null}
    </>
  );
}

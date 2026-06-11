"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";

import { useFeatureFlagEnabled } from "@hallaq/feature-flags";
import { cn } from "@hallaq/ui/cn";

import { SafeImage } from "@/components/safe-image";
import { createAppSupabaseBrowserClient } from "@/lib/supabase-browser";

type Result = { styleKey: string; outputImageUrl: string };
type Style = { key: string; name: string; imageUrl: string | null };

function safeStr(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function isHttpUrl(value: string) {
  return value.startsWith("http://") || value.startsWith("https://");
}

export function AiStudioClient() {
  const params = useSearchParams();
  const presetStyle = safeStr(params.get("style"));
  const enabled = useFeatureFlagEnabled("ai_haircut_studio", false);

  const fileRef = useRef<HTMLInputElement | null>(null);
  const supabase = useMemo(() => createAppSupabaseBrowserClient(), []);

  const [selfieUrl, setSelfieUrl] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [selected, setSelected] = useState<string[]>(() => (presetStyle ? [presetStyle] : []));
  const [results, setResults] = useState<Result[] | null>(null);
  const [activeIndex, setActiveIndex] = useState(0);
  const [notice, setNotice] = useState<string | null>(null);
  const [styles, setStyles] = useState<Style[]>([]);

  const active = results?.[activeIndex] ?? null;

  useEffect(() => {
    let alive = true;
    (async () => {
      const { data } = await supabase
        .from("style_library")
        .select("name_en, name_ar, ai_style_key, cover_url, cover_path, views_count, is_active")
        .eq("is_active", true)
        .order("views_count", { ascending: false })
        .order("created_at", { ascending: false })
        .limit(12);

      const rows = (data ?? []) as Array<Record<string, unknown>>;
      const mapped = rows
        .map((r) => {
          const key = safeStr(r.ai_style_key);
          if (!key) return null;
          const name = safeStr(r.name_en) || safeStr(r.name_ar) || "Style";
          const ref = safeStr(r.cover_path) || safeStr(r.cover_url);
          const imageUrl = ref ? (isHttpUrl(ref) ? ref : supabase.storage.from("style-library").getPublicUrl(ref).data.publicUrl) : null;
          return { key, name, imageUrl: imageUrl ? safeStr(imageUrl) : null } satisfies Style;
        })
        .filter(Boolean) as Style[];

      if (!alive) return;
      setStyles(mapped);
      setSelected((prev) => {
        if (presetStyle) return [presetStyle];
        if (prev.length) return prev;
        const first = mapped[0]?.key ?? "";
        return first ? [first] : [];
      });
    })();

    return () => {
      alive = false;
    };
  }, [presetStyle, supabase]);

  async function ensureAuth() {
    const {
      data: { user }
    } = await supabase.auth.getUser();
    if (!user) {
      window.location.href = "/auth/sign-in?next=/city/ai-studio";
      return null;
    }
    return user;
  }

  async function uploadSelfie(file: File) {
    const user = await ensureAuth();
    if (!user) return null;

    const ext = (file.name.split(".").pop() || "jpg").toLowerCase();
    const path = `${user.id}/inputs/${crypto.randomUUID()}.${ext}`;
    const { error: uploadError } = await supabase.storage.from("ai-style").upload(path, file, { upsert: false });
    if (uploadError) return null;
    const { data } = supabase.storage.from("ai-style").getPublicUrl(path);
    return safeStr(data.publicUrl) || null;
  }

  async function generate() {
    if (busy) return;
    if (!enabled) return;
    if (!selfieUrl) return;
    if (!selected.length) return;
    setBusy(true);
    setNotice(null);
    try {
      const body = { inputImageUrl: selfieUrl, styleKeys: selected };
      const res = await fetch("/api/city/ai/generate", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(body)
      });
      if (!res.ok) {
        setResults(null);
        setNotice("AI preview is unavailable right now.");
        return;
      }
      const json = (await res.json()) as { requestId: string | null; results: Result[] };
      const list = (json.results ?? [])
        .map((r) => ({ styleKey: safeStr(r.styleKey), outputImageUrl: safeStr(r.outputImageUrl) }))
        .filter((r) => r.styleKey && r.outputImageUrl);
      if (!list.length) {
        setResults(null);
        setNotice("AI preview is unavailable right now.");
        return;
      }
      setResults(list);
      setActiveIndex(0);
    } finally {
      setBusy(false);
    }
  }

  async function saveCurrent() {
    if (!active) return;
    const user = await ensureAuth();
    if (!user) return;
    const { error } = await supabase.from("ai_style_saves").insert({ profile_id: user.id, style_key: active.styleKey, image_url: active.outputImageUrl });
    setNotice(error ? "Save failed. Please try again." : "Saved.");
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="overflow-hidden rounded-[28px] border bg-[#111111] p-4 text-white shadow-[0_18px_48px_rgba(0,0,0,0.18)]">
        <div className="text-[11px] font-semibold tracking-[0.22em] text-white/70">AI HAIRCUT STUDIO</div>
        <div className="mt-2 text-sm font-semibold">Upload a selfie, choose styles, generate previews.</div>
        {!enabled ? <div className="mt-2 text-[12px] text-white/70">Coming soon.</div> : null}
      </div>

      <div className="grid grid-cols-2 gap-3">
        <button
          type="button"
          disabled={!enabled}
          onClick={() => fileRef.current?.click()}
          className={cn(
            "grid min-h-[140px] place-items-center overflow-hidden rounded-[26px] border bg-white shadow-[0_16px_36px_rgba(17,17,17,0.08)]",
            !enabled ? "opacity-60" : ""
          )}
        >
          {selfieUrl ? (
            <SafeImage src={selfieUrl} fallbackKey="default_profile_avatar" alt="Selfie" className="h-full w-full object-cover" />
          ) : (
            <div className="flex flex-col items-center gap-2 p-4">
              <div className="grid h-10 w-10 place-items-center rounded-2xl bg-[hsl(var(--gold))/0.14] text-[#111111]">+</div>
              <div className="text-[12px] font-semibold text-[#111111]">Upload Selfie</div>
              <div className="text-[11px] text-muted-foreground">Front-facing, good lighting.</div>
            </div>
          )}
        </button>

        <div className="overflow-hidden rounded-[26px] border bg-white p-4 shadow-[0_16px_36px_rgba(17,17,17,0.08)]">
          <div className="text-[12px] font-semibold text-[#111111]">Steps</div>
          <ol className="mt-2 space-y-2 text-[11px] text-muted-foreground">
            <li className="flex items-center gap-2">
              <span className="grid h-5 w-5 place-items-center rounded-full bg-black/5 text-[11px] font-semibold text-[#111111]">1</span>
              Upload selfie
            </li>
            <li className="flex items-center gap-2">
              <span className="grid h-5 w-5 place-items-center rounded-full bg-black/5 text-[11px] font-semibold text-[#111111]">2</span>
              Choose styles
            </li>
            <li className="flex items-center gap-2">
              <span className="grid h-5 w-5 place-items-center rounded-full bg-black/5 text-[11px] font-semibold text-[#111111]">3</span>
              Generate preview
            </li>
          </ol>
          <button
            type="button"
            disabled={!enabled || !selfieUrl || !selected.length || busy}
            onClick={generate}
            className={cn(
              "mt-4 h-11 w-full rounded-[20px] text-[12px] font-semibold text-[#111111] shadow-[0_14px_34px_rgba(212,175,55,0.22)]",
              !enabled || !selfieUrl || !selected.length || busy ? "bg-black/10" : "bg-[hsl(var(--gold))]"
            )}
          >
            {!enabled ? "Coming soon" : busy ? "Generating..." : "Generate"}
          </button>
        </div>
      </div>

      <input
        ref={fileRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={async (e) => {
          const file = e.target.files?.[0] ?? null;
          if (!file) return;
          setBusy(true);
          setNotice(null);
          try {
            const url = await uploadSelfie(file);
            if (url) setSelfieUrl(url);
            else setNotice("Upload failed. Please try again.");
          } finally {
            setBusy(false);
          }
        }}
      />

      <section className="flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div className="text-sm font-semibold text-[#111111]">Choose Styles</div>
          <button
            type="button"
            onClick={() => setSelected(presetStyle ? [presetStyle] : styles[0]?.key ? [styles[0].key] : [])}
            className="text-xs font-semibold text-muted-foreground underline underline-offset-4"
          >
            Reset
          </button>
        </div>
        <div className="grid grid-cols-2 gap-3">
          {styles.slice(0, 10).map((s) => {
            const on = selected.includes(s.key);
            return (
              <button
                key={s.key}
                type="button"
                disabled={!enabled}
                onClick={() => {
                  setSelected((prev) => {
                    if (prev.includes(s.key)) return prev.filter((x) => x !== s.key);
                    return [...prev, s.key].slice(0, 6);
                  });
                }}
                className={cn(
                  "relative overflow-hidden rounded-[24px] border bg-white text-left shadow-[0_16px_36px_rgba(17,17,17,0.08)]",
                  on ? "border-[hsl(var(--gold))]" : "border-black/10",
                  !enabled ? "opacity-60" : ""
                )}
              >
                <div className="aspect-square w-full overflow-hidden">
                  <SafeImage src={s.imageUrl} fallbackKey="default_style_image" alt={s.name} className="h-full w-full object-cover" />
                </div>
                <div className="p-3">
                  <div className="text-[12px] font-semibold text-[#111111]">{s.name}</div>
                  <div className="mt-1 text-[11px] text-muted-foreground">{on ? "Selected" : "Tap to select"}</div>
                </div>
                {on ? <div className="absolute right-3 top-3 rounded-full bg-[hsl(var(--gold))] px-2 py-1 text-[10px] font-semibold text-[#111111]">On</div> : null}
              </button>
            );
          })}
        </div>
      </section>

      <section className="flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div className="text-sm font-semibold text-[#111111]">AI Results</div>
          {results?.length ? <div className="text-xs font-semibold text-muted-foreground">{activeIndex + 1}/{results.length}</div> : null}
        </div>

        {results?.length ? (
          <div className="overflow-hidden rounded-[28px] border bg-white shadow-[0_22px_60px_rgba(17,17,17,0.10)]">
            <div className="relative aspect-[16/10] w-full overflow-hidden">
              <SafeImage src={active?.outputImageUrl} fallbackKey="default_style_image" alt="Result" className="h-full w-full object-cover" />
              <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/65 via-black/15 to-transparent p-4 text-white">
                <div className="text-sm font-semibold">{active?.styleKey.replaceAll("_", " ").toUpperCase()}</div>
                <div className="mt-2 flex gap-2">
                  <button type="button" onClick={saveCurrent} className="rounded-full bg-white/14 px-3 py-1 text-[11px] font-semibold backdrop-blur">
                    Save
                  </button>
                  <Link href="/city/barbers" className="rounded-full bg-[hsl(var(--gold))] px-3 py-1 text-[11px] font-semibold text-[#111111]">
                    Find Barbers
                  </Link>
                  <Link href="/booking/new" className="rounded-full bg-white/14 px-3 py-1 text-[11px] font-semibold backdrop-blur">
                    Book
                  </Link>
                </div>
              </div>
            </div>

            <div className="flex gap-2 overflow-x-auto p-3">
              {results.map((r, idx) => {
                const isActive = idx === activeIndex;
                return (
                  <button
                    key={r.styleKey}
                    type="button"
                    onClick={() => setActiveIndex(idx)}
                    className={cn(
                      "shrink-0 rounded-full border px-3 py-2 text-[12px] font-semibold leading-none transition",
                      isActive
                        ? "border-[hsl(var(--gold))] bg-[hsl(var(--gold))/0.10] text-[#111111]"
                        : "border-black/10 bg-white text-muted-foreground hover:border-black/20"
                    )}
                  >
                    {r.styleKey.replaceAll("_", " ")}
                  </button>
                );
              })}
            </div>
          </div>
        ) : (
          <div className="rounded-[26px] border bg-white p-4 text-sm text-muted-foreground">Generate to see previews.</div>
        )}
      </section>

      {notice ? (
        <div className="rounded-[26px] border bg-white p-4 text-sm text-muted-foreground shadow-[0_14px_34px_rgba(17,17,17,0.06)]">
          {notice}
        </div>
      ) : null}
    </div>
  );
}

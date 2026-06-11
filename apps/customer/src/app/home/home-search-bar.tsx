"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

export function HomeSearchBar({ placeholder }: { placeholder: string }) {
  const router = useRouter();
  const [q, setQ] = useState("");

  useEffect(() => {
    const v = q.trim();
    if (v.length < 2) return;
    const t = window.setTimeout(() => {
      router.push(`/city/search?q=${encodeURIComponent(v)}`);
    }, 280);
    return () => window.clearTimeout(t);
  }, [q, router]);

  return (
    <div className="flex h-12 items-center gap-3 rounded-full border border-[#2A2A2A] bg-[#111111] px-4 text-sm text-[#9E9E9E] shadow-[0_18px_44px_rgba(0,0,0,0.35)]">
      <span className="text-white/75">⌕</span>
      <input
        value={q}
        onChange={(e) => setQ(e.target.value)}
        placeholder={placeholder}
        className="min-w-0 flex-1 bg-transparent text-[13px] font-semibold text-white outline-none placeholder:text-white/60"
      />
      <button
        type="button"
        onClick={() => router.push("/city/search")}
        className="grid h-8 w-8 place-items-center rounded-full border border-[hsl(var(--gold))]/25 bg-[#1A1A1A] text-[hsl(var(--gold))]"
        aria-label="Search filters"
      >
        ⎯
      </button>
    </div>
  );
}


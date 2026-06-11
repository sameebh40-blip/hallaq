"use client";

import { useMemo } from "react";
import { useRouter } from "next/navigation";

import { Bell, ChevronDown, MapPin, QrCode } from "lucide-react";

type City = { id: string; name: string; country: string };

function setCityCookie(value: string) {
  const v = value.trim();
  if (!v) return;
  const maxAge = 60 * 60 * 24 * 365;
  document.cookie = `hallaq_city=${encodeURIComponent(v)}; path=/; max-age=${maxAge}; samesite=lax`;
}

export function HomeHeader({
  cities,
  selectedCity,
  unreadCount = 0
}: {
  cities: City[];
  selectedCity: string;
  unreadCount?: number;
}) {
  const router = useRouter();
  const options = useMemo(() => cities.filter((c) => c.name.trim()), [cities]);
  const current = selectedCity.trim() || options[0]?.name || "Manama";

  return (
    <header className="flex items-center gap-3">
      <div className="relative">
        <MapPin className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[hsl(var(--gold))]" />
        <select
          value={current}
          onChange={(e) => {
            setCityCookie(e.target.value);
            router.refresh();
          }}
          className="h-11 w-[170px] appearance-none rounded-full border border-[#2A2A2A] bg-[#111111] pl-9 pr-9 text-sm font-semibold text-white outline-none focus:border-[hsl(var(--gold))]/60"
        >
          {options.map((c) => (
            <option key={c.name} value={c.name} className="bg-[#111111] text-white">
              {c.name}, {c.country}
            </option>
          ))}
        </select>
        <ChevronDown className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[#9E9E9E]" />
      </div>

      <div className="flex flex-1 flex-col items-center leading-none">
        <div className="text-[12px] font-black tracking-[0.38em] text-[hsl(var(--gold))]">HALLAQ</div>
        <div className="mt-1 text-[10px] font-semibold tracking-[0.22em] text-[#9E9E9E]">BOOK. STYLE. SHINE.</div>
      </div>

      <div className="flex items-center gap-2">
        <button
          type="button"
          aria-label="Notifications"
          className="relative grid h-11 w-11 place-items-center rounded-full border border-[#2A2A2A] bg-[#111111] text-white"
          onClick={() => router.push("/notifications")}
        >
          <Bell className="h-5 w-5" />
          {unreadCount > 0 ? (
            <span className="absolute -right-1 -top-1 rounded-full border border-black/20 bg-[hsl(var(--gold))] px-1.5 py-0.5 text-[10px] font-extrabold leading-none text-black">
              {unreadCount > 99 ? "99+" : unreadCount}
            </span>
          ) : null}
        </button>
        <button
          type="button"
          aria-label="Scan QR"
          className="grid h-11 w-11 place-items-center rounded-full border border-[#2A2A2A] bg-[#111111] text-white"
          onClick={() => router.push("/scan")}
        >
          <QrCode className="h-5 w-5" />
        </button>
      </div>
    </header>
  );
}

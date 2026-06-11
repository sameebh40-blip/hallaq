"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";

import { cn } from "@hallaq/ui/cn";

import { createAppSupabaseBrowserClient } from "@/lib/supabase-browser";

type Status = "none" | "waiting" | "notified" | "unauthorized";

export function WaitlistClient({ barberId }: { barberId: string }) {
  const supabase = useMemo(() => createAppSupabaseBrowserClient(), []);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<Status>("none");
  const [position, setPosition] = useState<number | null>(null);
  const [etaMinutes, setEtaMinutes] = useState<number | null>(null);

  const refresh = useCallback(async () => {
    const {
      data: { user }
    } = await supabase.auth.getUser();
    if (!user) {
      setStatus("unauthorized");
      setPosition(null);
      setEtaMinutes(null);
      return;
    }

    const { data } = await supabase.rpc("get_waitlist_status", { p_barber: barberId });
    const row = (Array.isArray(data) ? data[0] : data) as {
      status?: string | null;
      waitlist_position?: number | null;
      position?: number | null;
      eta_minutes?: number | null;
    } | null;
    const s = String(row?.status ?? "none") as Status;
    setStatus((s === "waiting" || s === "notified" || s === "unauthorized") ? s : "none");
    setPosition(row?.waitlist_position ?? row?.position ?? null);
    setEtaMinutes(row?.eta_minutes ?? null);
  }, [barberId, supabase]);

  useEffect(() => {
    void refresh();
    const channel = supabase
      .channel("waitlist_status")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "waitlist_entries" },
        () => void refresh()
      )
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "notifications" }, () => void refresh())
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [supabase, refresh]);

  async function join() {
    if (busy) return;
    setBusy(true);
    try {
      const {
        data: { user }
      } = await supabase.auth.getUser();
      if (!user) {
        setStatus("unauthorized");
        return;
      }

      const { error } = await supabase.from("waitlist_entries").insert({ barber_id: barberId, profile_id: user.id });
      if (!error) await refresh();
    } finally {
      setBusy(false);
    }
  }

  async function cancel() {
    if (busy) return;
    setBusy(true);
    try {
      const { data } = await supabase.rpc("get_waitlist_status", { p_barber: barberId });
      const row = (Array.isArray(data) ? data[0] : data) as { status?: string | null } | null;
      if (row?.status !== "waiting") return;

      const { error } = await supabase
        .from("waitlist_entries")
        .update({ status: "cancelled" })
        .eq("barber_id", barberId);
      if (!error) await refresh();
    } finally {
      setBusy(false);
    }
  }

  if (status === "unauthorized") {
    return (
      <div className="rounded-[26px] border bg-white p-4 shadow-[0_16px_36px_rgba(17,17,17,0.08)]">
        <div className="text-sm font-semibold text-[#111111]">Sign in required</div>
        <div className="mt-1 text-[12px] text-muted-foreground">Sign in to join the waitlist and receive notifications.</div>
        <Link
          href={`/auth/sign-in?next=${encodeURIComponent(`/city/waitlist/${barberId}`)}`}
          className="mt-4 grid h-11 place-items-center rounded-[22px] bg-[hsl(var(--gold))] text-[12px] font-semibold text-[#111111] shadow-[0_14px_34px_rgba(212,175,55,0.22)]"
        >
          Sign In
        </Link>
      </div>
    );
  }

  const statusLabel = status === "notified" ? "Slot available" : status === "waiting" ? "Waiting" : "Not joined";

  return (
    <div className="flex flex-col gap-3">
      <div className="rounded-[28px] border bg-white p-4 shadow-[0_18px_48px_rgba(17,17,17,0.10)]">
        <div className="text-[11px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">WAITLIST</div>
        <div className="mt-2 text-sm font-semibold text-[#111111]">{statusLabel}</div>
        <div className="mt-1 text-[12px] text-muted-foreground">
          {status === "notified"
            ? "A slot is available now. Book before it’s gone."
            : "Join the waitlist when the barber is fully booked. You’ll be notified when a slot opens."}
        </div>

        <div className="mt-4 grid grid-cols-2 gap-3">
          <div className="rounded-[22px] bg-black/5 px-4 py-3">
            <div className="text-[10px] font-semibold text-muted-foreground">Your position</div>
            <div className="mt-1 text-base font-black text-[#111111]">{position ?? "—"}</div>
          </div>
          <div className="rounded-[22px] bg-black/5 px-4 py-3">
            <div className="text-[10px] font-semibold text-muted-foreground">Estimated wait</div>
            <div className="mt-1 text-base font-black text-[#111111]">{etaMinutes != null ? `${etaMinutes}m` : "—"}</div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <button
          type="button"
          disabled={busy || status === "waiting" || status === "notified"}
          onClick={join}
          className={cn(
            "h-12 rounded-[22px] text-[13px] font-semibold text-[#111111]",
            busy || status === "waiting" || status === "notified"
              ? "bg-black/10"
              : "bg-[hsl(var(--gold))] shadow-[0_18px_42px_rgba(212,175,55,0.25)]"
          )}
        >
          Join Waitlist
        </button>
        {status === "waiting" ? (
          <button type="button" disabled={busy} onClick={cancel} className="h-12 rounded-[22px] bg-black/5 text-[13px] font-semibold text-[#111111]">
            Cancel
          </button>
        ) : (
          <Link
            href={`/booking/new?barberId=${encodeURIComponent(barberId)}`}
            className="grid h-12 place-items-center rounded-[22px] bg-black/5 text-[13px] font-semibold text-[#111111]"
          >
            Book
          </Link>
        )}
      </div>

      {status === "notified" ? (
        <Link
          href={`/booking/new?barberId=${encodeURIComponent(barberId)}`}
          className="grid h-12 place-items-center rounded-[22px] bg-[hsl(var(--gold))] text-[13px] font-semibold text-[#111111] shadow-[0_18px_42px_rgba(212,175,55,0.25)]"
        >
          Book Now
        </Link>
      ) : null}
    </div>
  );
}

"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import { cn } from "@hallaq/ui/cn";

import { createAppSupabaseBrowserClient } from "@/lib/supabase-browser";

type PurchaseResult = { gift_card_id: string; code: string };

export function GiftCardsClient() {
  const supabase = useMemo(() => createAppSupabaseBrowserClient(), []);
  const [busy, setBusy] = useState(false);
  const [walletBalance, setWalletBalance] = useState<number | null>(null);
  const [lastCode, setLastCode] = useState<string | null>(null);
  const [redeemCode, setRedeemCode] = useState("");
  const [notice, setNotice] = useState<string | null>(null);

  const refreshWallet = useCallback(async () => {
    const {
      data: { user }
    } = await supabase.auth.getUser();
    if (!user) {
      setWalletBalance(null);
      return;
    }
    const { data } = await supabase.from("gift_card_wallet").select("balance_bhd").eq("profile_id", user.id).maybeSingle();
    setWalletBalance(data?.balance_bhd != null ? Number(data.balance_bhd) : 0);
  }, [supabase]);

  useEffect(() => {
    void refreshWallet();
    const channel = supabase.channel("gift_cards").on("postgres_changes", { event: "*", schema: "public", table: "gift_card_wallet" }, () => void refreshWallet()).subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [supabase, refreshWallet]);

  const ensureAuth = useCallback(async () => {
    const {
      data: { user }
    } = await supabase.auth.getUser();
    if (!user) {
      window.location.href = "/auth/sign-in?next=/city/gift-cards";
      return null;
    }
    return user;
  }, [supabase]);

  const purchase = useCallback(async (amount: number) => {
    if (busy) return;
    setNotice(null);
    setBusy(true);
    try {
      const user = await ensureAuth();
      if (!user) return;

      const { data, error } = await supabase.rpc("gift_card_purchase", { p_amount_bhd: amount });
      if (error) {
        setNotice("Purchase failed. Please try again.");
        return;
      }
      const row = (Array.isArray(data) ? data[0] : data) as PurchaseResult | null;
      if (!row?.code) {
        setNotice("Purchase failed. Please try again.");
        return;
      }
      setLastCode(row.code);
      setNotice("Gift card created.");
    } finally {
      setBusy(false);
    }
  }, [busy, ensureAuth, supabase]);

  const redeem = useCallback(async () => {
    if (busy) return;
    setNotice(null);
    setBusy(true);
    try {
      const user = await ensureAuth();
      if (!user) return;
      const code = redeemCode.trim().toUpperCase();
      if (!code) return;

      const { data, error } = await supabase.rpc("gift_card_redeem", { p_code: code });
      if (error) {
        setNotice("Invalid or already redeemed code.");
        return;
      }
      setNotice(`Redeemed. Wallet balance: BD ${Number(data ?? 0).toFixed(3)}`);
      setRedeemCode("");
      await refreshWallet();
    } finally {
      setBusy(false);
    }
  }, [busy, ensureAuth, redeemCode, refreshWallet, supabase]);

  return (
    <div className="flex flex-col gap-4">
      <div className="overflow-hidden rounded-[28px] border bg-white p-5 shadow-[0_18px_48px_rgba(17,17,17,0.10)]">
        <div className="text-[11px] font-semibold tracking-[0.22em] text-[hsl(var(--gold))]">GIFT CARDS</div>
        <div className="mt-2 text-sm font-semibold text-[#111111]">Send value. Book instantly.</div>
        <div className="mt-1 text-[12px] text-muted-foreground">Purchase a gift card, share the code, and redeem to wallet.</div>
        <div className="mt-4 rounded-[22px] bg-black/5 px-4 py-3">
          <div className="text-[10px] font-semibold text-muted-foreground">Wallet balance</div>
          <div className="mt-1 text-base font-black text-[#111111]">BD {(walletBalance ?? 0).toFixed(3)}</div>
        </div>
      </div>

      <div className="rounded-[28px] border bg-white p-4 shadow-[0_16px_36px_rgba(17,17,17,0.08)]">
        <div className="text-sm font-semibold text-[#111111]">Purchase</div>
        <div className="mt-3 grid grid-cols-3 gap-2">
          {[10, 20, 50].map((amt) => (
            <button
              key={amt}
              type="button"
              disabled={busy}
              onClick={() => void purchase(amt)}
              className={cn(
                "h-12 rounded-[22px] text-[12px] font-semibold text-[#111111]",
                busy ? "bg-black/10" : "bg-[hsl(var(--gold))] shadow-[0_14px_34px_rgba(212,175,55,0.22)]"
              )}
            >
              BD {amt}
            </button>
          ))}
        </div>

        {lastCode ? (
          <div className="mt-4 rounded-[22px] border border-[hsl(var(--gold))/0.35] bg-[hsl(var(--gold))/0.10] p-4">
            <div className="text-[10px] font-semibold tracking-[0.22em] text-black/60">GIFT CODE</div>
            <div className="mt-2 text-xl font-black text-[#111111]">{lastCode}</div>
            <div className="mt-3 grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={() => navigator.clipboard.writeText(lastCode)}
                className="h-11 rounded-[20px] bg-black/5 text-[12px] font-semibold text-[#111111]"
              >
                Copy
              </button>
              <button
                type="button"
                onClick={() => {
                  const text = `Hallaq Gift Card: ${lastCode}`;
                  const nav = navigator as Navigator & { share?: (data: { text?: string }) => Promise<void> };
                  if (nav.share) void nav.share({ text });
                  else void navigator.clipboard.writeText(text);
                }}
                className="h-11 rounded-[20px] bg-[#111111] text-[12px] font-semibold text-white"
              >
                Send
              </button>
            </div>
          </div>
        ) : null}
      </div>

      <div className="rounded-[28px] border bg-white p-4 shadow-[0_16px_36px_rgba(17,17,17,0.08)]">
        <div className="text-sm font-semibold text-[#111111]">Redeem</div>
        <div className="mt-3 flex items-center gap-2">
          <input
            value={redeemCode}
            onChange={(e) => setRedeemCode(e.target.value)}
            placeholder="Enter gift code"
            className="h-12 flex-1 rounded-[22px] border border-black/10 bg-white px-4 text-[13px] outline-none shadow-[0_10px_30px_rgba(17,17,17,0.05)] placeholder:text-muted-foreground focus:border-black/20"
          />
          <button
            type="button"
            disabled={busy || !redeemCode.trim()}
            onClick={() => void redeem()}
            className={cn(
              "h-12 rounded-[22px] px-4 text-[12px] font-semibold text-[#111111]",
              busy || !redeemCode.trim()
                ? "bg-black/10"
                : "bg-[hsl(var(--gold))] shadow-[0_14px_34px_rgba(212,175,55,0.22)]"
            )}
          >
            Redeem
          </button>
        </div>
      </div>

      {notice ? (
        <div className="rounded-[26px] border bg-white p-4 text-sm text-muted-foreground shadow-[0_14px_34px_rgba(17,17,17,0.06)]">
          {notice}
        </div>
      ) : null}
    </div>
  );
}

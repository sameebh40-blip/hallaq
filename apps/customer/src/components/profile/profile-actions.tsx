"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import QRCode from "qrcode";
import { Button } from "@hallaq/ui/button";
import { cn } from "@hallaq/ui/cn";
import {
  CalendarClock,
  Check,
  MessageSquareText,
  Phone,
  Share2,
  UserPlus,
  UserRoundCheck,
  X,
} from "lucide-react";

import { createAppSupabaseBrowserClient } from "@/lib/supabase-browser";

type FollowTargetType = "barber" | "shop";

type ActionType = "link" | "anchor" | "button";

type ProfileAction = {
  id: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  type: ActionType;
  href?: string;
  onClick?: () => void | Promise<void>;
  disabled?: boolean;
  tone?: "gold" | "dark";
};

export function toTelHref(raw: string | null | undefined) {
  const digits = String(raw ?? "").replace(/[^\d+]/g, "");
  return digits ? `tel:${digits}` : null;
}

export function toWaHref(raw: string | null | undefined) {
  const digits = String(raw ?? "").replace(/[^\d]/g, "");
  return digits ? `https://wa.me/${digits}` : null;
}

export function toMapsHref(args: { googleMapsUrl?: string | null; lat?: number | null; lng?: number | null; label?: string | null }) {
  const direct = String(args.googleMapsUrl ?? "").trim();
  if (direct) return direct;
  if (typeof args.lat === "number" && typeof args.lng === "number") {
    return `https://www.google.com/maps?q=${encodeURIComponent(`${args.lat},${args.lng}`)}`;
  }
  const label = String(args.label ?? "").trim();
  return label ? `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(label)}` : null;
}

function ActionButton({ action }: { action: ProfileAction }) {
  const baseClass =
    action.tone === "gold"
      ? "border-[hsl(var(--gold))]/40 bg-[linear-gradient(180deg,rgba(212,175,55,0.92),rgba(179,140,24,0.96))] text-black shadow-[0_18px_38px_rgba(212,175,55,0.28)] hover:brightness-105"
      : "border-white/10 bg-white/[0.04] text-white hover:border-[hsl(var(--gold))]/35 hover:text-[hsl(var(--gold))]";
  const className = cn(
    "flex h-14 items-center justify-center gap-2 rounded-[20px] border text-[13px] font-semibold transition-all duration-300",
    baseClass,
    action.disabled ? "pointer-events-none opacity-45" : "",
  );

  if (action.type === "link") {
    return (
      <Link href={action.href ?? "#"} className={className}>
        <action.icon className="h-4.5 w-4.5" />
        <span>{action.label}</span>
      </Link>
    );
  }

  if (action.type === "anchor") {
    return (
      <a href={action.href ?? "#"} target="_blank" rel="noreferrer" className={className}>
        <action.icon className="h-4.5 w-4.5" />
        <span>{action.label}</span>
      </a>
    );
  }

  return (
    <button type="button" onClick={() => void action.onClick?.()} className={className} disabled={action.disabled}>
      <action.icon className="h-4.5 w-4.5" />
      <span>{action.label}</span>
    </button>
  );
}

function ShareQrModal({
  open,
  onClose,
  title,
  url,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  url: string;
}) {
  const [svg, setSvg] = useState<string>("");
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (!open) return;
    void QRCode.toString(url, {
      type: "svg",
      margin: 1,
      width: 220,
      color: {
        dark: "#D4AF37",
        light: "#000000",
      },
    }).then(setSvg);
  }, [open, url]);

  useEffect(() => {
    if (!copied) return;
    const timer = window.setTimeout(() => setCopied(false), 1800);
    return () => window.clearTimeout(timer);
  }, [copied]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[80] bg-black/80 px-4 py-8 backdrop-blur-sm" onClick={onClose}>
      <div
        className="mx-auto mt-10 max-w-md rounded-[28px] border border-[hsl(var(--gold))]/18 bg-[#080808] p-5 shadow-[0_32px_80px_rgba(0,0,0,0.65)]"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex items-center justify-between gap-3">
          <div>
            <div className="text-[11px] font-semibold uppercase tracking-[0.32em] text-[hsl(var(--gold))]">Share Profile</div>
            <div className="mt-1 text-lg font-semibold text-white">{title}</div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="grid h-10 w-10 place-items-center rounded-full border border-white/10 bg-white/[0.03] text-white transition hover:border-[hsl(var(--gold))]/35 hover:text-[hsl(var(--gold))]"
          >
            <X className="h-4.5 w-4.5" />
          </button>
        </div>

        <div className="mt-5 rounded-[24px] border border-[hsl(var(--gold))]/15 bg-[radial-gradient(circle_at_top,rgba(212,175,55,0.14),transparent_55%),linear-gradient(180deg,#0D0D0D,#050505)] p-5">
          <div className="mx-auto grid h-[228px] w-[228px] place-items-center rounded-[22px] border border-[hsl(var(--gold))]/22 bg-black shadow-[0_18px_45px_rgba(0,0,0,0.38)]">
            {svg ? <div dangerouslySetInnerHTML={{ __html: svg }} /> : <div className="h-12 w-12 animate-spin rounded-full border-2 border-[hsl(var(--gold))]/25 border-t-[hsl(var(--gold))]" />}
          </div>
          <div className="mt-4 rounded-[20px] border border-white/10 bg-white/[0.03] px-4 py-3 text-center text-xs text-[#B8B8B8]">
            Scan to open this profile instantly
          </div>
        </div>

        <div className="mt-4 rounded-[20px] border border-white/10 bg-white/[0.03] px-4 py-3 text-xs text-[#B8B8B8]">{url}</div>

        <div className="mt-4 grid grid-cols-2 gap-3">
          <Button
            type="button"
            className="h-12 rounded-[18px]"
            onClick={async () => {
              if (navigator.share) {
                await navigator.share({ title, url });
                return;
              }
              await navigator.clipboard.writeText(url);
              setCopied(true);
            }}
          >
            <Share2 className="mr-2 h-4 w-4" />
            Share
          </Button>
          <button
            type="button"
            onClick={async () => {
              await navigator.clipboard.writeText(url);
              setCopied(true);
            }}
            className="flex h-12 items-center justify-center gap-2 rounded-[18px] border border-white/10 bg-white/[0.03] text-sm font-semibold text-white transition hover:border-[hsl(var(--gold))]/35 hover:text-[hsl(var(--gold))]"
          >
            {copied ? <Check className="h-4 w-4" /> : <Share2 className="h-4 w-4" />}
            {copied ? "Copied" : "Copy Link"}
          </button>
        </div>
      </div>
    </div>
  );
}

export function ProfileActionBar({
  targetType,
  targetId,
  title,
  bookingHref,
  phone,
  whatsapp,
  sharePath,
  initialFollowers,
}: {
  targetType: FollowTargetType;
  targetId: string;
  title: string;
  bookingHref?: string | null;
  phone?: string | null;
  whatsapp?: string | null;
  sharePath: string;
  initialFollowers: number;
}) {
  const router = useRouter();
  const [followers, setFollowers] = useState(initialFollowers);
  const [following, setFollowing] = useState(false);
  const [busy, setBusy] = useState(false);
  const [shareOpen, setShareOpen] = useState(false);
  const [feedback, setFeedback] = useState<string | null>(null);

  const telHref = useMemo(() => toTelHref(phone), [phone]);
  const waHref = useMemo(() => toWaHref(whatsapp) ?? toWaHref(phone), [phone, whatsapp]);
  const shareUrl = useMemo(() => {
    if (typeof window === "undefined") return sharePath;
    return `${window.location.origin}${sharePath}`;
  }, [sharePath]);

  useEffect(() => {
    if (!feedback) return;
    const timer = window.setTimeout(() => setFeedback(null), 1800);
    return () => window.clearTimeout(timer);
  }, [feedback]);

  useEffect(() => {
    let active = true;
    (async () => {
      const supabase = createAppSupabaseBrowserClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user || !active) return;
      const { data } = await supabase
        .from("follows")
        .select("target_id")
        .eq("profile_id", user.id)
        .eq("target_type", targetType)
        .eq("target_id", targetId)
        .maybeSingle();
      if (!active) return;
      setFollowing(Boolean(data));
    })();
    return () => {
      active = false;
    };
  }, [targetId, targetType]);

  const actions: ProfileAction[] = [
    {
      id: "book",
      label: "Book Now",
      icon: CalendarClock,
      type: "link",
      href: bookingHref ?? "#",
      disabled: !bookingHref,
      tone: "gold",
    },
    {
      id: "message",
      label: "Message",
      icon: MessageSquareText,
      type: "anchor",
      href: waHref ?? "#",
      disabled: !waHref,
    },
    {
      id: "call",
      label: "Call",
      icon: Phone,
      type: "anchor",
      href: telHref ?? "#",
      disabled: !telHref,
    },
    {
      id: "whatsapp",
      label: "WhatsApp",
      icon: MessageSquareText,
      type: "anchor",
      href: waHref ?? "#",
      disabled: !waHref,
    },
    {
      id: "follow",
      label: following ? `${followers.toLocaleString()} Following` : `${followers.toLocaleString()} Follow`,
      icon: following ? UserRoundCheck : UserPlus,
      type: "button",
      disabled: busy,
      onClick: async () => {
        if (busy) return;
        setBusy(true);
        try {
          const supabase = createAppSupabaseBrowserClient();
          const {
            data: { user },
          } = await supabase.auth.getUser();
          if (!user) {
            window.location.href = `/auth/sign-in?next=${encodeURIComponent(window.location.pathname + window.location.search)}`;
            return;
          }

          if (following) {
            const { error } = await supabase
              .from("follows")
              .delete()
              .eq("profile_id", user.id)
              .eq("target_type", targetType)
              .eq("target_id", targetId);
            if (error) throw error;
            setFollowing(false);
            setFollowers((value) => Math.max(0, value - 1));
            setFeedback("Unfollowed");
          } else {
            const { error } = await supabase
              .from("follows")
              .insert({ profile_id: user.id, target_type: targetType, target_id: targetId });
            if (error) throw error;
            setFollowing(true);
            setFollowers((value) => value + 1);
            setFeedback("Following");
          }
          router.refresh();
        } finally {
          setBusy(false);
        }
      },
    },
    {
      id: "share",
      label: "Share",
      icon: Share2,
      type: "button",
      onClick: () => setShareOpen(true),
    },
  ];

  return (
    <>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
        {actions.map((action) => (
          <ActionButton key={action.id} action={action} />
        ))}
      </div>
      {feedback ? (
        <div className="pointer-events-none fixed inset-x-0 bottom-24 z-[70] flex justify-center px-4">
          <div className="rounded-full border border-[#D4AF37]/28 bg-black/88 px-4 py-2 text-xs font-semibold uppercase tracking-[0.22em] text-[#D4AF37] shadow-[0_18px_45px_rgba(0,0,0,0.45)]">
            {feedback}
          </div>
        </div>
      ) : null}
      <ShareQrModal open={shareOpen} onClose={() => setShareOpen(false)} title={title} url={shareUrl} />
    </>
  );
}

"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";

import { createAppSupabaseBrowserClient } from "@/lib/supabase-browser";
import { Button } from "@hallaq/ui/button";
import { cn } from "@hallaq/ui/cn";
import { Bookmark, EyeOff, Heart, MessageCircle, Share2, UserPlus, UserX } from "lucide-react";

import { SafeImage } from "@/components/safe-image";

export type DiscoverItem = {
  id: string;
  caption: string | null;
  mediaType: "image" | "video";
  mediaUrl: string;
  posterUrl: string | null;
  authorType: "barber" | "shop";
  authorId: string;
  authorName: string;
  shopName: string | null;
  authorAvatarUrl: string;
  likesCount: number;
  commentsCount: number;
  savesCount: number;
};

type LocalState = {
  liked: boolean;
  saved: boolean;
  following: boolean;
  likesCount: number;
  savesCount: number;
};

export function DiscoverFeed({ items }: { items: DiscoverItem[] }) {
  const initial = useMemo(() => {
    const map = new Map<string, LocalState>();
    for (const it of items) {
      map.set(it.id, {
        liked: false,
        saved: false,
        following: false,
        likesCount: it.likesCount,
        savesCount: it.savesCount
      });
    }
    return map;
  }, [items]);

  const [hiddenIds, setHiddenIds] = useState<Set<string>>(() => new Set());
  const visibleItems = useMemo(() => items.filter((it) => !hiddenIds.has(it.id)), [items, hiddenIds]);

  useEffect(() => {
    const root = containerRef.current;
    if (!root) return;

    const observer = new IntersectionObserver(
      (entries) => {
        let best: { id: string; ratio: number } | null = null;
        for (const e of entries) {
          if (!e.isIntersecting) continue;
          const id = (e.target as HTMLElement).dataset.reelId;
          if (!id) continue;
          if (!best || e.intersectionRatio > best.ratio) best = { id, ratio: e.intersectionRatio };
        }
        if (best) setActiveId(best.id);
      },
      { root, threshold: [0.55, 0.65, 0.75, 0.85] }
    );

    for (const el of sectionRefs.current.values()) observer.observe(el);
    return () => observer.disconnect();
  }, [items]);

  const [state, setState] = useState(() => initial);
  const [busy, setBusy] = useState<string | null>(null);
  const [commentTarget, setCommentTarget] = useState<DiscoverItem | null>(null);
  const [comments, setComments] = useState<Array<{ id: string; text: string; created_at: string; name: string }> | null>(
    null
  );
  const [commentText, setCommentText] = useState("");
  const containerRef = useRef<HTMLDivElement | null>(null);
  const sectionRefs = useRef(new Map<string, HTMLElement>());
  const [activeId, setActiveId] = useState<string | null>(() => items[0]?.id ?? null);

  useEffect(() => {
    if (activeId && hiddenIds.has(activeId)) {
      setActiveId(visibleItems[0]?.id ?? null);
    }
  }, [activeId, hiddenIds, visibleItems]);

  function ReelVideo({ item, isActive }: { item: DiscoverItem; isActive: boolean }) {
    const [attempt, setAttempt] = useState(0);
    const [phase, setPhase] = useState<"loading" | "ready" | "failed">("loading");
    const [loadingTick, setLoadingTick] = useState(0);
    const videoRef = useRef<HTMLVideoElement | null>(null);

    useEffect(() => {
      const v = videoRef.current;
      if (!v) return;
      if (!isActive) {
        try {
          v.pause();
        } catch {}
      }
    }, [isActive]);

    useEffect(() => {
      if (!isActive) return;
      if (phase !== "ready") return;
      const v = videoRef.current;
      if (!v) return;
      const p = v.play();
      if (p && typeof (p as Promise<unknown>).catch === "function") {
        (p as Promise<unknown>).catch(() => {});
      }
    }, [isActive, phase]);

    useEffect(() => {
      if (!isActive) return;
      if (phase !== "loading") return;
      const t = window.setTimeout(() => setPhase("failed"), 10_000);
      return () => window.clearTimeout(t);
    }, [isActive, phase, loadingTick]);

    if (!isActive) {
      return (
        <SafeImage
          className="h-full w-full object-cover"
          src={item.posterUrl ?? ""}
          fallbackKey="default_reel_thumbnail"
          alt={item.caption ?? "Reel"}
        />
      );
    }

    if (phase === "failed") {
      return (
        <div className="relative h-full w-full">
          <SafeImage
            className="h-full w-full object-cover"
            src={item.posterUrl ?? ""}
            fallbackKey="default_reel_thumbnail"
            alt={item.caption ?? "Reel"}
          />
          <div className="absolute inset-0 grid place-items-center bg-black/55">
            <button
              type="button"
              onClick={() => {
                setPhase("loading");
                setAttempt((n) => n + 1);
              }}
              className="rounded-2xl bg-white/15 px-5 py-3 text-sm font-semibold text-white backdrop-blur"
            >
              Retry
            </button>
          </div>
        </div>
      );
    }

    return (
      <div className="relative h-full w-full">
        <SafeImage
          className="h-full w-full object-cover"
          src={item.posterUrl ?? ""}
          fallbackKey="default_reel_thumbnail"
          alt={item.caption ?? "Reel"}
        />
        <video
          key={attempt}
          ref={videoRef}
          className={cn("absolute inset-0 h-full w-full object-cover", phase === "ready" ? "opacity-100" : "opacity-0")}
          src={item.mediaUrl}
          muted
          playsInline
          loop
          controls
          preload="metadata"
          onLoadStart={() => {
            setPhase("loading");
            setLoadingTick((n) => n + 1);
          }}
          onWaiting={() => {
            setPhase("loading");
            setLoadingTick((n) => n + 1);
          }}
          onCanPlay={() => setPhase("ready")}
          onPlaying={() => setPhase("ready")}
          onError={() => setPhase("failed")}
        />
        {phase === "loading" ? (
          <div className="absolute inset-0 grid place-items-center bg-black/55">
            <div className="h-10 w-10 animate-spin rounded-full border-2 border-white/25 border-t-white" />
          </div>
        ) : null}
      </div>
    );
  }

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const supabase = createAppSupabaseBrowserClient();
      const {
        data: { user }
      } = await supabase.auth.getUser();
      if (!user || cancelled) return;

      const reelIds = items.map((i) => i.id);
      const barberIds = items.filter((i) => i.authorType === "barber").map((i) => i.authorId);
      const shopIds = items.filter((i) => i.authorType === "shop").map((i) => i.authorId);

      const followOr = [
        barberIds.length ? `and(target_type.eq.barber,target_id.in.(${barberIds.join(",")}))` : null,
        shopIds.length ? `and(target_type.eq.shop,target_id.in.(${shopIds.join(",")}))` : null
      ]
        .filter(Boolean)
        .join(",");

      const [{ data: likes }, { data: saves }, { data: follows }, { data: hides }] = await Promise.all([
        supabase
          .from("reel_likes")
          .select("reel_id")
          .eq("profile_id", user.id)
          .in("reel_id", reelIds) as unknown as PromiseLike<{ data: Array<{ reel_id: string }> | null }>,
        supabase
          .from("reel_saves")
          .select("reel_id")
          .eq("profile_id", user.id)
          .in("reel_id", reelIds) as unknown as PromiseLike<{ data: Array<{ reel_id: string }> | null }>,
        followOr
          ? (supabase
              .from("follows")
              .select("target_type, target_id")
              .eq("profile_id", user.id)
              .or(followOr) as unknown as PromiseLike<{ data: Array<{ target_type: string; target_id: string }> | null }>)
          : (Promise.resolve({ data: [] }) as PromiseLike<{ data: Array<{ target_type: string; target_id: string }> | null }>)
        ,
        supabase
          .from("reel_hides")
          .select("reel_id")
          .eq("profile_id", user.id)
          .in("reel_id", reelIds) as unknown as PromiseLike<{ data: Array<{ reel_id: string }> | null }>
      ]);

      if (cancelled) return;

      const likedSet = new Set((likes ?? []).map((r) => r.reel_id));
      const savedSet = new Set((saves ?? []).map((r) => r.reel_id));
      const followSet = new Set((follows ?? []).map((r) => `${r.target_type}:${r.target_id}`));
      const hideSet = new Set((hides ?? []).map((r) => r.reel_id));
      setHiddenIds(hideSet);

      setState((prev) => {
        const next = new Map(prev);
        for (const it of items) {
          const current = next.get(it.id);
          if (!current) continue;
          next.set(it.id, {
            ...current,
            liked: likedSet.has(it.id),
            saved: savedSet.has(it.id),
            following: followSet.has(`${it.authorType}:${it.authorId}`)
          });
        }
        return next;
      });
    })();

    return () => {
      cancelled = true;
    };
  }, [items]);

  function requireAuthRedirect() {
    window.location.href = "/auth/sign-in?next=/discover";
  }

  async function getViewerId() {
    const supabase = createAppSupabaseBrowserClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    return user?.id ?? null;
  }

  async function toggleLike(reelId: string) {
    if (busy) return;
    setBusy(reelId);
    try {
      const viewerId = await getViewerId();
      if (!viewerId) {
        requireAuthRedirect();
        return;
      }
      const supabase = createAppSupabaseBrowserClient();
      const current = state.get(reelId);
      if (!current) return;

      if (current.liked) {
        await supabase.from("reel_likes").delete().eq("reel_id", reelId).eq("profile_id", viewerId);
        setState((prev) => {
          const next = new Map(prev);
          next.set(reelId, { ...current, liked: false, likesCount: Math.max(0, current.likesCount - 1) });
          return next;
        });
      } else {
        await supabase.from("reel_likes").insert({ reel_id: reelId, profile_id: viewerId });
        setState((prev) => {
          const next = new Map(prev);
          next.set(reelId, { ...current, liked: true, likesCount: current.likesCount + 1 });
          return next;
        });
      }
    } finally {
      setBusy(null);
    }
  }

  async function toggleSave(reelId: string) {
    if (busy) return;
    setBusy(reelId);
    try {
      const viewerId = await getViewerId();
      if (!viewerId) {
        requireAuthRedirect();
        return;
      }
      const supabase = createAppSupabaseBrowserClient();
      const current = state.get(reelId);
      if (!current) return;

      if (current.saved) {
        await supabase.from("reel_saves").delete().eq("reel_id", reelId).eq("profile_id", viewerId);
        setState((prev) => {
          const next = new Map(prev);
          next.set(reelId, { ...current, saved: false, savesCount: Math.max(0, current.savesCount - 1) });
          return next;
        });
      } else {
        await supabase.from("reel_saves").insert({ reel_id: reelId, profile_id: viewerId });
        setState((prev) => {
          const next = new Map(prev);
          next.set(reelId, { ...current, saved: true, savesCount: current.savesCount + 1 });
          return next;
        });
      }
    } finally {
      setBusy(null);
    }
  }

  async function hideReel(reelId: string) {
    if (busy) return;
    setBusy(reelId);
    try {
      const viewerId = await getViewerId();
      if (!viewerId) {
        requireAuthRedirect();
        return;
      }
      const supabase = createAppSupabaseBrowserClient();
      await supabase.from("reel_hides").insert({ reel_id: reelId, profile_id: viewerId });
      setHiddenIds((prev) => {
        const next = new Set(prev);
        next.add(reelId);
        return next;
      });
    } finally {
      setBusy(null);
    }
  }

  async function toggleFollow(targetType: "barber" | "shop", targetId: string, reelId: string) {
    if (busy) return;
    setBusy(reelId);
    try {
      const viewerId = await getViewerId();
      if (!viewerId) {
        requireAuthRedirect();
        return;
      }
      const supabase = createAppSupabaseBrowserClient();
      const current = state.get(reelId);
      if (!current) return;

      if (current.following) {
        await supabase.from("follows").delete().eq("profile_id", viewerId).eq("target_type", targetType).eq("target_id", targetId);
        setState((prev) => {
          const next = new Map(prev);
          next.set(reelId, { ...current, following: false });
          return next;
        });
      } else {
        await supabase.from("follows").insert({ profile_id: viewerId, target_type: targetType, target_id: targetId });
        setState((prev) => {
          const next = new Map(prev);
          next.set(reelId, { ...current, following: true });
          return next;
        });
      }
    } finally {
      setBusy(null);
    }
  }

  async function share(url: string, reelId: string) {
    try {
      const viewerId = await getViewerId();
      if (!viewerId) {
        requireAuthRedirect();
        return;
      }
      const supabase = createAppSupabaseBrowserClient();
      if (navigator.share) {
        await navigator.share({ url });
      } else {
        await navigator.clipboard.writeText(url);
        alert("Link copied.");
      }
      await supabase.rpc("increment_reel_share", { reel: reelId });
    } catch {}
  }

  async function openComments(item: DiscoverItem) {
    const viewerId = await getViewerId();
    if (!viewerId) {
      requireAuthRedirect();
      return;
    }
    setCommentTarget(item);
    setComments(null);
    const supabase = createAppSupabaseBrowserClient();
    const { data } = await supabase
      .from("reel_comments")
      .select("id, text, created_at, profiles(full_name)")
      .eq("reel_id", item.id)
      .order("created_at", { ascending: false })
      .limit(50);

    setComments(
      (data ?? []).map((r) => ({
        id: r.id as string,
        text: (r.text as string) ?? "",
        created_at: (r.created_at as string) ?? "",
        name: ((r.profiles as { full_name?: string | null } | null)?.full_name ?? "User").trim() || "User"
      }))
    );
  }

  async function sendComment() {
    if (!commentTarget) return;
    const text = commentText.trim();
    if (!text) return;

    const viewerId = await getViewerId();
    if (!viewerId) {
      requireAuthRedirect();
      return;
    }

    const supabase = createAppSupabaseBrowserClient();
    const { error } = await supabase.from("reel_comments").insert({ reel_id: commentTarget.id, profile_id: viewerId, text });
    if (error) return;
    setCommentText("");
    await openComments(commentTarget);
  }

  return (
    <>
      <div
        ref={containerRef}
        className="h-[calc(100dvh-132px)] overflow-y-auto scroll-smooth [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden snap-y snap-mandatory"
      >
        {visibleItems.map((it) => {
          const st = state.get(it.id);
          const authorHref =
            it.authorType === "barber"
              ? `/barber/${it.authorId}?source=reel&reelId=${encodeURIComponent(it.id)}&tab=portfolio`
              : `/shop/${it.authorId}?source=reel&reelId=${encodeURIComponent(it.id)}&tab=portfolio`;
          const bookHref = `/booking/new?${new URLSearchParams(
            it.authorType === "barber"
              ? { barberId: it.authorId, reelId: it.id, source: "reel" }
              : { shopId: it.authorId, reelId: it.id, source: "reel" }
          ).toString()}`;

          return (
            <section
              key={it.id}
              className="relative h-[calc(100dvh-132px)] snap-start bg-black"
              data-reel-id={it.id}
              ref={(el) => {
                if (!el) {
                  sectionRefs.current.delete(it.id);
                  return;
                }
                sectionRefs.current.set(it.id, el);
              }}
            >
              {it.mediaType === "video" ? (
                <ReelVideo item={it} isActive={activeId === it.id} />
              ) : (
                <SafeImage
                  className="h-full w-full object-cover"
                  src={it.mediaUrl}
                  fallbackKey="default_reel_thumbnail"
                  alt={it.caption ?? "Reel"}
                />
              )}

              <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-black/25 via-transparent to-black/55" />

              <div className="absolute left-3 right-3 top-3 flex items-center justify-between gap-2">
                <Link href={authorHref} className="flex items-center gap-2 rounded-full bg-black/35 px-3 py-2 backdrop-blur">
                  <div className="h-9 w-9 overflow-hidden rounded-full border border-white/15 bg-black/20">
                    <SafeImage
                      src={it.authorAvatarUrl}
                      fallbackKey={it.authorType === "barber" ? "default_barber_avatar" : "default_shop_logo"}
                      alt={it.authorName}
                      className="h-full w-full object-cover"
                    />
                  </div>
                  <div className="flex flex-col">
                    <div className="text-xs font-semibold text-white line-clamp-1">{it.authorName}</div>
                    {it.shopName ? <div className="text-[11px] text-white/80 line-clamp-1">{it.shopName}</div> : null}
                  </div>
                </Link>

                <Button asChild size="sm" className="rounded-2xl px-4">
                  <Link href={bookHref}>Book Now</Link>
                </Button>
              </div>

              <div className="absolute bottom-4 left-3 right-16">
                <div className="text-sm font-semibold text-white line-clamp-2">{it.caption ?? "—"}</div>
              </div>

              <div className="absolute bottom-4 right-3 flex flex-col items-center gap-2">
                <button
                  type="button"
                  disabled={busy === it.id}
                  onClick={() => toggleLike(it.id)}
                  className={cn(
                    "flex w-11 flex-col items-center gap-1 rounded-2xl bg-black/35 px-2 py-2 text-white backdrop-blur",
                    st?.liked ? "ring-1 ring-white/20" : ""
                  )}
                >
                  <Heart className={cn("h-5 w-5", st?.liked ? "fill-white" : "")} />
                  <span className="text-[10px]">{st?.likesCount ?? it.likesCount}</span>
                </button>

                <button
                  type="button"
                  disabled={busy === it.id}
                  onClick={() => openComments(it)}
                  className="flex w-11 flex-col items-center gap-1 rounded-2xl bg-black/35 px-2 py-2 text-white backdrop-blur"
                >
                  <MessageCircle className="h-5 w-5" />
                  <span className="text-[10px]">{it.commentsCount}</span>
                </button>

                <button
                  type="button"
                  disabled={busy === it.id}
                  onClick={() => toggleSave(it.id)}
                  className={cn(
                    "flex w-11 flex-col items-center gap-1 rounded-2xl bg-black/35 px-2 py-2 text-white backdrop-blur",
                    st?.saved ? "ring-1 ring-white/20" : ""
                  )}
                >
                  <Bookmark className={cn("h-5 w-5", st?.saved ? "fill-white" : "")} />
                  <span className="text-[10px]">{st?.savesCount ?? it.savesCount}</span>
                </button>

                <button
                  type="button"
                  onClick={() => share(`${window.location.origin}/discover?reel=${it.id}`, it.id)}
                  className="flex w-11 flex-col items-center gap-1 rounded-2xl bg-black/35 px-2 py-2 text-white backdrop-blur"
                >
                  <Share2 className="h-5 w-5" />
                  <span className="text-[10px]">Share</span>
                </button>

                <button
                  type="button"
                  disabled={busy === it.id}
                  onClick={() => toggleFollow(it.authorType, it.authorId, it.id)}
                  className="flex w-11 flex-col items-center gap-1 rounded-2xl bg-black/35 px-2 py-2 text-white backdrop-blur"
                >
                  {st?.following ? <UserX className="h-5 w-5" /> : <UserPlus className="h-5 w-5" />}
                  <span className="text-[10px]">{st?.following ? "Unfollow" : "Follow"}</span>
                </button>

                <button
                  type="button"
                  disabled={busy === it.id}
                  onClick={() => hideReel(it.id)}
                  className="flex w-11 flex-col items-center gap-1 rounded-2xl bg-black/35 px-2 py-2 text-white backdrop-blur"
                >
                  <EyeOff className="h-5 w-5" />
                  <span className="text-[10px]">Hide</span>
                </button>
              </div>
            </section>
          );
        })}
        {visibleItems.length ? (
          <section className="relative flex h-[calc(100dvh-132px)] snap-start flex-col items-center justify-center gap-3 bg-black px-6 text-center">
            <div className="grid h-16 w-16 place-items-center rounded-full border border-[#D4AF37]/50 bg-[#D4AF37]/10 text-[#D4AF37]">
              ✓
            </div>
            <div className="text-lg font-semibold text-white">You’re all caught up</div>
            <div className="text-sm text-white/75">You’ve seen all the latest reels.</div>
            <Button asChild className="mt-2 rounded-2xl px-5">
              <Link href="/search?tab=barbers">Explore Top Barbers</Link>
            </Button>
          </section>
        ) : null}
      </div>

      {commentTarget ? (
        <div className="fixed inset-0 z-[60] bg-black/55 px-4 py-10" onClick={() => setCommentTarget(null)}>
          <div
            className="mx-auto flex max-w-md flex-col gap-3 rounded-2xl border border-[#2A2A2A] bg-[#111111] p-4 text-white"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="text-sm font-semibold text-white">Comments</div>
            <div className="max-h-[45dvh] overflow-y-auto">
              {comments ? (
                comments.length ? (
                  <div className="flex flex-col gap-2">
                    {comments.map((c) => (
                      <div key={c.id} className="rounded-xl border border-[#2A2A2A] bg-black/20 p-3">
                        <div className="text-xs font-semibold text-white">{c.name}</div>
                        <div className="pt-1 text-sm text-white/75">{c.text}</div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="text-sm text-white/75">No comments yet.</div>
                )
              ) : (
                <div className="text-sm text-white/75">Loading…</div>
              )}
            </div>

            <div className="flex items-center gap-2">
              <input
                value={commentText}
                onChange={(e) => setCommentText(e.target.value)}
                className="h-11 flex-1 rounded-2xl border border-[#2A2A2A] bg-black/30 px-4 text-sm text-white outline-none placeholder:text-white/40"
                placeholder="Write a comment…"
              />
              <Button type="button" onClick={sendComment} className="h-11 rounded-2xl px-4">
                Send
              </Button>
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}

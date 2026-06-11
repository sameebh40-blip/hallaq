"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";

import { trackAnalyticsEvent } from "@/lib/analytics";

function routeForValue(value: string): { path: string; entityType?: string; entityId?: string } | null {
  const v = value.trim();
  if (!v) return null;
  const low = v.toLowerCase();
  const withSource = (path: string) => {
    const url = new URL(path, "https://placeholder.invalid");
    if (!url.searchParams.get("source")) url.searchParams.set("source", "qr");
    return `${url.pathname}${url.search}`;
  };
  if (low.startsWith("/")) {
    const url = new URL(v, "https://placeholder.invalid");
    const parts = url.pathname.split("/").filter(Boolean);
    if (parts[0] === "barber" && parts[1]) return { path: withSource(`${url.pathname}${url.search}`), entityType: "barber", entityId: parts[1] };
    if (parts[0] === "shop" && parts[1]) return { path: withSource(`${url.pathname}${url.search}`), entityType: "shop", entityId: parts[1] };
    if (parts[0] === "discover") return { path: withSource(`/discover${url.search}`), entityType: "discover" };
  }
  if (low.startsWith("barber:")) {
    const id = v.slice(7).trim();
    return id ? { path: `/barber/${encodeURIComponent(id)}?source=qr`, entityType: "barber", entityId: id } : null;
  }
  if (low.startsWith("shop:")) {
    const id = v.slice(5).trim();
    return id ? { path: `/shop/${encodeURIComponent(id)}?source=qr`, entityType: "shop", entityId: id } : null;
  }
  if (low.startsWith("discover:")) {
    const id = v.slice(9).trim();
    return id
      ? { path: `/discover?reel=${encodeURIComponent(id)}&source=qr`, entityType: "discover", entityId: id }
      : { path: "/discover?source=qr", entityType: "discover" };
  }
  let url: URL | null = null;
  try {
    url = new URL(v);
  } catch {
    return null;
  }

  const parts = url.pathname.split("/").filter(Boolean);
  if (parts[0] === "barber" && parts[1]) return { path: withSource(`${url.pathname}${url.search}`), entityType: "barber", entityId: parts[1] };
  if (parts[0] === "shop" && parts[1]) return { path: withSource(`${url.pathname}${url.search}`), entityType: "shop", entityId: parts[1] };
  if (parts[0] === "discover") {
    const reel = url.searchParams.get("reel");
    return reel
      ? { path: `/discover?reel=${encodeURIComponent(reel)}&source=qr`, entityType: "discover", entityId: reel }
      : { path: "/discover?source=qr", entityType: "discover" };
  }
  return null;
}

export function ScanClient() {
  const router = useRouter();
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let stream: MediaStream | null = null;
    let raf = 0;
    let stopped = false;
    let handled = false;

    async function start() {
      try {
        if (!("mediaDevices" in navigator)) throw new Error("Camera not supported");
        type BarcodeDetectorCtor = new (opts: { formats: string[] }) => { detect: (src: CanvasImageSource) => Promise<Array<{ rawValue: string }>> };
        const Detector = (globalThis as unknown as { BarcodeDetector?: BarcodeDetectorCtor }).BarcodeDetector;
        if (!Detector) throw new Error("BarcodeDetector not supported in this browser");
        const detector = new Detector({ formats: ["qr_code"] });

        stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "environment" }, audio: false });
        if (!videoRef.current) return;
        videoRef.current.srcObject = stream;
        await videoRef.current.play();
        setReady(true);

        const tick = async () => {
          if (stopped || handled) return;
          const video = videoRef.current;
          const canvas = canvasRef.current;
          if (video && canvas && video.videoWidth && video.videoHeight) {
            canvas.width = video.videoWidth;
            canvas.height = video.videoHeight;
            const ctx = canvas.getContext("2d");
            if (ctx) {
              ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
              try {
                const res = await detector.detect(canvas);
                for (const r of res) {
                  const next = routeForValue(r.rawValue);
                  if (next) {
                    handled = true;
                    void trackAnalyticsEvent({
                      event_name: "qr_scan",
                      entity_type: next.entityType ?? "unknown",
                      entity_id: next.entityId ?? null,
                      meta: { raw_value: r.rawValue, target: next.path, source: "qr" }
                    });
                    router.push(next.path);
                    return;
                  }
                }
              } catch {}
            }
          }
          raf = window.requestAnimationFrame(tick);
        };

        raf = window.requestAnimationFrame(tick);
      } catch (e) {
        setError(e instanceof Error ? e.message : "Failed to start scanner");
      }
    }

    start();

    return () => {
      stopped = true;
      if (raf) window.cancelAnimationFrame(raf);
      if (stream) {
        for (const t of stream.getTracks()) t.stop();
      }
    };
  }, [router]);

  return (
    <div className="relative overflow-hidden rounded-[24px] border border-[#2A2A2A] bg-black">
      <div className="relative aspect-[3/4] w-full">
        <video ref={videoRef} className="absolute inset-0 h-full w-full object-cover" playsInline muted />
        <canvas ref={canvasRef} className="hidden" />
        <div className="absolute inset-0 bg-gradient-to-b from-black/65 via-black/10 to-black/75" />
        <div className="pointer-events-none absolute left-1/2 top-1/2 h-[260px] w-[260px] -translate-x-1/2 -translate-y-1/2 rounded-[26px] border-2 border-[hsl(var(--gold))]/80 shadow-[0_18px_42px_rgba(212,175,55,0.22)]" />
        <div className="absolute left-0 right-0 bottom-6 px-6 text-center text-sm font-semibold text-white/85">
          {error ? error : ready ? "Point the camera at a HALLAQ QR code." : "Starting camera…"}
        </div>
      </div>
    </div>
  );
}

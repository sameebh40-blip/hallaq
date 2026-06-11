"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import Cropper, { type Area } from "react-easy-crop";

import { Button } from "@hallaq/ui/button";
import { cn } from "@hallaq/ui/cn";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

type CropRatio = "free" | "1:1" | "16:9" | "3:1" | "9:16";

export type BrandAssetDefinition = {
  asset_key: string;
  section: string;
  label: string;
  folder: string;
  crop_ratio: string;
};

type PreviewTarget =
  | "client_profile"
  | "barber_profile"
  | "shop_profile"
  | "service_card"
  | "product_card"
  | "reel_feed"
  | "booking_card"
  | "membership_card"
  | "login_screen"
  | "notification"
  | "home_banner";

function parseRatio(value: string): { ratio: CropRatio; aspect: number | null } {
  const v = String(value ?? "")
    .trim()
    .toLowerCase();
  if (!v || v === "free") return { ratio: "free", aspect: null };
  const parts = v.split(":").map((p) => Number(p.trim()));
  if (parts.length === 2 && Number.isFinite(parts[0]) && Number.isFinite(parts[1]) && parts[0] > 0 && parts[1] > 0) {
    const text = `${parts[0]}:${parts[1]}` as CropRatio;
    return { ratio: text, aspect: parts[0] / parts[1] };
  }
  return { ratio: "free", aspect: null };
}

function getPreviewTargets(def: BrandAssetDefinition): PreviewTarget[] {
  const key = def.asset_key;
  if (key.includes("profile") && key.includes("avatar")) return ["client_profile"];
  if (key.includes("barber") && key.includes("avatar")) return ["barber_profile"];
  if (key.includes("shop_cover")) return ["shop_profile"];
  if (key.includes("shop_logo")) return ["shop_profile"];
  if (key.includes("service")) return ["service_card"];
  if (key.includes("product")) return ["product_card"];
  if (key.includes("reel")) return ["reel_feed"];
  if (key.includes("membership")) return ["membership_card"];
  if (key.includes("login_background")) return ["login_screen"];
  if (key.includes("notification")) return ["notification"];
  if (key.includes("home") || key.includes("banner")) return ["home_banner"];
  return ["client_profile", "shop_profile"];
}

function thresholdsForRatio(ratio: CropRatio) {
  if (ratio === "1:1") return { minW: 512, minH: 512, recW: 1024, recH: 1024 };
  if (ratio === "16:9") return { minW: 960, minH: 540, recW: 1920, recH: 1080 };
  if (ratio === "3:1") return { minW: 900, minH: 300, recW: 1800, recH: 600 };
  if (ratio === "9:16") return { minW: 540, minH: 960, recW: 1080, recH: 1920 };
  return { minW: 512, minH: 512, recW: 1024, recH: 1024 };
}

function createImage(src: string) {
  return new Promise<HTMLImageElement>((resolve, reject) => {
    const image = new Image();
    image.addEventListener("load", () => resolve(image));
    image.addEventListener("error", (e) => reject(e));
    image.setAttribute("crossOrigin", "anonymous");
    image.src = src;
  });
}

function getRadianAngle(degreeValue: number) {
  return (degreeValue * Math.PI) / 180;
}

function rotateSize(width: number, height: number, rotation: number) {
  const rotRad = getRadianAngle(rotation);
  return {
    width: Math.abs(Math.cos(rotRad) * width) + Math.abs(Math.sin(rotRad) * height),
    height: Math.abs(Math.sin(rotRad) * width) + Math.abs(Math.cos(rotRad) * height)
  };
}

async function cropImageToBlob(src: string, pixelCrop: Area, rotation: number) {
  const image = await createImage(src);
  const canvas = document.createElement("canvas");
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Canvas not supported");

  const rotRad = getRadianAngle(rotation);
  const { width: bBoxWidth, height: bBoxHeight } = rotateSize(image.width, image.height, rotation);

  canvas.width = bBoxWidth;
  canvas.height = bBoxHeight;

  ctx.translate(bBoxWidth / 2, bBoxHeight / 2);
  ctx.rotate(rotRad);
  ctx.translate(-image.width / 2, -image.height / 2);
  ctx.drawImage(image, 0, 0);

  const croppedCanvas = document.createElement("canvas");
  const croppedCtx = croppedCanvas.getContext("2d");
  if (!croppedCtx) throw new Error("Canvas not supported");

  croppedCanvas.width = pixelCrop.width;
  croppedCanvas.height = pixelCrop.height;

  croppedCtx.drawImage(
    canvas,
    pixelCrop.x,
    pixelCrop.y,
    pixelCrop.width,
    pixelCrop.height,
    0,
    0,
    pixelCrop.width,
    pixelCrop.height
  );

  const outMime = "image/webp";
  return await new Promise<Blob>((resolve, reject) => {
    croppedCanvas.toBlob((blob) => {
      if (!blob) reject(new Error("Failed to export image"));
      else resolve(blob);
    }, outMime, 0.92);
  });
}

export function AssetEditor({
  open,
  definition,
  file,
  onCancel,
  onSave
}: {
  open: boolean;
  definition: BrandAssetDefinition | null;
  file: File | null;
  onCancel: () => void;
  onSave: (result: { blob: Blob; fileName: string; mimeType: string }) => void;
}) {
  const objectUrlRef = useRef<string | null>(null);
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [rotation, setRotation] = useState(0);
  const [croppedAreaPixels, setCroppedAreaPixels] = useState<Area | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [info, setInfo] = useState<{ width: number; height: number } | null>(null);

  const src = useMemo(() => {
    if (!open || !file) return null;
    const url = URL.createObjectURL(file);
    objectUrlRef.current = url;
    return url;
  }, [open, file]);

  useEffect(() => {
    return () => {
      if (objectUrlRef.current) URL.revokeObjectURL(objectUrlRef.current);
      objectUrlRef.current = null;
    };
  }, []);

  useEffect(() => {
    setCrop({ x: 0, y: 0 });
    setZoom(1);
    setRotation(0);
    setCroppedAreaPixels(null);
    setError("");
    setInfo(null);
  }, [src]);

  useEffect(() => {
    if (!open || !src) return;
    let cancelled = false;
    void (async () => {
      try {
        const img = await createImage(src);
        if (cancelled) return;
        setInfo({ width: img.width, height: img.height });
      } catch {
        if (cancelled) return;
        setInfo(null);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [open, src]);

  const ratio = parseRatio(definition?.crop_ratio ?? "free");
  const targets = useMemo(() => (definition ? getPreviewTargets(definition) : []), [definition]);
  const fileSizeMb = useMemo(() => (file ? file.size / (1024 * 1024) : 0), [file]);
  const quality = useMemo(() => {
    if (!file) return { label: "—", tone: "muted" as const, warnings: [] as string[] };
    const warnings: string[] = [];
    const dims = info;
    const target = thresholdsForRatio(ratio.ratio);
    if (fileSizeMb > 10) warnings.push("File is very large (>10MB).");
    else if (fileSizeMb > 4) warnings.push("File is large (>4MB).");
    if (!dims) warnings.push("Unable to read image dimensions.");
    if (dims) {
      if (dims.width < target.minW || dims.height < target.minH) warnings.push("Resolution too low for best results.");
      const isRec = dims.width >= target.recW && dims.height >= target.recH;
      const isMin = dims.width >= target.minW && dims.height >= target.minH;
      if (isRec && fileSizeMb <= 2) return { label: "Excellent", tone: "good" as const, warnings };
      if (isMin) return { label: "Good", tone: "ok" as const, warnings };
      return { label: "Needs Improvement", tone: "bad" as const, warnings };
    }
    return warnings.length ? { label: "Needs Improvement", tone: "bad" as const, warnings } : { label: "Good", tone: "ok" as const, warnings };
  }, [file, fileSizeMb, info, ratio.ratio]);

  if (!open || !definition || !file || !src) return null;

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/70 p-4">
      <LuxuryCard className="w-full max-w-[1200px] border border-white/10 bg-[#070707] p-4 md:p-5">
        <div className="flex flex-col gap-4">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div className="flex flex-col gap-1">
              <div className="text-base font-semibold">{definition.label}</div>
              <div className="text-xs text-muted-foreground">{definition.asset_key}</div>
            </div>
            <div className="flex items-center gap-2">
              <Button
                type="button"
                variant="ghost"
                onClick={() => {
                  setCrop({ x: 0, y: 0 });
                  setZoom(1);
                  setRotation(0);
                }}
                disabled={busy}
              >
                Reset
              </Button>
              <Button type="button" variant="secondary" onClick={onCancel} disabled={busy}>
                Cancel
              </Button>
              <Button
                type="button"
                onClick={async () => {
                  setError("");
                  if (!croppedAreaPixels) {
                    setError("Select crop area first.");
                    return;
                  }
                  setBusy(true);
                  try {
                    const base = file.name.replace(/\.[^/.]+$/, "");
                    const blob = await cropImageToBlob(src, croppedAreaPixels, rotation);
                    onSave({ blob, fileName: `${base}.webp`, mimeType: "image/webp" });
                  } catch (e) {
                    setError(e instanceof Error ? e.message : "Failed to crop image");
                  } finally {
                    setBusy(false);
                  }
                }}
                disabled={busy}
              >
                Save
              </Button>
            </div>
          </div>

          {error ? <LuxuryCard className="border border-rose-500/25 bg-rose-500/10 p-3 text-sm text-rose-200">{error}</LuxuryCard> : null}

          <LuxuryCard
            className={cn(
              "border bg-white/5 p-3",
              quality.tone === "good"
                ? "border-emerald-500/25 bg-emerald-500/10 text-emerald-200"
                : quality.tone === "bad"
                  ? "border-amber-500/25 bg-amber-500/10 text-amber-200"
                  : "border-white/10 text-muted-foreground"
            )}
          >
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="text-xs font-semibold">Quality: {quality.label}</div>
              <div className="text-[11px]">
                {info ? `${info.width}×${info.height}` : "—"} • {fileSizeMb.toFixed(2)}MB • {ratio.ratio === "free" ? "Free" : ratio.ratio}
              </div>
            </div>
            {quality.warnings.length ? (
              <div className="mt-2 grid gap-1 text-[11px]">
                {quality.warnings.map((w) => (
                  <div key={w}>{w}</div>
                ))}
              </div>
            ) : null}
          </LuxuryCard>

          <div className="grid grid-cols-1 gap-4 lg:grid-cols-[1.3fr,0.7fr]">
            <div className="overflow-hidden rounded-xl border border-white/10 bg-black/40">
              <div className="relative h-[380px] w-full md:h-[520px]">
                <Cropper
                  image={src}
                  crop={crop}
                  zoom={zoom}
                  rotation={rotation}
                  aspect={ratio.aspect ?? undefined}
                  onCropChange={setCrop}
                  onZoomChange={setZoom}
                  onRotationChange={setRotation}
                  onCropComplete={(_a, area) => setCroppedAreaPixels(area)}
                  objectFit="horizontal-cover"
                />
              </div>
              <div className="grid grid-cols-1 gap-3 border-t border-white/10 p-3 md:grid-cols-2">
                <div className="flex flex-col gap-1">
                  <div className="text-[11px] font-semibold text-muted-foreground">Zoom</div>
                  <input
                    type="range"
                    min={1}
                    max={3}
                    step={0.01}
                    value={zoom}
                    onChange={(e) => setZoom(Number(e.currentTarget.value))}
                    className="h-2 w-full cursor-pointer accent-[hsl(var(--gold))]"
                  />
                </div>
                <div className="flex flex-col gap-1">
                  <div className="text-[11px] font-semibold text-muted-foreground">Rotate</div>
                  <input
                    type="range"
                    min={0}
                    max={360}
                    step={1}
                    value={rotation}
                    onChange={(e) => setRotation(Number(e.currentTarget.value))}
                    className="h-2 w-full cursor-pointer accent-[hsl(var(--gold))]"
                  />
                </div>
              </div>
            </div>

            <div className="flex flex-col gap-3">
              <div className="text-sm font-semibold">Live Preview</div>
              <div className="grid grid-cols-1 gap-3">
                {targets.map((t) => (
                  <PreviewFrame key={t} src={src} target={t} />
                ))}
              </div>
              <div className="text-xs text-muted-foreground">
                {ratio.ratio === "free" ? "Free crop" : `Crop ratio: ${ratio.ratio}`}
              </div>
            </div>
          </div>
        </div>
      </LuxuryCard>
    </div>
  );
}

function PreviewFrame({ src, target }: { src: string; target: PreviewTarget }) {
  const common = "overflow-hidden border border-white/10 bg-black/30";

  if (target === "client_profile") {
    return (
      <LuxuryCard className={cn(common, "p-3")}>
        <div className="text-[11px] font-semibold text-muted-foreground">Client Profile</div>
        <div className="mt-2 flex items-center gap-3">
          <div className="h-12 w-12 overflow-hidden rounded-full border border-white/10 bg-black/30">
            <img src={src} alt="" className="h-full w-full object-cover" />
          </div>
          <div className="flex flex-col">
            <div className="text-xs font-semibold">Avatar</div>
            <div className="text-[11px] text-muted-foreground">1:1</div>
          </div>
        </div>
      </LuxuryCard>
    );
  }

  if (target === "barber_profile") {
    return (
      <LuxuryCard className={cn(common, "p-3")}>
        <div className="text-[11px] font-semibold text-muted-foreground">Barber Profile</div>
        <div className="mt-2 flex items-center gap-3">
          <div className="h-12 w-12 overflow-hidden rounded-full border border-white/10 bg-black/30">
            <img src={src} alt="" className="h-full w-full object-cover" />
          </div>
          <div className="flex flex-col">
            <div className="text-xs font-semibold">Avatar</div>
            <div className="text-[11px] text-muted-foreground">1:1</div>
          </div>
        </div>
      </LuxuryCard>
    );
  }

  if (target === "shop_profile") {
    return (
      <LuxuryCard className={cn(common, "p-3")}>
        <div className="text-[11px] font-semibold text-muted-foreground">Shop Profile</div>
        <div className="mt-2 overflow-hidden rounded-lg border border-white/10 bg-black/30">
          <div className="relative aspect-[16/9] w-full">
            <img src={src} alt="" className="h-full w-full object-cover" />
          </div>
        </div>
      </LuxuryCard>
    );
  }

  if (target === "service_card") {
    return (
      <LuxuryCard className={cn(common, "p-3")}>
        <div className="text-[11px] font-semibold text-muted-foreground">Service Card</div>
        <div className="mt-2 flex items-start gap-3">
          <div className="h-14 w-14 overflow-hidden rounded-lg border border-white/10 bg-black/30">
            <img src={src} alt="" className="h-full w-full object-cover" />
          </div>
          <div className="flex flex-1 flex-col gap-1">
            <div className="text-xs font-semibold">Service</div>
            <div className="h-2 w-20 rounded bg-white/10" />
            <div className="h-2 w-12 rounded bg-white/10" />
          </div>
        </div>
      </LuxuryCard>
    );
  }

  if (target === "product_card") {
    return (
      <LuxuryCard className={cn(common, "p-3")}>
        <div className="text-[11px] font-semibold text-muted-foreground">Product Card</div>
        <div className="mt-2 flex items-start gap-3">
          <div className="h-14 w-14 overflow-hidden rounded-lg border border-white/10 bg-black/30">
            <img src={src} alt="" className="h-full w-full object-cover" />
          </div>
          <div className="flex flex-1 flex-col gap-1">
            <div className="text-xs font-semibold">Product</div>
            <div className="h-2 w-24 rounded bg-white/10" />
            <div className="h-2 w-14 rounded bg-white/10" />
          </div>
        </div>
      </LuxuryCard>
    );
  }

  if (target === "reel_feed") {
    return (
      <LuxuryCard className={cn(common, "p-3")}>
        <div className="text-[11px] font-semibold text-muted-foreground">Reel Feed</div>
        <div className="mt-2 overflow-hidden rounded-lg border border-white/10 bg-black/30">
          <div className="relative aspect-[9/16] w-full">
            <img src={src} alt="" className="h-full w-full object-cover" />
          </div>
        </div>
      </LuxuryCard>
    );
  }

  if (target === "booking_card") {
    return (
      <LuxuryCard className={cn(common, "p-3")}>
        <div className="text-[11px] font-semibold text-muted-foreground">Booking Card</div>
        <div className="mt-2 overflow-hidden rounded-lg border border-white/10 bg-black/30">
          <div className="relative aspect-[16/9] w-full">
            <img src={src} alt="" className="h-full w-full object-cover" />
          </div>
        </div>
      </LuxuryCard>
    );
  }

  if (target === "membership_card") {
    return (
      <LuxuryCard className={cn(common, "p-3")}>
        <div className="text-[11px] font-semibold text-muted-foreground">Membership Card</div>
        <div className="mt-2 overflow-hidden rounded-lg border border-white/10 bg-black/30">
          <div className="relative aspect-[16/9] w-full">
            <img src={src} alt="" className="h-full w-full object-cover" />
          </div>
        </div>
      </LuxuryCard>
    );
  }

  if (target === "login_screen") {
    return (
      <LuxuryCard className={cn(common, "p-3")}>
        <div className="text-[11px] font-semibold text-muted-foreground">Login Screen</div>
        <div className="mt-2 overflow-hidden rounded-lg border border-white/10 bg-black/30">
          <div className="relative aspect-[9/16] w-full">
            <img src={src} alt="" className="h-full w-full object-cover" />
          </div>
        </div>
      </LuxuryCard>
    );
  }

  if (target === "notification") {
    return (
      <LuxuryCard className={cn(common, "p-3")}>
        <div className="text-[11px] font-semibold text-muted-foreground">Notification</div>
        <div className="mt-2 flex items-center gap-3 rounded-lg border border-white/10 bg-black/30 p-3">
          <div className="h-10 w-10 overflow-hidden rounded-lg border border-white/10 bg-black/30">
            <img src={src} alt="" className="h-full w-full object-cover" />
          </div>
          <div className="flex flex-1 flex-col gap-1">
            <div className="h-2 w-28 rounded bg-white/10" />
            <div className="h-2 w-40 rounded bg-white/10" />
          </div>
        </div>
      </LuxuryCard>
    );
  }

  return (
    <LuxuryCard className={cn(common, "p-3")}>
      <div className="text-[11px] font-semibold text-muted-foreground">Home Banner</div>
      <div className="mt-2 overflow-hidden rounded-lg border border-white/10 bg-black/30">
        <div className="relative aspect-[3/1] w-full">
          <img src={src} alt="" className="h-full w-full object-cover" />
        </div>
      </div>
    </LuxuryCard>
  );
}

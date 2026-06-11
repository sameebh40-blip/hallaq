"use client";

import Image from "next/image";
import { useEffect, useMemo, useState } from "react";

import { createSupabaseBrowserClient } from "@hallaq/supabase/browser";
import { Button } from "@hallaq/ui/button";
import { cn } from "@hallaq/ui/cn";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";
import { optimizeImageFile } from "@/lib/media/optimize-image-file";
import { MAX_ADMIN_VIDEO_BYTES } from "@/lib/media/upload-constraints";

type Option = { id: string; name: string };

function getExtension(filename: string) {
  const parts = filename.split(".");
  return parts.length > 1 ? parts[parts.length - 1].toLowerCase() : "bin";
}

export function ReelUploadForm({
  title,
  subtitle,
  shops,
  barbers,
  createReel
}: {
  title: string;
  subtitle: string;
  shops: Option[];
  barbers: Option[];
  createReel: (formData: FormData) => void;
}) {
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [previewFailed, setPreviewFailed] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [uploadedUrl, setUploadedUrl] = useState<string>("");
  const [mediaType, setMediaType] = useState<"video" | "image">("video");
  const [error, setError] = useState<string>("");
  const [message, setMessage] = useState<string>("");

  const accept = useMemo(() => (mediaType === "video" ? "video/*" : "image/*"), [mediaType]);

  useEffect(() => {
    return () => {
      if (previewUrl) URL.revokeObjectURL(previewUrl);
    };
  }, [previewUrl]);

  async function uploadSelected() {
    if (!file) return;

    setError("");
    setUploading(true);
    try {
      const supabase = createSupabaseBrowserClient();
      const ext = getExtension(file.name);
      const key = `admin/${Date.now()}-${Math.random().toString(16).slice(2)}.${ext}`;

      const { error: uploadError } = await supabase.storage.from("reels").upload(key, file, {
        cacheControl: "3600",
        upsert: true,
        contentType: file.type || undefined
      });

      if (uploadError) {
        setError(uploadError.message);
        return;
      }

      setUploadedUrl(key);
      const { data: signed } = await supabase.storage.from("reels").createSignedUrl(key, 60 * 10);
      if (signed?.signedUrl) {
        setPreviewUrl((prev) => {
          if (prev) URL.revokeObjectURL(prev);
          return signed.signedUrl;
        });
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not prepare this upload.");
    } finally {
      setUploading(false);
    }
  }

  async function onFileSelected(next: File | null) {
    if (!next) return;
    let prepared = next;
    let nextMessage = "";
    if ((next.type ?? "").startsWith("image/")) {
      try {
        const optimized = await optimizeImageFile(next);
        prepared = optimized.file;
        if (optimized.changed) {
          nextMessage = "Image compressed automatically before upload.";
        }
      } catch {
        nextMessage = "Image selected. Automatic compression was skipped.";
      }
    } else if ((next.type ?? "").startsWith("video/") && next.size > MAX_ADMIN_VIDEO_BYTES) {
      nextMessage = "Large video selected. Upload may take longer.";
    }

    setFile(prepared);
    setUploadedUrl("");
    setError("");
    setMessage(nextMessage);
    setPreviewFailed(false);

    setPreviewUrl((prev) => {
      if (prev) URL.revokeObjectURL(prev);
      return URL.createObjectURL(prepared);
    });
  }

  return (
    <PageFrame title={title} subtitle={subtitle}>
      <div className="grid grid-cols-1 gap-4 xl:grid-cols-2">
        <LuxuryCard className="p-5">
          <form action={createReel} className="flex flex-col gap-4">
            <input type="hidden" name="mediaUrl" value={uploadedUrl} />
            <input type="hidden" name="mediaType" value={mediaType} />

            <div className="grid grid-cols-2 gap-3">
              <Button
                type="button"
                variant={mediaType === "video" ? "secondary" : "ghost"}
                onClick={() => setMediaType("video")}
              >
                Video
              </Button>
              <Button
                type="button"
                variant={mediaType === "image" ? "secondary" : "ghost"}
                onClick={() => setMediaType("image")}
              >
                Image
              </Button>
            </div>

            <div className="flex flex-col gap-2">
              <Label>Media file</Label>
              <div
                className={cn(
                  "relative flex min-h-[140px] flex-col items-center justify-center gap-2 rounded-lg border border-white/10 bg-white/5 p-4 text-center",
                  "outline-none focus-within:ring-2 focus-within:ring-primary/40"
                )}
                onDragOver={(e) => {
                  e.preventDefault();
                }}
                onDrop={(e) => {
                  e.preventDefault();
                  const dropped = e.dataTransfer.files?.[0] ?? null;
                  if (dropped) onFileSelected(dropped);
                }}
              >
                <div className="text-sm font-medium">Drag & drop</div>
                <div className="text-xs text-muted-foreground">or choose a file to upload</div>
                <Input
                  type="file"
                  accept={accept}
                  className="h-11 bg-white/5"
                  onChange={(e) => onFileSelected(e.target.files?.[0] ?? null)}
                />
              </div>
            </div>

            <div className="flex items-center gap-2">
              <Button type="button" onClick={uploadSelected} disabled={!file || uploading} className="h-11">
                {uploading ? "Uploading…" : "Upload"}
              </Button>
              <div className="text-xs text-muted-foreground">
                {uploadedUrl ? "Ready to publish" : "Upload required before publish"}
              </div>
            </div>

            <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
              <div className="flex flex-col gap-2">
                <Label htmlFor="barberId">Barber</Label>
                <select
                  id="barberId"
                  name="barberId"
                  className="h-11 rounded-lg border border-white/10 bg-white/5 px-3 text-sm outline-none focus:ring-2 focus:ring-primary/40"
                  defaultValue=""
                >
                  <option value="">—</option>
                  {barbers.map((b) => (
                    <option key={b.id} value={b.id}>
                      {b.name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="flex flex-col gap-2">
                <Label htmlFor="shopId">Store</Label>
                <select
                  id="shopId"
                  name="shopId"
                  className="h-11 rounded-lg border border-white/10 bg-white/5 px-3 text-sm outline-none focus:ring-2 focus:ring-primary/40"
                  defaultValue=""
                >
                  <option value="">—</option>
                  {shops.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.name}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <div className="flex flex-col gap-2">
              <Label htmlFor="caption">Caption</Label>
              <textarea
                id="caption"
                name="caption"
                className="min-h-[110px] rounded-lg border border-white/10 bg-white/5 px-3 py-3 text-sm outline-none focus:ring-2 focus:ring-primary/40"
                placeholder="Write a premium caption…"
              />
            </div>

            <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
              <div className="flex flex-col gap-2">
                <Label htmlFor="hashtags">Hashtags</Label>
                <Input
                  id="hashtags"
                  name="hashtags"
                  placeholder="#fade #bahrain #hallaq"
                  className="h-11 bg-white/5"
                />
              </div>
              <div className="flex flex-col gap-2">
                <Label htmlFor="location">Location</Label>
                <Input id="location" name="location" placeholder="Manama, Seef…" className="h-11 bg-white/5" />
              </div>
            </div>

            <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
              <label className="flex items-center gap-2 rounded-lg border border-white/10 bg-white/5 px-4 py-3 text-sm text-muted-foreground">
                <input type="checkbox" name="publishNow" defaultChecked className="h-4 w-4 accent-[hsl(var(--gold))]" />
                Publish now
              </label>
              <label className="flex items-center gap-2 rounded-lg border border-white/10 bg-white/5 px-4 py-3 text-sm text-muted-foreground">
                <input type="checkbox" name="featured" className="h-4 w-4 accent-[hsl(var(--gold))]" />
                Featured
              </label>
              <label className="flex items-center gap-2 rounded-lg border border-white/10 bg-white/5 px-4 py-3 text-sm text-muted-foreground">
                <input type="checkbox" name="sponsored" className="h-4 w-4 accent-[hsl(var(--gold))]" />
                Sponsored
              </label>
            </div>

            {error ? (
              <div className="rounded-lg border border-destructive/40 bg-destructive/10 p-3 text-sm text-destructive">
                {error}
              </div>
            ) : null}

            {message ? (
              <div className="rounded-lg border border-white/10 bg-white/5 p-3 text-sm text-muted-foreground">
                {message}
              </div>
            ) : null}

            <Button type="submit" className="h-11" disabled={!uploadedUrl}>
              Publish
            </Button>
          </form>
        </LuxuryCard>

        <LuxuryCard className="p-5">
          <div className="flex flex-col gap-3">
            <div className="text-sm font-semibold">Preview</div>
            <div className="text-xs text-muted-foreground">Verify the media, caption, and status before publishing.</div>
            <div className="mt-2 overflow-hidden rounded-lg border border-white/10 bg-black">
              {previewUrl ? (
                mediaType === "video" ? (
                  previewFailed ? (
                    <div className="grid h-[420px] place-items-center bg-[radial-gradient(900px_520px_at_20%_0%,hsl(var(--gold)/0.16),transparent_55%),radial-gradient(800px_520px_at_85%_10%,hsl(var(--gold)/0.10),transparent_55%)] px-6 text-center text-sm text-muted-foreground">
                      Preview unavailable
                    </div>
                  ) : (
                    <video
                      src={previewUrl}
                      controls
                      className="h-[420px] w-full object-contain"
                      onError={() => setPreviewFailed(true)}
                    />
                  )
                ) : (
                  previewFailed ? (
                    <div className="grid h-[420px] place-items-center bg-[radial-gradient(900px_520px_at_20%_0%,hsl(var(--gold)/0.16),transparent_55%),radial-gradient(800px_520px_at_85%_10%,hsl(var(--gold)/0.10),transparent_55%)] px-6 text-center text-sm text-muted-foreground">
                      Preview unavailable
                    </div>
                  ) : (
                    <div className="relative h-[420px] w-full">
                      <Image
                        src={previewUrl}
                        alt="Reel preview"
                        fill
                        unoptimized
                        sizes="420px"
                        className="object-contain"
                        onError={() => setPreviewFailed(true)}
                      />
                    </div>
                  )
                )
              ) : (
                <div className="grid h-[420px] place-items-center text-sm text-muted-foreground">
                  Drop a file to preview
                </div>
              )}
            </div>
            {uploadedUrl ? (
              <div className="rounded-lg border border-white/10 bg-white/5 p-3 text-xs text-muted-foreground">
                Uploaded: <span className="break-all text-primary">{uploadedUrl}</span>
              </div>
            ) : null}
          </div>
        </LuxuryCard>
      </div>
    </PageFrame>
  );
}

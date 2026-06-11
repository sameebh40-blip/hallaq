"use client";

import Image from "next/image";
import { useMemo, useState, type InputHTMLAttributes } from "react";

type Props = Omit<InputHTMLAttributes<HTMLInputElement>, "type" | "name" | "accept"> & {
  name: string;
  accept: string;
};

export function MediaFileInput({ name, accept, ...inputProps }: Props) {
  const [url, setUrl] = useState<string | null>(null);
  const [type, setType] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [previewFailed, setPreviewFailed] = useState(false);
  const [inputKey, setInputKey] = useState(0);

  const isImage = useMemo(() => (type ?? "").startsWith("image/"), [type]);
  const isVideo = useMemo(() => (type ?? "").startsWith("video/"), [type]);

  return (
    <div className="flex flex-col gap-3">
      <input
        key={inputKey}
        type="file"
        name={name}
        accept={accept}
        {...inputProps}
        onChange={async (e) => {
          inputProps.onChange?.(e);
          const f = e.target.files?.[0];
          if (!f) return;

          const isImg = (f.type ?? "").startsWith("image/");
          const isVid = (f.type ?? "").startsWith("video/");
          if (!isImg && !isVid) {
            setError("Unsupported file type.");
            setType(null);
            setUrl((prev) => {
              if (prev) URL.revokeObjectURL(prev);
              return null;
            });
            setInputKey((k) => k + 1);
            return;
          }

          const maxBytes = isVid ? 150 * 1024 * 1024 : 15 * 1024 * 1024;
          if (f.size > maxBytes) {
            setError(isVid ? "Video is too large (max 150MB)." : "Image is too large.");
            setType(null);
            setUrl((prev) => {
              if (prev) URL.revokeObjectURL(prev);
              return null;
            });
            setInputKey((k) => k + 1);
            return;
          }

          if (isVid) {
            if (f.type !== "video/mp4") {
              setError("Only MP4 videos are supported.");
              setType(null);
              setUrl((prev) => {
                if (prev) URL.revokeObjectURL(prev);
                return null;
              });
              setInputKey((k) => k + 1);
              return;
            }

            const testUrl = URL.createObjectURL(f);
            const ok = await new Promise<boolean>((resolve) => {
              const v = document.createElement("video");
              v.preload = "metadata";
              v.onloadedmetadata = () => resolve(v.duration <= 20.01);
              v.onerror = () => resolve(false);
              v.src = testUrl;
            });
            URL.revokeObjectURL(testUrl);
            if (!ok) {
              setError("Video must be 20 seconds or less.");
              setType(null);
              setUrl((prev) => {
                if (prev) URL.revokeObjectURL(prev);
                return null;
              });
              setInputKey((k) => k + 1);
              return;
            }
          }

          setError(null);
          setType(f.type);
          setPreviewFailed(false);
          setUrl((prev) => {
            if (prev) URL.revokeObjectURL(prev);
            return URL.createObjectURL(f);
          });
        }}
      />

      {error ? (
        <div className="rounded-md border border-destructive/40 bg-destructive/10 p-3 text-sm text-destructive">
          {error}
        </div>
      ) : null}

      {url && isImage ? (
        <div className="max-w-md overflow-hidden rounded-lg border border-white/10 bg-white/5">
          {previewFailed ? (
            <div className="grid aspect-video place-items-center bg-[radial-gradient(600px_260px_at_10%_0%,hsl(var(--gold)/0.16),transparent_55%),radial-gradient(500px_260px_at_90%_20%,hsl(var(--gold)/0.10),transparent_55%)] px-6 text-center text-sm text-muted-foreground">
              Preview unavailable
            </div>
          ) : (
            <div className="relative aspect-video w-full">
              <Image src={url} alt="Preview" fill unoptimized className="object-cover" onError={() => setPreviewFailed(true)} />
            </div>
          )}
        </div>
      ) : null}

      {url && isVideo ? (
        <div className="max-w-md overflow-hidden rounded-lg border border-white/10 bg-white/5">
          {previewFailed ? (
            <div className="grid aspect-video place-items-center bg-[radial-gradient(600px_260px_at_10%_0%,hsl(var(--gold)/0.16),transparent_55%),radial-gradient(500px_260px_at_90%_20%,hsl(var(--gold)/0.10),transparent_55%)] px-6 text-center text-sm text-muted-foreground">
              Preview unavailable
            </div>
          ) : (
            <video src={url} controls className="h-auto w-full" onError={() => setPreviewFailed(true)} />
          )}
        </div>
      ) : null}
    </div>
  );
}

"use client";

import Image from "next/image";
import { useEffect, useMemo, useRef, useState, type InputHTMLAttributes } from "react";

import { optimizeImageFile } from "@/lib/media/optimize-image-file";
import { MAX_ADMIN_VIDEO_BYTES } from "@/lib/media/upload-constraints";

type Props = Omit<InputHTMLAttributes<HTMLInputElement>, "type" | "name" | "accept"> & {
  name: string;
  accept: string;
};

export function MediaFileInput({ name, accept, ...inputProps }: Props) {
  const inputRef = useRef<HTMLInputElement | null>(null);
  const [url, setUrl] = useState<string | null>(null);
  const [type, setType] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [isPreparing, setIsPreparing] = useState(false);
  const [previewFailed, setPreviewFailed] = useState(false);
  const [inputKey, setInputKey] = useState(0);

  const isImage = useMemo(() => (type ?? "").startsWith("image/"), [type]);
  const isVideo = useMemo(() => (type ?? "").startsWith("video/"), [type]);

  useEffect(() => {
    return () => {
      if (url) URL.revokeObjectURL(url);
    };
  }, [url]);

  return (
    <div className="flex flex-col gap-3">
      <input
        ref={inputRef}
        key={inputKey}
        type="file"
        name={name}
        accept={accept}
        {...inputProps}
        onChange={async (e) => {
          inputProps.onChange?.(e);
          const input = e.currentTarget;
          const f = input.files?.[0];
          if (!f) return;

          const isImg = (f.type ?? "").startsWith("image/");
          const isVid = (f.type ?? "").startsWith("video/");
          if (!isImg && !isVid) {
            setError("Unsupported file type.");
            setMessage(null);
            setType(null);
            setUrl((prev) => {
              if (prev) URL.revokeObjectURL(prev);
              return null;
            });
            setInputKey((k) => k + 1);
            return;
          }

          let nextFile = f;
          let nextMessage: string | null = null;

          if (isImg) {
            setIsPreparing(true);
            try {
              const optimized = await optimizeImageFile(f);
              nextFile = optimized.file;
              if (optimized.changed) {
                nextMessage = "Image compressed automatically before upload.";
                try {
                  const dataTransfer = new DataTransfer();
                  dataTransfer.items.add(nextFile);
                  input.files = dataTransfer.files;
                } catch {}
              }
            } catch {
              nextMessage = "Image selected. Automatic compression was skipped.";
            } finally {
              setIsPreparing(false);
            }
          } else if (f.size > MAX_ADMIN_VIDEO_BYTES) {
            nextMessage = "Large video selected. It will be compressed during upload.";
          }

          setError(null);
          setMessage(nextMessage);
          setType(nextFile.type || f.type);
          setPreviewFailed(false);
          setUrl((prev) => {
            if (prev) URL.revokeObjectURL(prev);
            return URL.createObjectURL(nextFile);
          });
        }}
      />

      {isPreparing ? (
        <div className="rounded-md border border-amber-500/30 bg-amber-500/10 p-3 text-sm text-amber-100">
          Preparing image for upload...
        </div>
      ) : null}

      {error ? (
        <div className="rounded-md border border-destructive/40 bg-destructive/10 p-3 text-sm text-destructive">
          {error}
        </div>
      ) : null}

      {message ? (
        <div className="rounded-md border border-white/10 bg-white/5 p-3 text-sm text-muted-foreground">
          {message}
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

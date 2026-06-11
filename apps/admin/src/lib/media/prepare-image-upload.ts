import { randomUUID } from "crypto";
import { promises as fs } from "fs";
import os from "os";
import path from "path";

import { ADMIN_RASTER_IMAGE_EXTENSIONS, MAX_ADMIN_IMAGE_BYTES, MAX_ADMIN_IMAGE_DIMENSION, getLowercaseExtension, isRasterImageFile, isSvgImageFile } from "./upload-constraints";

async function ffmpegPath() {
  try {
    const envPath = String(process.env.FFMPEG_PATH ?? "").trim();
    if (envPath) {
      await fs.access(envPath);
      return envPath;
    }
  } catch {}
  try {
    const mod = await import("@ffmpeg-installer/ffmpeg");
    const p = (mod.default as unknown as { path?: string }).path;
    const resolved = p && String(p).trim() ? String(p) : "";
    if (!resolved) return null;
    await fs.access(resolved);
    return resolved;
  } catch {
    return null;
  }
}

async function run(cmd: string, args: string[]) {
  const { spawn } = await import("child_process");
  await new Promise<void>((resolve, reject) => {
    const child = spawn(cmd, args, { windowsHide: true });
    let err = "";
    child.stderr.on("data", (d) => {
      err += String(d);
      if (err.length > 30000) err = err.slice(-30000);
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(err || `ffmpeg exit code ${code}`));
    });
  });
}

export function buildImageOptimizationAttempts() {
  return [
    { maxDimension: MAX_ADMIN_IMAGE_DIMENSION, quality: 84 },
    { maxDimension: 1800, quality: 78 },
    { maxDimension: 1600, quality: 72 },
    { maxDimension: 1400, quality: 66 },
    { maxDimension: 1200, quality: 60 },
    { maxDimension: 1000, quality: 54 },
    { maxDimension: 840, quality: 48 },
  ];
}

export function buildPreparedUploadPath(basePath: string, fileName: string, contentType: string) {
  const cleanBase = basePath.replace(/[\\/]+/g, "/").replace(/\/+$/, "");
  const ext0 = getLowercaseExtension(fileName);
  const ext =
    isSvgImageFile({ type: contentType, fileName })
      ? "svg"
      : contentType === "image/webp"
        ? "webp"
        : ADMIN_RASTER_IMAGE_EXTENSIONS.includes(ext0 as (typeof ADMIN_RASTER_IMAGE_EXTENSIONS)[number])
          ? ext0
          : "bin";
  return `${cleanBase}.${ext}`;
}

export async function prepareImageFileForUpload(
  file: File,
  {
    maxBytes = MAX_ADMIN_IMAGE_BYTES,
  }: {
    maxBytes?: number;
  } = {},
) {
  const sourceBytes = new Uint8Array(await file.arrayBuffer());

  if (isSvgImageFile({ type: file.type, fileName: file.name })) {
    if (sourceBytes.byteLength > maxBytes) {
      throw new Error("Image is still too large after compression. Please choose a smaller image.");
    }
    return {
      bytes: sourceBytes,
      contentType: "image/svg+xml",
      fileName: file.name || "image.svg",
      changed: false,
      originalBytes: sourceBytes.byteLength,
      optimizedBytes: sourceBytes.byteLength,
    };
  }

  if (!isRasterImageFile({ type: file.type, fileName: file.name })) {
    throw new Error("Unsupported image type.");
  }

  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "hallaq-image-"));
  const inPath = path.join(dir, `${randomUUID()}.input`);
  try {
    await fs.writeFile(inPath, sourceBytes);
    let smallest: Uint8Array | null = null;
    const ffmpeg = await ffmpegPath();
    if (!ffmpeg) {
      if (sourceBytes.byteLength > maxBytes) {
        throw new Error("ffmpeg_not_available");
      }
      return {
        bytes: sourceBytes,
        contentType: file.type || "application/octet-stream",
        fileName: file.name || "image",
        changed: false,
        originalBytes: sourceBytes.byteLength,
        optimizedBytes: sourceBytes.byteLength,
      };
    }

    for (const [index, attempt] of buildImageOptimizationAttempts().entries()) {
      const outPath = path.join(dir, `${index}-${randomUUID()}.webp`);
      await run(ffmpeg, [
        "-y",
        "-i",
        inPath,
        "-vf",
        `scale='min(${attempt.maxDimension},iw)':'min(${attempt.maxDimension},ih)':force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2`,
        "-frames:v",
        "1",
        "-c:v",
        "libwebp",
        "-quality",
        String(attempt.quality),
        "-compression_level",
        "6",
        "-preset",
        "picture",
        outPath,
      ]);
      const bytes = new Uint8Array(await fs.readFile(outPath));
      if (!smallest || bytes.byteLength < smallest.byteLength) {
        smallest = bytes;
      }
      if (bytes.byteLength <= maxBytes) {
        return {
          bytes,
          contentType: "image/webp",
          fileName: file.name.replace(/\.[^.]+$/, "") || "image",
          changed: true,
          originalBytes: sourceBytes.byteLength,
          optimizedBytes: bytes.byteLength,
        };
      }
    }

    if (smallest && smallest.byteLength <= maxBytes) {
      return {
        bytes: smallest,
        contentType: "image/webp",
        fileName: file.name.replace(/\.[^.]+$/, "") || "image",
        changed: true,
        originalBytes: sourceBytes.byteLength,
        optimizedBytes: smallest.byteLength,
      };
    }

    throw new Error("Image is still too large after compression. Please choose a smaller image.");
  } finally {
    try {
      await fs.rm(dir, { recursive: true, force: true });
    } catch {}
  }
}

export async function removeStorageObjectIfPresent(
  storage: {
    from(bucket: string): {
      remove(paths: string[]): Promise<{ error: { message?: string } | null }>;
    };
  },
  bucket: string,
  pathValue: string | null | undefined,
) {
  const normalized = String(pathValue || "").trim();
  if (!normalized || normalized.startsWith("http://") || normalized.startsWith("https://")) return;
  const { error } = await storage.from(bucket).remove([normalized]);
  if (error) throw new Error(error.message || `Failed to delete ${bucket}/${normalized}`);
}

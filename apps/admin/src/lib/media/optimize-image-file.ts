"use client";

import { MAX_ADMIN_IMAGE_BYTES, MAX_ADMIN_IMAGE_DIMENSION } from "./upload-constraints";

type OptimizedImageResult = {
  file: File;
  changed: boolean;
};

function renameWithExtension(fileName: string, ext: string) {
  const trimmed = fileName.trim();
  const dot = trimmed.lastIndexOf(".");
  const base = dot > 0 ? trimmed.slice(0, dot) : trimmed || "upload";
  return `${base}.${ext}`;
}

function loadImage(file: File) {
  return new Promise<HTMLImageElement>((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const image = new Image();
    image.onload = () => {
      URL.revokeObjectURL(url);
      resolve(image);
    };
    image.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error("Could not read the selected image."));
    };
    image.src = url;
  });
}

function createCanvas(width: number, height: number) {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Canvas is not available.");
  return { canvas, ctx };
}

function canvasToBlob(canvas: HTMLCanvasElement, type: string, quality?: number) {
  return new Promise<Blob | null>((resolve) => {
    canvas.toBlob((blob) => resolve(blob), type, quality);
  });
}

function formatOutputName(file: File, type: string) {
  if (type === "image/webp") return renameWithExtension(file.name, "webp");
  if (type === "image/jpeg") return renameWithExtension(file.name, "jpg");
  return file.name;
}

export async function optimizeImageFile(
  file: File,
  {
    maxBytes = MAX_ADMIN_IMAGE_BYTES,
    maxDimension = MAX_ADMIN_IMAGE_DIMENSION,
  }: {
    maxBytes?: number;
    maxDimension?: number;
  } = {},
): Promise<OptimizedImageResult> {
  if (!(file.type ?? "").startsWith("image/")) {
    return { file, changed: false };
  }

  const image = await loadImage(file);
  const largestSide = Math.max(image.naturalWidth, image.naturalHeight);
  const needsResize = largestSide > maxDimension;
  const needsCompression = file.size > maxBytes;

  if (!needsResize && !needsCompression) {
    return { file, changed: false };
  }

  const scales = [1, 0.92, 0.84, 0.76, 0.68, 0.6, 0.52, 0.44];
  const qualities = [0.9, 0.82, 0.74, 0.66, 0.58, 0.5, 0.42, 0.34];
  const targetTypes = ["image/webp", "image/jpeg"] as const;

  let smallestBlob: Blob | null = null;
  let smallestType = "image/webp";

  for (const scale of scales) {
    const dimensionScale = Math.min(1, maxDimension / largestSide) * scale;
    const width = Math.max(1, Math.round(image.naturalWidth * dimensionScale));
    const height = Math.max(1, Math.round(image.naturalHeight * dimensionScale));
    const { canvas, ctx } = createCanvas(width, height);
    ctx.clearRect(0, 0, width, height);
    ctx.drawImage(image, 0, 0, width, height);

    for (const type of targetTypes) {
      for (const quality of qualities) {
        const blob = await canvasToBlob(canvas, type, quality);
        if (!blob) continue;
        if (!smallestBlob || blob.size < smallestBlob.size) {
          smallestBlob = blob;
          smallestType = type;
        }
        if (blob.size <= maxBytes) {
          return {
            file: new File([blob], formatOutputName(file, type), {
              type,
              lastModified: Date.now(),
            }),
            changed: true,
          };
        }
      }
    }
  }

  if (!smallestBlob) {
    throw new Error("Could not optimize the selected image.");
  }

  return {
    file: new File([smallestBlob], formatOutputName(file, smallestType), {
      type: smallestType,
      lastModified: Date.now(),
    }),
    changed: true,
  };
}

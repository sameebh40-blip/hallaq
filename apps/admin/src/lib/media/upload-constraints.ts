export const MAX_ADMIN_IMAGE_BYTES = 15 * 1024 * 1024;
export const MAX_ADMIN_VIDEO_BYTES = 150 * 1024 * 1024;
export const MAX_ADMIN_IMAGE_DIMENSION = 2200;

export const ADMIN_RASTER_IMAGE_EXTENSIONS = ["png", "jpg", "jpeg", "webp"] as const;
export const ADMIN_VECTOR_IMAGE_EXTENSIONS = ["svg"] as const;
export const ADMIN_IMAGE_EXTENSIONS = [...ADMIN_RASTER_IMAGE_EXTENSIONS, ...ADMIN_VECTOR_IMAGE_EXTENSIONS] as const;

export function getLowercaseExtension(fileName: string) {
  const trimmed = String(fileName || "").trim().toLowerCase();
  const dot = trimmed.lastIndexOf(".");
  return dot >= 0 ? trimmed.slice(dot + 1) : "";
}

export function isRasterImageFile(input: { type?: string | null; fileName?: string | null }) {
  const type = String(input.type || "").trim().toLowerCase();
  if (type.startsWith("image/") && type !== "image/svg+xml") return true;
  return ADMIN_RASTER_IMAGE_EXTENSIONS.includes(getLowercaseExtension(String(input.fileName || "")) as (typeof ADMIN_RASTER_IMAGE_EXTENSIONS)[number]);
}

export function isSvgImageFile(input: { type?: string | null; fileName?: string | null }) {
  const type = String(input.type || "").trim().toLowerCase();
  if (type === "image/svg+xml") return true;
  return getLowercaseExtension(String(input.fileName || "")) === "svg";
}

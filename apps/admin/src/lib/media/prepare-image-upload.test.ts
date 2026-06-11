import assert from "node:assert/strict";
import test from "node:test";

import {
  buildImageOptimizationAttempts,
  buildPreparedUploadPath,
} from "./prepare-image-upload.ts";
import {
  MAX_ADMIN_IMAGE_DIMENSION,
  getLowercaseExtension,
  isRasterImageFile,
  isSvgImageFile,
} from "./upload-constraints.ts";

test("detects raster image files by mime or extension", () => {
  assert.equal(isRasterImageFile({ type: "image/png", fileName: "logo.png" }), true);
  assert.equal(isRasterImageFile({ type: "", fileName: "cover.WEBP" }), true);
  assert.equal(isRasterImageFile({ type: "image/svg+xml", fileName: "logo.svg" }), false);
});

test("detects svg files by mime or extension", () => {
  assert.equal(isSvgImageFile({ type: "image/svg+xml", fileName: "logo.txt" }), true);
  assert.equal(isSvgImageFile({ type: "", fileName: "icon.svg" }), true);
  assert.equal(isSvgImageFile({ type: "image/jpeg", fileName: "photo.jpg" }), false);
});

test("normalizes upload output paths by content type", () => {
  assert.equal(buildPreparedUploadPath("shops/123/logo", "logo", "image/webp"), "shops/123/logo.webp");
  assert.equal(buildPreparedUploadPath("shops/123/logo", "logo", "image/svg+xml"), "shops/123/logo.svg");
});

test("builds descending image optimization attempts", () => {
  const attempts = buildImageOptimizationAttempts();
  assert.ok(attempts.length >= 4);
  assert.equal(attempts[0]?.maxDimension, MAX_ADMIN_IMAGE_DIMENSION);
  assert.ok((attempts.at(-1)?.maxDimension ?? 0) < attempts[0]!.maxDimension);
});

test("extracts lowercase extension safely", () => {
  assert.equal(getLowercaseExtension("Banner.JPG"), "jpg");
  assert.equal(getLowercaseExtension("noext"), "");
});

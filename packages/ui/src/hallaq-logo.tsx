"use client";

import type { ImgHTMLAttributes } from "react";

import { SafeImage } from "@hallaq/brand-assets/react";

import { cn } from "./cn";

export function HallaqGoldLogo({
  className,
  assetKey = "app_logo",
  alt,
  ...props
}: Omit<ImgHTMLAttributes<HTMLImageElement>, "src"> & { assetKey?: string }) {
  return (
    <SafeImage
      {...props}
      src={null}
      fallbackKey={assetKey}
      alt={alt ?? "Hallaq"}
      className={cn("h-10 w-10", className)}
    />
  );
}

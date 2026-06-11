"use client";

import type { ReactNode } from "react";

import { BrandAssetsProvider } from "@hallaq/brand-assets/react";

import { type Locale } from "./translations";
import { I18nProvider } from "./translations-client";

export function HallaqProviders({
  children,
  locale
}: {
  children: ReactNode;
  locale: Locale;
}) {
  return (
    <I18nProvider locale={locale}>
      <BrandAssetsProvider>{children}</BrandAssetsProvider>
    </I18nProvider>
  );
}

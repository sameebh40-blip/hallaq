"use client";

import type { ReactNode } from "react";
import { createContext, createElement, useContext } from "react";

import { t, type Locale } from "./translations";

const I18nContext = createContext<{ locale: Locale }>({ locale: "ar" });

export function I18nProvider({
  locale,
  children
}: {
  locale: Locale;
  children: ReactNode;
}) {
  return createElement(I18nContext.Provider, { value: { locale } }, children);
}

export function useT() {
  const { locale } = useContext(I18nContext);
  return (keyPath: string) => t(keyPath, locale);
}

export function useLocale() {
  const { locale } = useContext(I18nContext);
  return locale;
}

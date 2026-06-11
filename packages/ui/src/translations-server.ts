import { cookies } from "next/headers";

import { t as baseT, type Locale } from "./translations";

export function createT(locale: Locale) {
  return (keyPath: string) => baseT(keyPath, locale);
}

export async function getServerLocale(): Promise<Locale> {
  const cookieStore = await cookies();
  return cookieStore.get("hallaq_locale")?.value === "en" ? "en" : "ar";
}

export async function getT(): Promise<(keyPath: string) => string> {
  return createT(await getServerLocale());
}

import { createSupabaseBrowserClient } from "@hallaq/supabase/browser";

const qaCookieName = "hallaq-qa-auth";
const qaActiveCookieName = "hallaq_qa_active";

function hasQaActiveCookie() {
  if (typeof document === "undefined") return false;
  return document.cookie.split(";").some((c) => c.trim() === `${qaActiveCookieName}=1`);
}

export function createAppSupabaseBrowserClient() {
  return createSupabaseBrowserClient(hasQaActiveCookie() ? { cookieName: qaCookieName } : undefined);
}


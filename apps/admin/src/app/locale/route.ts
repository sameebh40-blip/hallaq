import { cookies } from "next/headers";
import { NextResponse } from "next/server";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const value = url.searchParams.get("value") === "en" ? "en" : "ar";
  const cookieStore = await cookies();
  cookieStore.set("hallaq_locale", value, { path: "/", sameSite: "lax" });
  const referer = request.headers.get("referer");
  if (referer) return NextResponse.redirect(referer);
  return NextResponse.redirect(new URL("./dashboard", url));
}

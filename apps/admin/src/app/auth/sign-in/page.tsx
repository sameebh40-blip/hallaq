import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { userFacingAuthError } from "@hallaq/supabase/user-facing";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { getT } from "@hallaq/ui/translations-server";
import { LockKeyhole, Mail, ShieldCheck } from "lucide-react";

export default async function SignInPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string; next?: string }>;
}) {
  const t = await getT();
  const params = searchParams ? await searchParams : undefined;
  const next = params?.next && params.next.startsWith("/") && !params.next.startsWith("//") ? params.next : null;

  async function signIn(formData: FormData) {
    "use server";

    const email = String(formData.get("email") ?? "");
    const password = String(formData.get("password") ?? "");

    if (!email || !password) {
      redirect(`/auth/sign-in?error=${encodeURIComponent("Email and password are required.")}`);
    }

    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.auth.signInWithPassword({ email, password });

    if (error) {
      const qs = new URLSearchParams({ error: userFacingAuthError(error.message) });
      if (next) qs.set("next", next);
      redirect(`/auth/sign-in?${qs.toString()}`);
    }
    redirect(next ?? "/dashboard");
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-1">
        <h1 className="text-xl font-semibold tracking-tight">{t("auth.signIn")}</h1>
        <p className="text-sm text-muted-foreground">
          Admin access only. This panel is private and protected.
        </p>
      </div>

      <form action={signIn} className="flex flex-col gap-4">
        <div className="flex flex-col gap-2">
          <Label htmlFor="email">{t("auth.email")}</Label>
          <div className="relative">
            <Mail className="pointer-events-none absolute inset-y-0 start-3 my-auto h-4 w-4 text-muted-foreground" />
            <Input
              id="email"
              name="email"
              type="email"
              className="h-11 bg-white/5 ps-10"
              placeholder="admin@hallaq.com"
            />
          </div>
        </div>

        <div className="flex flex-col gap-2">
          <Label htmlFor="password">{t("auth.password")}</Label>
          <div className="relative">
            <LockKeyhole className="pointer-events-none absolute inset-y-0 start-3 my-auto h-4 w-4 text-muted-foreground" />
            <Input
              id="password"
              name="password"
              type="password"
              className="h-11 bg-white/5 ps-10"
              placeholder="••••••••"
            />
          </div>
        </div>

        <div className="flex items-center justify-between gap-3">
          <label className="flex items-center gap-2 text-sm text-muted-foreground">
            <input type="checkbox" name="remember" defaultChecked className="h-4 w-4 accent-[hsl(var(--gold))]" />
            Remember me
          </label>
          <Link href="/auth/forgot-password" className="text-sm text-muted-foreground underline underline-offset-4">
            {t("auth.forgotPassword")}
          </Link>
        </div>

        {params?.error ? (
          <div className="rounded-md border border-destructive/40 bg-destructive/10 p-3 text-sm text-destructive">
            {params.error}
          </div>
        ) : null}

        <Button type="submit" className="h-11 w-full">
          {t("auth.signIn")}
        </Button>

        <div className="flex items-center justify-center gap-2 rounded-lg border border-white/10 bg-white/5 p-3 text-xs text-muted-foreground">
          <ShieldCheck className="h-4 w-4 text-primary" />
          Session is encrypted and protected by Supabase Auth.
        </div>
      </form>
    </div>
  );
}

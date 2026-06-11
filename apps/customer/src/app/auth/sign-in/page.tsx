import Link from "next/link";
import { redirect } from "next/navigation";

import { createAppSupabaseServerClient } from "@/lib/supabase";
import { userFacingAuthError } from "@hallaq/supabase/user-facing";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { getT } from "@hallaq/ui/translations-server";
import { LockKeyhole, Mail } from "lucide-react";

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

    const supabase = await createAppSupabaseServerClient();
    const { error } = await supabase.auth.signInWithPassword({ email, password });

    if (error) {
      const qs = new URLSearchParams({ error: userFacingAuthError(error.message) });
      if (next) qs.set("next", next);
      redirect(`/auth/sign-in?${qs.toString()}`);
    }
    redirect(next ?? "/");
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-1">
        <h1 className="text-xl font-semibold">{t("auth.signIn")}</h1>
        <p className="text-sm text-muted-foreground">
          {t("home.subtitle")}
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
              autoComplete="email"
              required
              className="ps-10"
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
              autoComplete="current-password"
              required
              className="ps-10"
            />
          </div>
        </div>

        {params?.error ? (
          <div className="rounded-md border border-destructive/40 bg-destructive/10 p-3 text-sm text-destructive">
            {params.error}
          </div>
        ) : null}

        <Button type="submit" className="w-full">
          {t("auth.signIn")}
        </Button>

        <div className="flex items-center justify-between text-sm">
          <Link
            href="/auth/forgot-password"
            className="text-muted-foreground underline underline-offset-4"
          >
            {t("auth.forgotPassword")}
          </Link>
          <Link href="/auth/sign-up" className="underline underline-offset-4">
            {t("auth.signUp")}
          </Link>
        </div>
      </form>
    </div>
  );
}

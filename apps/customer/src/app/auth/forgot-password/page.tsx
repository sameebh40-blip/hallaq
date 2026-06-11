import Link from "next/link";
import { headers } from "next/headers";
import { redirect } from "next/navigation";

import { createAppSupabaseServerClient } from "@/lib/supabase";
import { userFacingAuthError } from "@hallaq/supabase/user-facing";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { getT } from "@hallaq/ui/translations-server";
import { Mail } from "lucide-react";

export default async function ForgotPasswordPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string; sent?: string }>;
}) {
  const t = await getT();
  const params = searchParams ? await searchParams : undefined;

  async function sendReset(formData: FormData) {
    "use server";

    const email = String(formData.get("email") ?? "");
    const origin = (await headers()).get("origin") ?? "";

    const supabase = await createAppSupabaseServerClient();
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${origin}/auth/callback?next=/auth/reset-password`
    });

    if (error) redirect(`/auth/forgot-password?error=${encodeURIComponent(userFacingAuthError(error.message))}`);
    redirect("/auth/forgot-password?sent=1");
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-1">
        <h1 className="text-xl font-semibold">{t("auth.resetPassword")}</h1>
        <p className="text-sm text-muted-foreground">
          Enter your email and we’ll send you a reset link.
        </p>
      </div>

      <form action={sendReset} className="flex flex-col gap-4">
        <div className="flex flex-col gap-2">
          <Label htmlFor="email">{t("auth.email")}</Label>
          <div className="relative">
            <Mail className="pointer-events-none absolute inset-y-0 start-3 my-auto h-4 w-4 text-muted-foreground" />
            <Input id="email" name="email" type="email" required className="ps-10" />
          </div>
        </div>

        {params?.sent ? (
          <div className="rounded-md border border-border bg-secondary/40 p-3 text-sm text-muted-foreground">
            {t("auth.resetLinkSent")}
          </div>
        ) : null}

        {params?.error ? (
          <div className="rounded-md border border-destructive/40 bg-destructive/10 p-3 text-sm text-destructive">
            {params.error}
          </div>
        ) : null}

        <Button type="submit" className="w-full">
          {t("auth.sendResetLink")}
        </Button>

        <div className="text-center text-sm text-muted-foreground">
          <Link href="/auth/sign-in" className="underline underline-offset-4">
            {t("auth.backToSignIn")}
          </Link>
        </div>
      </form>
    </div>
  );
}

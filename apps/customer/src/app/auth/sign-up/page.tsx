import Link from "next/link";
import { redirect } from "next/navigation";

import { createAppSupabaseServerClient } from "@/lib/supabase";
import { userFacingAuthError } from "@hallaq/supabase/user-facing";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { getT } from "@hallaq/ui/translations-server";
import { LockKeyhole, Mail, UserRound } from "lucide-react";

export default async function SignUpPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const t = await getT();
  const params = searchParams ? await searchParams : undefined;

  async function signUp(formData: FormData) {
    "use server";

    const fullName = String(formData.get("fullName") ?? "");
    const email = String(formData.get("email") ?? "");
    const password = String(formData.get("password") ?? "");

    const supabase = await createAppSupabaseServerClient();

    try {
      const { data: allowed } = await supabase.rpc("get_setting_bool", {
        p_key: "allow_customer_signup",
        p_default: true
      });
      if (!allowed) {
        redirect(`/auth/sign-up?error=${encodeURIComponent("Sign up is currently disabled.")}`);
      }
    } catch {}

    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { full_name: fullName }
      }
    });

    if (error) redirect(`/auth/sign-up?error=${encodeURIComponent(userFacingAuthError(error.message))}`);
    redirect("/");
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-1">
        <h1 className="text-xl font-semibold">{t("auth.signUp")}</h1>
        <p className="text-sm text-muted-foreground">{t("home.subtitle")}</p>
      </div>

      <form action={signUp} className="flex flex-col gap-4">
        <div className="flex flex-col gap-2">
          <Label htmlFor="fullName">{t("auth.fullName")}</Label>
          <div className="relative">
            <UserRound className="pointer-events-none absolute inset-y-0 start-3 my-auto h-4 w-4 text-muted-foreground" />
            <Input id="fullName" name="fullName" required className="ps-10" />
          </div>
        </div>

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
              autoComplete="new-password"
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
          {t("auth.signUp")}
        </Button>

        <div className="text-center text-sm text-muted-foreground">
          <Link href="/auth/sign-in" className="underline underline-offset-4">
            {t("auth.signIn")}
          </Link>
        </div>
      </form>
    </div>
  );
}

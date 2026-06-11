import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { userFacingAuthError } from "@hallaq/supabase/user-facing";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { LockKeyhole } from "lucide-react";

export default async function ResetPasswordPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string; done?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;

  async function resetPassword(formData: FormData) {
    "use server";

    const password = String(formData.get("password") ?? "");
    const supabase = await createSupabaseServerClient();

    const { data: userData } = await supabase.auth.getUser();
    if (!userData.user) redirect("/auth/sign-in");

    const { error } = await supabase.auth.updateUser({ password });
    if (error) redirect(`/auth/reset-password?error=${encodeURIComponent(userFacingAuthError(error.message))}`);

    const { error: profileError } = await supabase
      .from("profiles")
      .update({ must_change_password: false })
      .eq("id", userData.user.id);
    if (profileError) redirect(`/auth/reset-password?error=${encodeURIComponent("Failed to update profile.")}`);

    redirect("/auth/reset-password?done=1");
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-1">
        <h1 className="text-xl font-semibold">Set new password</h1>
        <p className="text-sm text-muted-foreground">Choose a strong password.</p>
      </div>

      <form action={resetPassword} className="flex flex-col gap-4">
        <div className="flex flex-col gap-2">
          <Label htmlFor="password">New password</Label>
          <div className="relative">
            <LockKeyhole className="pointer-events-none absolute inset-y-0 start-3 my-auto h-4 w-4 text-muted-foreground" />
            <Input id="password" name="password" type="password" required className="ps-10" />
          </div>
        </div>

        {params?.done ? (
          <div className="rounded-md border border-border bg-secondary/40 p-3 text-sm text-muted-foreground">
            Password updated. You can sign in again.
          </div>
        ) : null}

        {params?.error ? (
          <div className="rounded-md border border-destructive/40 bg-destructive/10 p-3 text-sm text-destructive">
            {params.error}
          </div>
        ) : null}

        <Button type="submit" className="w-full">
          Update password
        </Button>

        <div className="text-center text-sm text-muted-foreground">
          <Link href="/auth/sign-in" className="underline underline-offset-4">
            Back to sign in
          </Link>
        </div>
      </form>
    </div>
  );
}

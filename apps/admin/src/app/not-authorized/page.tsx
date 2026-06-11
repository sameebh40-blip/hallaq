import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

export const dynamic = "force-dynamic";

export default async function NotAuthorizedPage() {
  const supabase = await createSupabaseServerClient();
  const { data: auth } = await supabase.auth.getUser();
  const user = auth.user;

  if (!user) redirect("/auth/sign-in");

  const { data: profile } = await supabase
    .from("profiles")
    .select("id, role, full_name, email")
    .eq("id", user.id)
    .maybeSingle();

  return (
    <main className="mx-auto flex min-h-dvh max-w-3xl flex-col justify-center px-4 py-12">
      <LuxuryCard className="p-6">
        <div className="flex flex-col gap-4">
          <div className="text-lg font-semibold">Not authorized</div>
          <div className="text-sm text-muted-foreground">
            This account is signed in, but it is not an admin account. Admin pages require profiles.role = &quot;admin&quot;.
          </div>

          <div className="grid gap-2 rounded-xl border border-white/10 bg-white/5 p-4 text-sm">
            <div>
              <span className="text-muted-foreground">User ID: </span>
              <span className="font-mono">{user.id}</span>
            </div>
            <div>
              <span className="text-muted-foreground">Email: </span>
              <span className="font-mono">{user.email ?? "-"}</span>
            </div>
            <div>
              <span className="text-muted-foreground">Profile role: </span>
              <span className="font-mono">{profile?.role ?? "-"}</span>
            </div>
          </div>

          <div className="text-sm text-muted-foreground">
            Fix: in Supabase Dashboard → SQL Editor, run:
          </div>
          <pre className="overflow-x-auto rounded-xl border border-white/10 bg-black/30 p-4 text-xs">
            {`update public.profiles set role = 'admin' where id = '${user.id}';`}
          </pre>

          <div className="flex flex-wrap items-center justify-end gap-2 pt-2">
            <Button asChild variant="ghost">
              <Link href="/auth/sign-in">Back to sign in</Link>
            </Button>
            <form action="/auth/sign-out" method="post">
              <Button type="submit" variant="secondary">
                Sign out
              </Button>
            </form>
            <Button asChild>
              <Link href="/dashboard">Retry</Link>
            </Button>
          </div>
        </div>
      </LuxuryCard>
    </main>
  );
}

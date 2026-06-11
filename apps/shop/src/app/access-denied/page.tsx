import Link from "next/link";
import { redirect } from "next/navigation";

import { createAppSupabaseServerClient } from "@/lib/supabase";
import { userFacingAuthError } from "@hallaq/supabase/user-facing";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

export default async function AccessDeniedPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string; sent?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const supabase = await createAppSupabaseServerClient();
  const { data: userData } = await supabase.auth.getUser();
  if (!userData.user) redirect("/auth/sign-in");

  const { data: existing } = await supabase
    .from("role_requests")
    .select("id, requested_role, status, created_at")
    .eq("profile_id", userData.user.id)
    .order("created_at", { ascending: false });

  async function requestAccess(formData: FormData) {
    "use server";

    const requestedRole = "shop_owner";
    const shopName = String(formData.get("shopName") ?? "");
    const phone = String(formData.get("phone") ?? "");

    const supabase = await createAppSupabaseServerClient();
    const { data: userData } = await supabase.auth.getUser();
    if (!userData.user) redirect("/auth/sign-in");

    const { data: pending } = await supabase
      .from("role_requests")
      .select("id")
      .eq("profile_id", userData.user.id)
      .eq("status", "pending")
      .limit(1);
    if (pending?.length) {
      redirect(`/access-denied?error=${encodeURIComponent("You already have a pending request.")}`);
    }

    const { error } = await supabase.from("role_requests").insert({
      profile_id: userData.user.id,
      requested_role: requestedRole,
      shop_name: shopName || null,
      phone: phone || null
    });

    if (error) redirect(`/access-denied?error=${encodeURIComponent(userFacingAuthError(error.message))}`);
    redirect("/access-denied?sent=1");
  }

  return (
    <main className="mx-auto flex min-h-dvh max-w-lg flex-col justify-center gap-6 px-4 py-12">
      <LuxuryCard className="p-6">
        <div className="flex flex-col gap-3">
          <div className="text-lg font-semibold">Access denied</div>
          <div className="text-sm text-muted-foreground">
            This area is only for shop owners.
          </div>

          {existing && existing.length ? (
            <div className="rounded-md border border-border bg-secondary/30 p-3 text-sm text-muted-foreground">
              Latest request: {existing[0].requested_role} ({existing[0].status})
            </div>
          ) : null}

          {params?.sent ? (
            <div className="rounded-md border border-border bg-secondary/30 p-3 text-sm text-muted-foreground">
              Request sent. We’ll review it soon.
            </div>
          ) : null}

          {params?.error ? (
            <div className="rounded-md border border-destructive/40 bg-destructive/10 p-3 text-sm text-destructive">
              {params.error}
            </div>
          ) : null}

          <form action={requestAccess} className="flex flex-col gap-3 pt-2">
            <input type="hidden" name="requestedRole" value="shop_owner" />

            <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
              <div className="flex flex-col gap-2">
                <Label htmlFor="shopName">Shop name</Label>
                <Input id="shopName" name="shopName" placeholder="Optional" />
              </div>
              <div className="flex flex-col gap-2">
                <Label htmlFor="phone">Phone</Label>
                <Input id="phone" name="phone" placeholder="Optional" />
              </div>
            </div>

            <Button type="submit">Send request</Button>
          </form>

          <div className="flex items-center gap-2 pt-2">
            <Button asChild variant="ghost">
              <Link href="/">Back</Link>
            </Button>
          </div>
        </div>
      </LuxuryCard>
    </main>
  );
}

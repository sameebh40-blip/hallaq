import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

export const dynamic = "force-dynamic";

export default async function BootstrapAdminPage() {
  async function bootstrap() {
    "use server";

    const supabase = await createSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();

    if (!user) {
      redirect("/auth/sign-in?error=Please%20sign%20in%20first.");
    }

    const admin = await createSupabaseAdminClient();

    const buckets = [
      "avatars",
      "barber-images",
      "shop-images",
      "portfolio",
      "reels",
      "reels-media",
      "post-media",
      "review-images",
      "review-photos",
      "service-images",
      "products"
    ];
    for (const bucketId of buckets) {
      const { error: getError } = await admin.storage.getBucket(bucketId);
      if (getError) {
        const { error: createError } = await admin.storage.createBucket(bucketId, { public: false });
        if (createError) redirect(`/health?error=${encodeURIComponent(createError.message)}`);
      }
    }

    try {
      await admin.from("profiles").upsert({ id: user.id, ...(user.email ? { email: user.email } : {}) });
    } catch {
      await admin.from("profiles").upsert({ id: user.id });
    }

    const { count, error: countError } = await admin
      .from("profiles")
      .select("id", { count: "exact", head: true })
      .eq("role", "admin");
    if (countError) redirect(`/health?error=${encodeURIComponent(countError.message)}`);

    if ((count ?? 0) === 0) {
      const { error: promoteError } = await admin.from("profiles").update({ role: "admin" }).eq("id", user.id);
      if (promoteError) redirect(`/health?error=${encodeURIComponent(promoteError.message)}`);
    }

    redirect("/health?bootstrapped=1");
  }

  return (
    <main className="mx-auto flex min-h-dvh max-w-lg flex-col justify-center px-4 py-12">
      <LuxuryCard className="p-6">
        <div className="flex flex-col gap-3">
          <div className="text-lg font-semibold">Bootstrap</div>
          <div className="text-sm text-muted-foreground">
            Creates required Storage buckets and makes the first signed-in user admin (only if no admins exist yet).
          </div>
          <form action={bootstrap} className="flex items-center justify-end gap-2 pt-2">
            <Button asChild variant="ghost">
              <Link href="/health">Back</Link>
            </Button>
            <Button type="submit">Run Bootstrap</Button>
          </form>
        </div>
      </LuxuryCard>
    </main>
  );
}

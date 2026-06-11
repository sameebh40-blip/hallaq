import Link from "next/link";
import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { redirect } from "next/navigation";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type CheckItem = { label: string; ok: boolean; detail?: string };

export default async function DiagnosticsPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const errorMessage = (params?.error ?? "").trim();
  const supabase = await createSupabaseServerClient();
  const { data: auth } = await supabase.auth.getUser();
  const user = auth.user ?? null;

  const checks: CheckItem[] = [];

  checks.push({ label: "Signed in", ok: Boolean(user), detail: user?.email ?? undefined });

  const { data: profile, error: profileError } = user
    ? await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle()
    : { data: null, error: null };
  checks.push({
    label: "Profile readable",
    ok: !profileError,
    detail: profileError?.message
  });
  checks.push({ label: "Admin role", ok: profile?.role === "admin", detail: profile?.role ?? undefined });

  let adminReady = false;
  let admin: Awaited<ReturnType<typeof createSupabaseAdminClient>> | null = null;
  try {
    admin = await createSupabaseAdminClient();
    adminReady = true;
  } catch (e) {
    const message = e instanceof Error ? e.message : "Service role not available";
    checks.push({ label: "Service role client", ok: false, detail: message });
  }
  if (adminReady) checks.push({ label: "Service role client", ok: true });

  const bucketIds = [
    "avatars",
    "portfolio",
    "reels-media",
    "post-media",
    "shop-images",
    "barber-images",
    "review-images",
    "review-photos",
    "service-images"
  ];
  if (admin) {
    for (const bucketId of bucketIds) {
      const { error } = await admin.storage.getBucket(bucketId);
      checks.push({
        label: `Bucket: ${bucketId}`,
        ok: !error,
        detail: error?.message
      });
    }
  }

  async function runWriteTest() {
    "use server";

    const supabase = await createSupabaseServerClient();
    const { data: auth } = await supabase.auth.getUser();
    const userId = auth.user?.id ?? null;
    if (!userId) return;

    const admin = await createSupabaseAdminClient();

    const path = `diagnostics/${userId}-${Date.now()}.txt`;
    const bytes = new TextEncoder().encode("ok");
    const { error: uploadError } = await admin.storage.from("reels-media").upload(path, bytes, { contentType: "text/plain", upsert: true });
    if (uploadError) redirect(`/diagnostics?error=${encodeURIComponent(uploadError.message)}`);
    const { error: removeError } = await admin.storage.from("reels-media").remove([path]);
    if (removeError) redirect(`/diagnostics?error=${encodeURIComponent(removeError.message)}`);

    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: userId,
      action: "diagnostics_write_test",
      entity_type: "system",
      entity_id: null,
      meta: {}
    });
    if (logError) redirect(`/diagnostics?error=${encodeURIComponent(logError.message)}`);
  }

  return (
    <PageFrame
      title="Diagnostics"
      subtitle="Verify auth, Supabase config, storage buckets, and write access."
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/health">Health</Link>
        </Button>
      }
    >
      {errorMessage ? (
        <LuxuryCard className="mb-4 border border-rose-500/40 bg-rose-500/10 p-4 text-sm text-rose-100">{errorMessage}</LuxuryCard>
      ) : null}
      <LuxuryCard className="p-5">
        <div className="grid gap-3 text-sm">
          {checks.map((c) => (
            <div key={c.label} className="flex items-start justify-between gap-4">
              <div className="text-muted-foreground">{c.label}</div>
              <div className="text-right">
                <div className={c.ok ? "text-emerald-200" : "text-rose-200"}>{c.ok ? "OK" : "FAIL"}</div>
                {c.detail ? <div className="text-xs text-muted-foreground break-all">{c.detail}</div> : null}
              </div>
            </div>
          ))}
        </div>
      </LuxuryCard>
      <div className="flex justify-end pt-4">
        <form action={runWriteTest}>
          <Button type="submit" variant="secondary">
            Run write test
          </Button>
        </form>
      </div>
    </PageFrame>
  );
}

import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

const requiredFlags = [
  { key: "ai_haircut_studio", label: "AI Haircut Studio", defaultEnabled: false },
  { key: "gift_cards", label: "Gift Cards", defaultEnabled: false },
  { key: "home_service", label: "Home Service", defaultEnabled: false },
  { key: "hallaq_city", label: "Hallaq City", defaultEnabled: false },
  { key: "awards", label: "Awards", defaultEnabled: false },
  { key: "waitlist", label: "Waitlist", defaultEnabled: false },
  { key: "reception_mode", label: "Reception Mode", defaultEnabled: false },
  { key: "customer_notes", label: "Customer Notes", defaultEnabled: false },
  { key: "advanced_analytics", label: "Advanced Analytics", defaultEnabled: false },
  { key: "referral_program", label: "Referral Program", defaultEnabled: false }
];

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong.";
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as an admin account.";
  }
  return m;
}

export default async function FeatureFlagsPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((params?.error ?? "").trim());
  const supabase = await createSupabaseServerClient();

  const { data: rows } = await supabase
    .from("feature_flags")
    .select("key, enabled, description, updated_at")
    .in(
      "key",
      requiredFlags.map((f) => f.key)
    );

  const current = new Map<string, { description: string | null; enabled: boolean }>();
  rows?.forEach((r) => current.set(r.key, { description: r.description, enabled: r.enabled }));

  async function saveFlags(formData: FormData) {
    "use server";

    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const upserts = requiredFlags.map((f) => ({
      key: f.key,
      description: f.label,
      enabled: String(formData.get(f.key) ?? "") === "on",
      updated_at: new Date().toISOString()
    }));

    const { error: upsertError } = await supabase.from("feature_flags").upsert(upserts, { onConflict: "key" });
    if (upsertError) redirect(`/admin/feature-flags?error=${encodeURIComponent(upsertError.message)}`);

    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "feature_flags_updated",
      entity_type: "feature_flags",
      entity_id: null,
      meta: Object.fromEntries(upserts.map((u) => [u.key, u.enabled]))
    });
    if (logError) redirect(`/admin/feature-flags?error=${encodeURIComponent(logError.message)}`);

    redirect("/admin/feature-flags");
  }

  return (
    <PageFrame title="Feature Flags" subtitle="Enable or disable features globally. Changes apply instantly.">
      {params?.error ? (
        <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard>
      ) : null}

      <form action={saveFlags} className="grid grid-cols-1 gap-3 text-sm">
        {requiredFlags.map((f) => {
          const row = current.get(f.key);
          const label = row?.description?.trim() || f.label;
          const enabled = row?.enabled ?? f.defaultEnabled;

          return (
            <label
              key={f.key}
              className="flex items-center justify-between gap-3 rounded-lg border border-white/10 bg-white/5 px-4 py-3"
            >
              <div className="flex flex-col gap-1">
                <span className="font-medium">{label}</span>
                <span className="text-xs text-muted-foreground">{f.key}</span>
              </div>
              <input
                type="checkbox"
                name={f.key}
                className="h-4 w-4 accent-[hsl(var(--gold))]"
                defaultChecked={enabled}
              />
            </label>
          );
        })}

        <Button type="submit" className="h-11">
          Save
        </Button>
      </form>
    </PageFrame>
  );
}

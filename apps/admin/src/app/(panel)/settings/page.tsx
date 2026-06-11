import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getT } from "@hallaq/ui/translations-server";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

const platformKeys = [
  { key: "maintenance_mode", label: "Maintenance Mode", defaultEnabled: false },
  { key: "allow_customer_signup", label: "Allow Customer Signup", defaultEnabled: true },
  { key: "require_post_approval", label: "Require Post Approval", defaultEnabled: true }
];

function getEnabledFromSettingsValue(value: unknown) {
  if (!value || typeof value !== "object") return false;
  const enabled = (value as { enabled?: unknown }).enabled;
  return typeof enabled === "boolean" ? enabled : false;
}

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong.";
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as an admin account.";
  }
  return m;
}

export default async function SettingsPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const t = await getT();
  const params = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((params?.error ?? "").trim());
  const supabase = await createSupabaseServerClient();

  const { data: settingsRows } = await supabase
    .from("admin_settings")
    .select("key, value, updated_at")
    .in(
      "key",
      platformKeys.map((k) => k.key)
    );

  const current = new Map<string, boolean>();
  settingsRows?.forEach((r) => current.set(r.key, getEnabledFromSettingsValue(r.value)));

  async function saveAccount(formData: FormData) {
    "use server";

    const email = String(formData.get("email") ?? "").trim();
    const password = String(formData.get("password") ?? "");

    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    if (email) {
      const { error } = await supabase.auth.updateUser({ email });
      if (error) redirect(`/settings?error=${encodeURIComponent(error.message)}`);
    }
    if (password) {
      const { error } = await supabase.auth.updateUser({ password });
      if (error) redirect(`/settings?error=${encodeURIComponent(error.message)}`);
    }

    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "admin_account_updated",
      entity_type: "admin",
      entity_id: actorId,
      meta: { emailChanged: Boolean(email), passwordChanged: Boolean(password) }
    });
    if (logError) redirect(`/settings?error=${encodeURIComponent(logError.message)}`);

    redirect("/settings");
  }

  async function savePlatform(formData: FormData) {
    "use server";

    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    const upserts: Array<{
      key: string;
      value: { enabled: boolean };
      updated_at: string;
      updated_by: string | null;
    }> = platformKeys.map((k) => ({
      key: k.key,
      value: { enabled: String(formData.get(k.key) ?? "") === "on" },
      updated_at: new Date().toISOString(),
      updated_by: actorId
    }));

    const { error: upsertError } = await supabase.from("admin_settings").upsert(upserts, { onConflict: "key" });
    if (upsertError) redirect(`/settings?error=${encodeURIComponent(upsertError.message)}`);

    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "platform_settings_updated",
      entity_type: "settings",
      entity_id: null,
      meta: Object.fromEntries(upserts.map((u) => [u.key, u.value.enabled]))
    });
    if (logError) redirect(`/settings?error=${encodeURIComponent(logError.message)}`);

    redirect("/settings");
  }

  return (
    <PageFrame title={t("admin.settings.title")} subtitle={t("admin.settings.subtitle")}>
      {params?.error ? (
        <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard>
      ) : null}
      <div className="grid grid-cols-1 gap-3 xl:grid-cols-2">
        <LuxuryCard className="p-5">
          <div className="flex flex-col gap-4">
            <div className="flex flex-col gap-1">
              <div className="text-sm font-semibold">Admin Account</div>
              <div className="text-xs text-muted-foreground">Update credentials and security.</div>
            </div>

            <form action={saveAccount} className="grid grid-cols-1 gap-3">
              <div className="flex flex-col gap-2">
                <Label htmlFor="email">Email</Label>
                <Input id="email" name="email" type="email" placeholder="admin@hallaq.com" className="h-11 bg-white/5" />
              </div>
              <div className="flex flex-col gap-2">
                <Label htmlFor="password">New password</Label>
                <Input id="password" name="password" type="password" className="h-11 bg-white/5" />
              </div>
              <Button type="submit" className="h-11">
                {t("admin.common.save")}
              </Button>
            </form>
          </div>
        </LuxuryCard>

        <LuxuryCard className="p-5">
          <div className="flex flex-col gap-4">
            <div className="flex flex-col gap-1">
              <div className="text-sm font-semibold">Platform Settings</div>
              <div className="text-xs text-muted-foreground">Operational toggles.</div>
            </div>

            <form action={savePlatform} className="grid grid-cols-1 gap-3 text-sm">
              {platformKeys.map((s) => (
                <label
                  key={s.key}
                  className="flex items-center justify-between gap-3 rounded-lg border border-white/10 bg-white/5 px-4 py-3"
                >
                  <span className="font-medium">{s.label}</span>
                  <input
                    type="checkbox"
                    name={s.key}
                    className="h-4 w-4 accent-[hsl(var(--gold))]"
                    defaultChecked={current.get(s.key) ?? s.defaultEnabled}
                  />
                </label>
              ))}
              <Button type="submit" className="h-11">
                {t("admin.common.save")}
              </Button>
            </form>
          </div>
        </LuxuryCard>
      </div>
    </PageFrame>
  );
}

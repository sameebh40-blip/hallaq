import { redirect } from "next/navigation";

import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getMyProfile } from "@hallaq/supabase/profile";

import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

export default async function BusinessMessagesPage() {
  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);
  if (!profile) return <div className="text-sm text-muted-foreground">Sign in required.</div>;

  const { data: rows } = await supabase
    .from("notifications")
    .select("id, type, title, body, data, read, created_at")
    .eq("profile_id", profile.id)
    .in("type", ["message", "chat", "dm", "inbox"])
    .order("created_at", { ascending: false })
    .limit(200);

  async function markRead(formData: FormData) {
    "use server";
    const id = String(formData.get("id") ?? "").trim();
    const read = String(formData.get("read") ?? "") === "true";
    if (!id) redirect("/business/messages");
    const supabase = await createAppSupabaseServerClient();
    await supabase.from("notifications").update({ read }).eq("id", id);
    redirect("/business/messages");
  }

  return (
    <div className="grid gap-4">
      <LuxuryCard className="p-4">
        <div className="text-base font-semibold">Messages</div>
        <div className="text-sm text-muted-foreground">
          This inbox shows message-type events delivered through notifications. If your account has no message events yet, the inbox will be empty.
        </div>
      </LuxuryCard>

      <LuxuryCard className="overflow-hidden">
        <div className="divide-y divide-white/10">
          {rows?.length ? (
            rows.map((n) => (
              <div key={n.id} className={n.read ? "px-5 py-4" : "bg-[hsl(var(--gold))/0.06] px-5 py-4"}>
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <div className="text-sm font-semibold">{(n.title ?? "").trim() || "Message"}</div>
                    <div className="pt-1 text-sm text-muted-foreground">{(n.body ?? "").trim()}</div>
                    <div className="pt-2 text-xs text-muted-foreground">{new Date(n.created_at).toLocaleString()}</div>
                  </div>
                  <form action={markRead}>
                    <input type="hidden" name="id" value={n.id} />
                    <input type="hidden" name="read" value={String(!n.read)} />
                    <Button type="submit" size="sm" variant="secondary">
                      {n.read ? "Mark unread" : "Mark read"}
                    </Button>
                  </form>
                </div>
              </div>
            ))
          ) : (
            <div className="px-5 py-10 text-center text-sm text-muted-foreground">No messages yet.</div>
          )}
        </div>
      </LuxuryCard>
    </div>
  );
}


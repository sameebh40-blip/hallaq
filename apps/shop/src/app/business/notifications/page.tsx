import { redirect } from "next/navigation";

import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getMyProfile } from "@hallaq/supabase/profile";

import { BusinessPageHeader } from "@/components/business/page-header";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

function typeLabel(type: string) {
  const t = (type ?? "").trim() || "generic";
  if (t === "booking_created") return "New booking";
  if (t === "booking_cancelled") return "Booking cancelled";
  if (t === "booking_updated") return "Booking updated";
  if (t === "review_created") return "New review";
  if (t === "reel_interaction") return "Reel activity";
  return t;
}

export default async function BusinessNotificationsPage({
  searchParams
}: {
  searchParams?: Promise<{ filter?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const filter = (params?.filter ?? "").trim();

  const supabase = await createAppSupabaseServerClient();
  const profile = await getMyProfile(supabase);
  if (!profile) return <div className="text-sm text-muted-foreground">Sign in required.</div>;

  let q = supabase
    .from("notifications")
    .select("id, type, title, body, data, read, created_at")
    .eq("profile_id", profile.id)
    .order("created_at", { ascending: false })
    .limit(200);

  if (filter === "unread") q = q.eq("read", false);

  const { data: rows } = await q;

  async function markRead(formData: FormData) {
    "use server";
    const id = String(formData.get("id") ?? "").trim();
    const read = String(formData.get("read") ?? "") === "true";
    if (!id) redirect("/business/notifications");
    const supabase = await createAppSupabaseServerClient();
    await supabase.from("notifications").update({ read }).eq("id", id);
    redirect("/business/notifications");
  }

  async function markAllRead() {
    "use server";
    const supabase = await createAppSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const userId = u.user?.id ?? null;
    if (!userId) redirect("/business/notifications");
    await supabase.from("notifications").update({ read: true }).eq("profile_id", userId).eq("read", false);
    redirect("/business/notifications");
  }

  return (
    <div className="grid gap-4">
      <BusinessPageHeader
        title="Notifications"
        subtitle="Realtime notifications for your shop owner account."
        actions={
          <>
            <form method="get" className="flex items-center gap-2">
              <select name="filter" defaultValue={filter || "all"} className="h-9 rounded-md border border-white/10 bg-white/5 px-3 text-sm">
                <option value="all">All</option>
                <option value="unread">Unread</option>
              </select>
              <Button type="submit" size="sm" variant="secondary">
                Apply
              </Button>
            </form>
            <form action={markAllRead}>
              <Button type="submit" size="sm" variant="ghost">
                Mark all read
              </Button>
            </form>
          </>
        }
      />

      <LuxuryCard className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[980px] text-sm">
            <thead className="text-xs text-muted-foreground">
              <tr className="border-b border-white/10">
                <th className="px-5 py-3 text-left font-medium">Type</th>
                <th className="px-5 py-3 text-left font-medium">Title</th>
                <th className="px-5 py-3 text-left font-medium">Body</th>
                <th className="px-5 py-3 text-left font-medium">When</th>
                <th className="px-5 py-3 text-right font-medium">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/10">
              {rows?.length ? (
                rows.map((n) => (
                  <tr key={n.id} className={n.read ? "hover:bg-white/5" : "bg-[hsl(var(--gold))/0.06] hover:bg-[hsl(var(--gold))/0.09]"}>
                    <td className="px-5 py-3 text-muted-foreground">{typeLabel(n.type)}</td>
                    <td className="px-5 py-3">
                      <div className="font-medium">{(n.title ?? "").trim() || "Notification"}</div>
                      <div className="text-xs text-muted-foreground">{n.read ? "Read" : "Unread"}</div>
                    </td>
                    <td className="px-5 py-3 text-muted-foreground">
                      <div className="line-clamp-2">{(n.body ?? "").trim()}</div>
                    </td>
                    <td className="px-5 py-3 text-muted-foreground">
                      {Intl.DateTimeFormat("en", { dateStyle: "medium", timeStyle: "short" }).format(new Date(n.created_at))}
                    </td>
                    <td className="px-5 py-3 text-right">
                      <form action={markRead}>
                        <input type="hidden" name="id" value={n.id} />
                        <input type="hidden" name="read" value={String(!n.read)} />
                        <Button type="submit" size="sm" variant="secondary">
                          {n.read ? "Mark unread" : "Mark read"}
                        </Button>
                      </form>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={5} className="px-5 py-10 text-center text-muted-foreground">
                    No notifications.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </LuxuryCard>
    </div>
  );
}

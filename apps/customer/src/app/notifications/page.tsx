import { redirect } from "next/navigation";

import { createAppSupabaseServerClient } from "@/lib/supabase";
import { CustomerBottomNav } from "@/components/customer-bottom-nav";

export const dynamic = "force-dynamic";

function formatDate(value: string) {
  const date = new Date(value);
  return Intl.DateTimeFormat("en", { dateStyle: "medium", timeStyle: "short" }).format(date);
}

export default async function NotificationsPage() {
  const supabase = await createAppSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) redirect("/auth/sign-in?next=/notifications");

  const { data: rows } = await supabase
    .from("notifications")
    .select("id, title, body, read, created_at")
    .eq("profile_id", user.id)
    .order("created_at", { ascending: false })
    .limit(80);

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 py-6 pb-28 text-white">
      <div className="text-lg font-bold">Notifications</div>
      {rows?.length ? (
        <div className="flex flex-col gap-3">
          {rows.map((n) => (
            <div key={n.id} className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-4">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0 flex-1">
                  <div className="truncate text-sm font-extrabold">{n.title || "Notification"}</div>
                  <div className="mt-1 text-sm font-semibold text-[#9E9E9E]">{n.body}</div>
                  <div className="mt-2 text-[12px] font-semibold text-[#9E9E9E]">{formatDate(n.created_at)}</div>
                </div>
                {!n.read ? <span className="mt-1 h-2.5 w-2.5 rounded-full bg-[hsl(var(--gold))]" /> : null}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-6">
          <div className="text-sm font-extrabold">No notifications</div>
          <div className="pt-1 text-sm font-semibold text-[#9E9E9E]">You’re all caught up.</div>
        </div>
      )}
      <CustomerBottomNav />
    </main>
  );
}


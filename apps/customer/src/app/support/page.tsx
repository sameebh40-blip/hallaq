import Link from "next/link";
import { redirect } from "next/navigation";

import { createAppSupabaseServerClient } from "@/lib/supabase";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";

export const dynamic = "force-dynamic";

async function createSupportTicket(formData: FormData) {
  "use server";

  const supabase = await createAppSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) redirect("/auth/sign-in?next=/support");

  const subject = String(formData.get("subject") ?? "").trim();
  const message = String(formData.get("message") ?? "").trim();
  const reason = [subject, message].filter(Boolean).join("\n\n");
  if (!reason) return;

  await supabase.from("reports").insert({
    reporter_profile_id: user.id,
    entity_type: "support",
    reason
  });
}

export default async function SupportPage() {
  const supabase = await createAppSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) redirect("/auth/sign-in?next=/support");

  const { data: rows } = await supabase
    .from("reports")
    .select("id, reason, status, created_at")
    .eq("reporter_profile_id", user.id)
    .eq("entity_type", "support")
    .order("created_at", { ascending: false })
    .limit(40);

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 py-6 pb-28 text-white">
      <div className="flex items-center justify-between">
        <Link href="/profile" className="text-sm font-semibold text-[#9E9E9E]">
          Back
        </Link>
        <div className="text-sm font-extrabold">Support</div>
        <div className="w-10" />
      </div>

      <form action={createSupportTicket} className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-4 shadow-[0_18px_44px_rgba(0,0,0,0.55)]">
        <div className="text-sm font-extrabold">New Request</div>
        <div className="pt-3 grid grid-cols-1 gap-2">
          <input name="subject" placeholder="Subject" className="h-11 rounded-[18px] border border-[#2A2A2A] bg-black/20 px-4 text-sm font-semibold text-white outline-none" />
          <textarea
            name="message"
            placeholder="Describe your issue"
            rows={5}
            className="rounded-[18px] border border-[#2A2A2A] bg-black/20 px-4 py-3 text-sm font-semibold text-white outline-none"
          />
          <button type="submit" className="mt-2 inline-flex h-12 items-center justify-center rounded-[14px] bg-[hsl(var(--gold))] px-5 text-sm font-extrabold text-black shadow-[0_18px_42px_rgba(212,175,55,0.28)]">
            Submit
          </button>
        </div>
      </form>

      {rows?.length ? (
        <div className="flex flex-col gap-3">
          {rows.map((r) => (
            <div key={r.id} className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-4 shadow-[0_18px_44px_rgba(0,0,0,0.55)]">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0 flex-1">
                  <div className="text-sm font-extrabold">Request</div>
                  <div className="pt-2 whitespace-pre-wrap text-sm font-semibold text-[#9E9E9E]">{(r.reason ?? "").trim()}</div>
                  <div className="pt-2 text-[12px] font-semibold text-[#9E9E9E]">{new Date(r.created_at).toLocaleString()}</div>
                </div>
                <div className="rounded-full border border-[#2A2A2A] bg-black/20 px-3 py-1 text-[11px] font-extrabold text-[#9E9E9E]">{r.status}</div>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="rounded-[24px] border border-[#2A2A2A] bg-[#111111] p-6">
          <div className="text-sm font-extrabold">No requests yet</div>
          <div className="pt-1 text-sm font-semibold text-[#9E9E9E]">Create a request and our team will respond.</div>
        </div>
      )}

      <CustomerBottomNav />
    </main>
  );
}


import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { getT } from "@hallaq/ui/translations-server";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong.";
  if (m.toLowerCase().includes("deposit_required")) return "Deposit payment is required before confirming this booking.";
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as an admin account.";
  }
  return m;
}

function formatDate(value: string) {
  const date = new Date(value);
  return Intl.DateTimeFormat("en", { dateStyle: "medium", timeStyle: "short" }).format(date);
}

function formatStatus(status: string) {
  const s = (status ?? "").toLowerCase();
  const base = "rounded-full border px-2.5 py-1 text-xs font-medium";
  if (s === "confirmed") return `${base} border-emerald-500/25 bg-emerald-500/10 text-emerald-200`;
  if (s === "pending") return `${base} border-amber-500/25 bg-amber-500/10 text-amber-200`;
  if (s === "in_progress") return `${base} border-sky-500/25 bg-sky-500/10 text-sky-200`;
  if (s === "rescheduled") return `${base} border-violet-500/25 bg-violet-500/10 text-violet-200`;
  if (s === "no_show") return `${base} border-orange-500/25 bg-orange-500/10 text-orange-200`;
  if (s === "completed") return `${base} border-white/10 bg-white/5 text-muted-foreground`;
  if (s === "cancelled") return `${base} border-rose-500/25 bg-rose-500/10 text-rose-200`;
  return `${base} border-white/10 bg-white/5 text-muted-foreground`;
}

function isActiveBooking(status: string) {
  return status === "pending" || status === "confirmed" || status === "in_progress" || status === "rescheduled";
}

function canStartOrFinalize(status: string) {
  return status === "confirmed" || status === "rescheduled" || status === "in_progress";
}

function cancelLabel(
  cancelledByProfileId: string | null,
  customerProfileId: string,
  barberProfileId: string | null,
  shopOwnerProfileId: string | null
) {
  const by = (cancelledByProfileId ?? "").trim();
  if (!by) return "Cancelled";
  if (by === customerProfileId) return "Cancelled by Client";
  if (barberProfileId && by === barberProfileId) return "Cancelled by Barber";
  if (shopOwnerProfileId && by === shopOwnerProfileId) return "Cancelled by Shop";
  return "Cancelled";
}

function shortId(id: string) {
  return (id ?? "").slice(0, 8);
}

export default async function AppointmentsPage({
  searchParams
}: {
  searchParams?: Promise<{ status?: string; error?: string }>;
}) {
  const t = await getT();
  const params = searchParams ? await searchParams : undefined;
  const statusFilter = (params?.status ?? "").trim();
  const error = userFacingDbError((params?.error ?? "").trim());
  const supabase = await createSupabaseServerClient();

  let query = supabase
    .from("bookings")
    .select(
      "id, customer_profile_id, start_at, end_at, status, created_at, barber_id, shop_id, service_id, deposit_required_amount, cancelled_by_profile_id, cancel_reason, cancelled_reason, profiles(full_name, email), services(name_en, name_ar, duration_minutes), barbers(profile_id, display_name), barbershops(owner_profile_id, name)"
    )
    .order("created_at", { ascending: false })
    .limit(50);

  if (statusFilter && statusFilter !== "all") query = query.eq("status", statusFilter);

  const { data: rowsRaw } = await query;
  const rows =
    (rowsRaw ?? []).map((row) => {
      const r = row as Record<string, unknown>;
      const rawProfile = r.profiles as unknown;
      const profile =
        (Array.isArray(rawProfile) ? (rawProfile[0] as Record<string, unknown> | undefined) : (rawProfile as Record<string, unknown> | null)) ??
        null;

      const rawService = r.services as unknown;
      const service =
        (Array.isArray(rawService) ? (rawService[0] as Record<string, unknown> | undefined) : (rawService as Record<string, unknown> | null)) ??
        null;

      const rawBarber = r.barbers as unknown;
      const barber =
        (Array.isArray(rawBarber) ? (rawBarber[0] as Record<string, unknown> | undefined) : (rawBarber as Record<string, unknown> | null)) ??
        null;

      const rawShop = r.barbershops as unknown;
      const shopRow =
        (Array.isArray(rawShop) ? (rawShop[0] as Record<string, unknown> | undefined) : (rawShop as Record<string, unknown> | null)) ?? null;

      return {
        id: String(r.id ?? ""),
        customer_profile_id: String(r.customer_profile_id ?? ""),
        customer_name: (profile?.full_name as string | null | undefined) ?? null,
        customer_email: (profile?.email as string | null | undefined) ?? null,
        barber_id: String(r.barber_id ?? ""),
        barber_profile_id: (barber?.profile_id as string | null | undefined) ?? null,
        barber_name: (barber?.display_name as string | null | undefined) ?? null,
        shop_id: String(r.shop_id ?? ""),
        shop_owner_profile_id: (shopRow?.owner_profile_id as string | null | undefined) ?? null,
        shop_name: (shopRow?.name as string | null | undefined) ?? null,
        service_id: String(r.service_id ?? ""),
        service_name_en: (service?.name_en as string | null | undefined) ?? null,
        service_name_ar: (service?.name_ar as string | null | undefined) ?? null,
        start_at: String(r.start_at ?? ""),
        end_at: String(r.end_at ?? ""),
        status: String(r.status ?? ""),
        created_at: String(r.created_at ?? ""),
        deposit_required_amount: (r.deposit_required_amount as number | null | undefined) ?? 0,
        cancelled_by_profile_id: (r.cancelled_by_profile_id as string | null | undefined) ?? null,
        cancel_reason: (r.cancel_reason as string | null | undefined) ?? null,
        cancelled_reason: (r.cancelled_reason as string | null | undefined) ?? null
      };
    }) ?? [];

  const bookingIds = (rows ?? []).map((r) => r.id).filter(Boolean);
  const { data: depositPayments } = bookingIds.length
    ? await supabase
        .from("payments")
        .select("id, booking_id, status, amount, created_at")
        .in("booking_id", bookingIds)
        .eq("purpose", "deposit")
        .order("created_at", { ascending: false })
        .limit(5000)
    : { data: [] as Array<{ id: string; booking_id: string; status: string; amount: number; created_at: string }> };

  const depositPaidByBookingId = new Map<string, boolean>();
  for (const p of depositPayments ?? []) {
    if (!p?.booking_id) continue;
    if (p.status === "succeeded") depositPaidByBookingId.set(p.booking_id, true);
  }

  async function setStatus(formData: FormData) {
    "use server";

    const id = String(formData.get("id") ?? "");
    const status = String(formData.get("status") ?? "");
    if (!["pending", "confirmed", "in_progress", "no_show", "cancelled", "completed"].includes(status)) redirect("/appointments");
    const cancelReason = String(formData.get("cancel_reason") ?? "").trim();

    const supabase = await createSupabaseServerClient();
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;

    if (status === "cancelled") {
      const { error } = await supabase.rpc("cancel_booking", { booking_id: id, reason: cancelReason || null });
      if (error) redirect(`/appointments?error=${encodeURIComponent(error.message)}`);
    }
    if (status === "confirmed") {
      const { error } = await supabase.rpc("confirm_booking", { booking_id: id });
      if (error) redirect(`/appointments?error=${encodeURIComponent(error.message)}`);
    }
    if (status === "in_progress") {
      const { error } = await supabase.rpc("start_booking", { booking_id: id });
      if (error) redirect(`/appointments?error=${encodeURIComponent(error.message)}`);
    }
    if (status === "no_show") {
      const { error } = await supabase.rpc("mark_booking_no_show", { booking_id: id });
      if (error) redirect(`/appointments?error=${encodeURIComponent(error.message)}`);
    }
    if (status === "completed") {
      const { error } = await supabase.rpc("complete_booking", { booking_id: id });
      if (error) redirect(`/appointments?error=${encodeURIComponent(error.message)}`);
    }
    if (!["cancelled", "confirmed", "in_progress", "no_show", "completed"].includes(status)) redirect("/appointments");

    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "booking_status_changed",
      entity_type: "booking",
      entity_id: id,
      meta: { status }
    });
    if (logError) redirect(`/appointments?error=${encodeURIComponent(logError.message)}`);

    redirect("/appointments");
  }

  async function markDepositPaid(formData: FormData) {
    "use server";

    const paymentId = String(formData.get("payment_id") ?? "");
    if (!paymentId) redirect("/appointments");

    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.rpc("mark_payment_succeeded", { payment_id: paymentId });
    if (error) redirect(`/appointments?error=${encodeURIComponent(error.message)}`);
    const { data: u } = await supabase.auth.getUser();
    const actorId = u.user?.id ?? null;
    const { error: logError } = await supabase.from("admin_activity_logs").insert({
      actor_profile_id: actorId,
      action: "payment_marked_succeeded",
      entity_type: "payment",
      entity_id: paymentId,
      meta: { purpose: "deposit" }
    });
    if (logError) redirect(`/appointments?error=${encodeURIComponent(logError.message)}`);
    redirect("/appointments");
  }

  async function sendReminders() {
    "use server";
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.rpc("send_booking_reminders");
    if (error) redirect(`/appointments?error=${encodeURIComponent(error.message)}`);
    redirect("/appointments");
  }

  return (
    <PageFrame
      title={t("admin.nav.appointments")}
      subtitle="Monitor bookings, statuses, and audit trail."
    >
      {params?.error ? (
        <LuxuryCard className="mb-4 border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-200">{error}</LuxuryCard>
      ) : null}
      <LuxuryCard className="p-4">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div className="text-sm text-muted-foreground">Tip: filter by status to focus on pending/confirmed bookings.</div>
          <div className="flex flex-wrap items-center gap-2">
            <form method="get" className="flex items-center gap-2">
              <select
                name="status"
                defaultValue={statusFilter || "all"}
                className="h-9 rounded-md border border-white/10 bg-white/5 px-3 text-sm"
              >
                <option value="all">All</option>
                <option value="pending">Pending</option>
                <option value="confirmed">Confirmed</option>
                <option value="in_progress">In progress</option>
                <option value="no_show">No show</option>
                <option value="rescheduled">Rescheduled</option>
                <option value="completed">Completed</option>
                <option value="cancelled">Cancelled</option>
              </select>
              <Button type="submit" size="sm" variant="secondary">
                Filter
              </Button>
            </form>
            <form action={sendReminders}>
              <Button type="submit" size="sm" variant="ghost">
                Send 2h reminders
              </Button>
            </form>
          </div>
        </div>
      </LuxuryCard>
      <LuxuryCard className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[980px] text-sm">
            <thead className="text-xs text-muted-foreground">
              <tr className="border-b border-white/10">
                <th className="px-4 py-3 text-left font-medium">When</th>
                <th className="px-4 py-3 text-left font-medium">Status</th>
                <th className="px-4 py-3 text-left font-medium">Service</th>
                <th className="px-4 py-3 text-left font-medium">Customer</th>
                <th className="px-4 py-3 text-left font-medium">Target</th>
                <th className="px-4 py-3 text-left font-medium">Deposit</th>
                <th className="px-4 py-3 text-right font-medium">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/10">
              {rows?.length ? (
                rows.map((r) => (
                  <tr key={r.id} className="hover:bg-white/5">
                    <td className="px-4 py-3">
                      <div className="font-medium">{formatDate(r.start_at)}</div>
                      <div className="text-xs text-muted-foreground">{formatDate(r.end_at)}</div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex flex-col gap-1">
                        <span className={formatStatus(r.status)}>{r.status}</span>
                        {r.status === "cancelled" ? (
                          <div className="text-xs text-rose-200">
                            {cancelLabel(r.cancelled_by_profile_id, r.customer_profile_id, r.barber_profile_id, r.shop_owner_profile_id)}
                          </div>
                        ) : null}
                        {r.status === "cancelled" && (r.cancelled_reason ?? r.cancel_reason ?? "").trim().length > 0 ? (
                          <div className="max-w-[240px] truncate text-xs text-muted-foreground">
                            {(r.cancelled_reason ?? r.cancel_reason ?? "").trim()}
                          </div>
                        ) : null}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="font-medium">{r.service_name_en ?? "Service"}</div>
                      <div className="text-xs text-muted-foreground">{r.barber_name ?? r.shop_name ?? "—"}</div>
                    </td>
                    <td className="px-4 py-3 font-mono text-xs text-muted-foreground">
                      {(r.customer_name ?? "").trim() ? (
                        <div className="font-sans text-sm text-white/90">{r.customer_name}</div>
                      ) : null}
                      <div className="text-xs text-muted-foreground">{(r.customer_email ?? "").trim() || shortId(r.customer_profile_id)}</div>
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">
                      {r.barber_id ? (
                        <span className="font-mono text-xs">{`Barber • ${shortId(r.barber_id)}`}</span>
                      ) : (
                        <span className="font-mono text-xs">{`Shop • ${shortId(r.shop_id)}`}</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      {Number(r.deposit_required_amount ?? 0) > 0 ? (
                        (() => {
                          const payments = (depositPayments ?? []).filter((p) => p.booking_id === r.id);
                          const paid = payments.some((p) => p.status === "succeeded");
                          const latest = payments[0];
                          return (
                            <div className="flex flex-col items-start gap-2">
                              <span className={paid ? "text-emerald-200" : "text-amber-200"}>
                                {Number(r.deposit_required_amount).toFixed(3)} BHD
                              </span>
                              {paid ? (
                                <span className="text-xs text-muted-foreground">Paid</span>
                              ) : latest ? (
                                <form action={markDepositPaid}>
                                  <input type="hidden" name="payment_id" value={latest.id} />
                                  <Button type="submit" size="sm" variant="secondary">
                                    Mark paid
                                  </Button>
                                </form>
                              ) : (
                                <span className="text-xs text-muted-foreground">Pending</span>
                              )}
                            </div>
                          );
                        })()
                      ) : (
                        <span className="text-xs text-muted-foreground">—</span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-right">
                      {(() => {
                        const now = Date.now();
                        const startMs = new Date(r.start_at).getTime();
                        const canEdit = isActiveBooking(r.status) && startMs > now;
                        const depositRequired = Number(r.deposit_required_amount ?? 0) > 0;
                        const depositPaid = depositPaidByBookingId.get(r.id) ?? false;
                        const canConfirm = r.status === "pending" && (!depositRequired || depositPaid);
                        return (
                          <div className="flex flex-col items-end gap-2">
                            <div className="flex justify-end gap-2">
                              {canEdit ? (
                                <Button asChild size="sm" variant="ghost">
                                  <Link href={`/appointments/${encodeURIComponent(r.id)}/reschedule`}>
                                    Reschedule
                                  </Link>
                                </Button>
                              ) : null}
                              {canConfirm ? (
                                <form action={setStatus}>
                                  <input type="hidden" name="id" value={r.id} />
                                  <input type="hidden" name="status" value="confirmed" />
                                  <Button type="submit" size="sm" variant="secondary">
                                    Confirm
                                  </Button>
                                </form>
                              ) : null}
                              {r.status === "confirmed" || r.status === "rescheduled" ? (
                                <form action={setStatus}>
                                  <input type="hidden" name="id" value={r.id} />
                                  <input type="hidden" name="status" value="in_progress" />
                                  <Button type="submit" size="sm" variant="secondary">
                                    Start
                                  </Button>
                                </form>
                              ) : null}
                              {canStartOrFinalize(r.status) ? (
                                <form action={setStatus}>
                                  <input type="hidden" name="id" value={r.id} />
                                  <input type="hidden" name="status" value="completed" />
                                  <Button type="submit" size="sm">
                                    Complete
                                  </Button>
                                </form>
                              ) : null}
                              {canStartOrFinalize(r.status) ? (
                                <form action={setStatus}>
                                  <input type="hidden" name="id" value={r.id} />
                                  <input type="hidden" name="status" value="no_show" />
                                  <Button type="submit" size="sm" variant="ghost">
                                    No show
                                  </Button>
                                </form>
                              ) : null}
                              {canEdit ? (
                                <form action={setStatus}>
                                  <input type="hidden" name="id" value={r.id} />
                                  <input type="hidden" name="status" value="cancelled" />
                                  <select
                                    name="cancel_reason"
                                    defaultValue="HALLAQ cancelled"
                                    className="h-9 rounded-md border border-white/10 bg-white/5 px-2 text-xs text-muted-foreground"
                                  >
                                    <option value="HALLAQ cancelled">HALLAQ cancelled</option>
                                    <option value="Shop unavailable">Shop unavailable</option>
                                    <option value="Barber unavailable">Barber unavailable</option>
                                    <option value="Client requested">Client requested</option>
                                    <option value="Other">Other</option>
                                  </select>
                                  <Button type="submit" size="sm" variant="ghost">
                                    Cancel
                                  </Button>
                                </form>
                              ) : null}
                            </div>
                            <div className="font-mono text-[10px] text-muted-foreground">{r.id}</div>
                          </div>
                        );
                      })()}
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={7} className="px-4 py-10 text-center text-muted-foreground">
                    No bookings yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </LuxuryCard>
    </PageFrame>
  );
}

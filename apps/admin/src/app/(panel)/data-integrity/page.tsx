import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@hallaq/supabase/server";
import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

type Scan = Record<string, unknown>;

function listCount(v: unknown) {
  return Array.isArray(v) ? v.length : 0;
}

export default async function DataIntegrityPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string; fixed?: string }>;
}) {
  const sp = searchParams ? await searchParams : undefined;
  const errorMsg = (sp?.error ?? "").trim();
  const fixedMsg = (sp?.fixed ?? "").trim();

  const supabase = await createSupabaseServerClient();

  async function fixBrokenSavedItems() {
    "use server";

    const supabase = await createSupabaseServerClient();
    const { data, error } = await supabase.rpc("admin_fix_broken_saved_items", { p_limit: 500 });
    if (error) redirect(`/data-integrity?error=${encodeURIComponent(error.message)}`);

    const { data: auth } = await supabase.auth.getUser();
    const actorId = auth.user?.id ?? null;
    if (actorId) {
      await Promise.allSettled([
        supabase.from("admin_activity_logs").insert({
          actor_profile_id: actorId,
          action: "data_integrity_auto_fix",
          entity_type: "saved_items",
          entity_id: null,
          meta: { fix: "broken_saved_items", deleted: data ?? 0 }
        }),
        supabase.from("admin_audit_logs").insert({
          admin_profile_id: actorId,
          action: "data_integrity_auto_fix",
          target_type: "saved_items",
          target_id: null,
          meta: { fix: "broken_saved_items", deleted: data ?? 0 }
        })
      ]);
    }

    redirect(`/data-integrity?fixed=${encodeURIComponent(String(data ?? 0))}`);
  }

  const { data: scanRaw, error: scanError } = await supabase.rpc("admin_data_integrity_scan", { p_limit: 50 });
  const scan = (scanRaw ?? {}) as Scan;
  const { data: bookingScanRaw, error: bookingScanError } = await supabase.rpc("admin_booking_integrity_scan", { p_limit: 50 });
  const bookingScan = (bookingScanRaw ?? {}) as Scan;

  const orphanServices = scan.orphan_services;
  const servicesWithoutOwner = scan.services_without_owner;
  const productsWithoutShop = scan.products_without_shop;
  const reelsWithoutMedia = scan.reels_without_media;
  const brokenSavedItems = scan.broken_saved_items;
  const duplicateEmails = scan.duplicate_emails;
  const duplicatePhones = scan.duplicate_phone_numbers;
  const shopsMissingBranches = scan.shops_missing_branches;
  const barbersMissingBranch = scan.barbers_missing_branch;
  const ownershipRoleMismatches = scan.ownership_role_mismatches;
  const ownerMembershipMismatches = scan.owner_membership_mismatches;
  const staleOwnerMemberships = scan.stale_owner_memberships;
  const barberMembershipMismatches = scan.barber_membership_mismatches;
  const bookingsMissingBranch = bookingScan.bookings_missing_branch;
  const bookingStatusTimestampMismatches = bookingScan.booking_status_timestamp_mismatches;
  const bookingPaymentStateMismatches = bookingScan.booking_payment_state_mismatches;

  return (
    <PageFrame
      title="Data Integrity Scanner"
      subtitle="Detects broken relationships, duplicates, and invalid references. All results come from live Supabase data."
      actions={
        <>
          <Button asChild size="sm" variant="secondary">
            <Link href="/data-integrity/report">Export Report</Link>
          </Button>
          <form action={fixBrokenSavedItems}>
            <Button type="submit" size="sm" variant="ghost">
              Auto Fix Saved Items
            </Button>
          </form>
        </>
      }
    >
      {errorMsg || scanError || bookingScanError ? (
        <LuxuryCard className="mb-4 border border-rose-500/25 bg-rose-500/10 p-4 text-sm text-rose-200">
          {(errorMsg || scanError?.message || bookingScanError?.message || "Scan failed.").trim()}
        </LuxuryCard>
      ) : null}
      {fixedMsg ? (
        <LuxuryCard className="mb-4 border border-emerald-500/25 bg-emerald-500/10 p-4 text-sm text-emerald-200">
          Auto fix completed: deleted {fixedMsg} broken saved items.
        </LuxuryCard>
      ) : null}

      <div className="grid grid-cols-1 gap-4">
        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Orphan Services</div>
            <div className="text-xs text-muted-foreground">services with no shop_id and no barber_id</div>
            <div className="text-sm">{listCount(orphanServices).toLocaleString()}</div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Services Missing Owner Fields</div>
            <div className="text-xs text-muted-foreground">legacy owner_type/owner_id not set</div>
            <div className="text-sm">{listCount(servicesWithoutOwner).toLocaleString()}</div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Products Without Shop</div>
            <div className="text-sm">{listCount(productsWithoutShop).toLocaleString()}</div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Reels Without Media</div>
            <div className="text-sm">{listCount(reelsWithoutMedia).toLocaleString()}</div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Broken Saved Items</div>
            <div className="text-xs text-muted-foreground">saved_items referencing missing entities</div>
            <div className="text-sm">{listCount(brokenSavedItems).toLocaleString()}</div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Duplicate Emails</div>
            <div className="text-sm">{listCount(duplicateEmails).toLocaleString()}</div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Duplicate Phone Numbers</div>
            <div className="text-sm">{listCount(duplicatePhones).toLocaleString()}</div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Shops Missing Branches</div>
            <div className="text-xs text-muted-foreground">shops with no default branch row</div>
            <div className="text-sm">{listCount(shopsMissingBranches).toLocaleString()}</div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Barbers Missing Branch</div>
            <div className="text-xs text-muted-foreground">barbers linked to a shop but missing branch_id</div>
            <div className="text-sm">{listCount(barbersMissingBranch).toLocaleString()}</div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Ownership Role Mismatches</div>
            <div className="text-xs text-muted-foreground">shop owners whose profile role is not shop_owner</div>
            <div className="text-sm">{listCount(ownershipRoleMismatches).toLocaleString()}</div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Owner Membership Gaps</div>
            <div className="text-xs text-muted-foreground">shops missing the expected owner membership row</div>
            <div className="text-sm">{listCount(ownerMembershipMismatches).toLocaleString()}</div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Stale Owner Memberships</div>
            <div className="text-xs text-muted-foreground">owner memberships pointing to the wrong profile</div>
            <div className="text-sm">{listCount(staleOwnerMemberships).toLocaleString()}</div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Barber Membership Gaps</div>
            <div className="text-xs text-muted-foreground">barbers missing the matching shop_memberships row</div>
            <div className="text-sm">{listCount(barberMembershipMismatches).toLocaleString()}</div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Bookings Missing Branch</div>
            <div className="text-xs text-muted-foreground">bookings linked to a shop but missing branch_id</div>
            <div className="text-sm">{listCount(bookingsMissingBranch).toLocaleString()}</div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Booking Status Timestamp Mismatches</div>
            <div className="text-xs text-muted-foreground">statuses missing their expected started/completed/cancelled/no-show timestamps</div>
            <div className="text-sm">{listCount(bookingStatusTimestampMismatches).toLocaleString()}</div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="flex flex-col gap-2">
            <div className="text-sm font-semibold">Booking Payment State Mismatches</div>
            <div className="text-xs text-muted-foreground">booking payment_status out of sync with deposit payments and refunds</div>
            <div className="text-sm">{listCount(bookingPaymentStateMismatches).toLocaleString()}</div>
          </div>
        </LuxuryCard>

        <LuxuryCard className="border border-white/10 bg-white/5 p-4">
          <div className="text-sm font-semibold">Review / Raw Output</div>
          <pre className="mt-3 max-h-[520px] overflow-auto rounded-lg border border-white/10 bg-black/30 p-3 text-[11px] text-muted-foreground">
            {JSON.stringify({ ...scan, booking_scan: bookingScan }, null, 2)}
          </pre>
        </LuxuryCard>
      </div>
    </PageFrame>
  );
}

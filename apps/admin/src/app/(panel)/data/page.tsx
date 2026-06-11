import Link from "next/link";

import { Button } from "@hallaq/ui/button";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { PageFrame } from "@/components/page-frame";

export const dynamic = "force-dynamic";

const tables = [
  { label: "system_logs", table: "system_logs" },
  { label: "admin_audit_logs", table: "admin_audit_logs" },
  { label: "admin_activity_logs", table: "admin_activity_logs" },
  { label: "audit_events", table: "audit_events" },
  { label: "profiles", table: "profiles" },
  { label: "customers", table: "customers" },
  { label: "barbershops", table: "barbershops" },
  { label: "barbers", table: "barbers" },
  { label: "services", table: "services" },
  { label: "products", table: "products" },
  { label: "orders", table: "orders" },
  { label: "bookings", table: "bookings" },
  { label: "reels", table: "reels" },
  { label: "portfolio_items", table: "portfolio_items" },
  { label: "reviews", table: "reviews" },
  { label: "notifications", table: "notifications" },
  { label: "follows", table: "follows" },
  { label: "reel_likes", table: "reel_likes" },
  { label: "reel_comments", table: "reel_comments" },
  { label: "offers", table: "offers" },
  { label: "awards", table: "awards" },
  { label: "gift_cards", table: "gift_cards" },
  { label: "membership_levels", table: "membership_levels" },
  { label: "waitlist_entries", table: "waitlist_entries" }
];

export default async function DataIndexPage() {
  return (
    <PageFrame
      title="Data Explorer"
      subtitle="Admin-only table viewer (search, filter, export, edit, delete)."
      actions={
        <Button asChild variant="secondary" size="sm">
          <Link href="/system-health">System Health</Link>
        </Button>
      }
    >
      <LuxuryCard className="p-5">
        <div className="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-3">
          {tables.map((t) => (
            <Link
              key={t.table}
              href={`/data/${t.table}`}
              className="rounded-xl border border-white/10 bg-white/5 p-4 transition hover:border-white/20 hover:bg-white/10"
            >
              <div className="text-sm font-semibold">{t.label}</div>
              <div className="pt-1 text-xs text-muted-foreground break-all">public.{t.table}</div>
            </Link>
          ))}
        </div>
      </LuxuryCard>
    </PageFrame>
  );
}


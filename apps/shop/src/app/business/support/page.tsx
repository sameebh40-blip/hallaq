import Link from "next/link";

import { LuxuryCard } from "@hallaq/ui/luxury-card";
import { Button } from "@hallaq/ui/button";
import { getMyProfile } from "@hallaq/supabase/profile";

import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

export default async function BusinessSupportPage() {
  const supabase = await createAppSupabaseServerClient();
  const { data: auth } = await supabase.auth.getUser();
  const profile = await getMyProfile(supabase);

  let setting: boolean | null = null;
  try {
    const { data } = await supabase.rpc("get_setting_bool", { p_key: "maintenance_mode" });
    setting = (data as boolean | null) ?? null;
  } catch {}

  return (
    <div className="grid gap-4">
      <LuxuryCard className="p-5">
        <div className="text-base font-semibold">Support</div>
        <div className="pt-2 text-sm text-muted-foreground">
          If you need help with bookings, barbers, services, products, or payouts, contact support and include your shop name and the time of the issue.
        </div>
        <div className="mt-4 grid gap-2 text-sm">
          <div className="flex items-center justify-between gap-3 rounded-xl border border-white/10 bg-white/5 px-4 py-3">
            <div className="text-muted-foreground">Signed in as</div>
            <div className="font-medium">{auth.user?.email ?? profile?.id ?? "-"}</div>
          </div>
          <div className="flex items-center justify-between gap-3 rounded-xl border border-white/10 bg-white/5 px-4 py-3">
            <div className="text-muted-foreground">System status</div>
            <div className="font-medium">{setting === true ? "Maintenance mode" : "Operational"}</div>
          </div>
        </div>
        <div className="mt-4 flex flex-wrap gap-2">
          <Button asChild variant="secondary">
            <Link href="/business/notifications">View notifications</Link>
          </Button>
          <Button asChild variant="ghost">
            <Link href="/business/reports">Open reports</Link>
          </Button>
        </div>
      </LuxuryCard>
    </div>
  );
}

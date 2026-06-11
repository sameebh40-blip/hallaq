import { redirect } from "next/navigation";

import { BookingFlow } from "@/app/booking/new/booking-flow";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

function safeId(raw: string | null | undefined) {
  const v = String(raw ?? "").trim();
  return v || null;
}

function withParams(path: string, values: Record<string, string | null | undefined>) {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(values)) {
    if (value) search.set(key, value);
  }
  const query = search.toString();
  return query ? `${path}?${query}` : path;
}

export default async function NewBookingWebPage({
  searchParams
}: {
  searchParams?: Promise<{
    shopId?: string;
    barberId?: string;
    serviceId?: string;
    reelId?: string;
    offerId?: string;
    sourcePostId?: string;
    postId?: string;
    source?: string;
  }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const shopId = safeId(params?.shopId);
  const barberId = safeId(params?.barberId);
  const serviceId = safeId(params?.serviceId);
  const reelId = safeId(params?.reelId);
  const offerId = safeId(params?.offerId);
  const sourcePostId = safeId(params?.sourcePostId) ?? safeId(params?.postId);
  const source = (params?.source ?? "").trim() || null;

  const supabase = await createAppSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/sign-in?next=${encodeURIComponent("/booking/new")}`);

  const backHref = barberId
    ? withParams(`/barber/${encodeURIComponent(barberId)}`, {
        source,
        reelId,
        tab: offerId ? "offers" : serviceId ? "services" : undefined,
        serviceId,
        offerId,
      })
    : shopId
      ? withParams(`/shop/${encodeURIComponent(shopId)}`, {
          source,
          reelId,
          barberId,
          tab: offerId ? "offers" : serviceId ? "services" : barberId ? "barbers" : undefined,
          serviceId,
          offerId,
        })
      : "/home";
  return (
    <>
      <BookingFlow
        initial={{
          barberId,
          shopId,
          serviceId,
          reelId,
          offerId,
          sourcePostId,
          source
        }}
        backHref={backHref}
      />
    </>
  );
}

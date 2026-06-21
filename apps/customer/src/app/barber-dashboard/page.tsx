import { redirect } from "next/navigation";
import Link from "next/link";
import { randomUUID } from "crypto";

import { createAppSupabaseServerClient } from "@/lib/supabase";
import { signedOrUrl } from "@hallaq/supabase/storage";
import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { RealtimeRefresh } from "@/components/realtime-refresh";
import { SafeImage } from "@/components/safe-image";

export const dynamic = "force-dynamic";

type BarberRow = {
  id: string;
  profile_id: string;
  display_name: string | null;
  bio: string | null;
  area: string | null;
  avatar_url: string | null;
  avatar_path: string | null;
  cover_url: string | null;
  cover_path: string | null;
  shop_id: string | null;
};

function formatDateTime(value: string) {
  const date = new Date(value);
  return Intl.DateTimeFormat("en", { dateStyle: "medium", timeStyle: "short" }).format(date);
}

function safeTab(raw: string | null | undefined) {
  const v = String(raw ?? "").trim();
  if (v === "bookings" || v === "portfolio" || v === "reviews" || v === "profile") return v;
  return "bookings";
}

export default async function BarberDashboardWebPage({
  searchParams
}: {
  searchParams?: Promise<{ tab?: string; error?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const tab = safeTab(params?.tab);
  const error = (params?.error ?? "").trim() || null;

  const supabase = await createAppSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) redirect("/auth/sign-in?next=/barber-dashboard");

  const { data: barber } = (await supabase
    .from("barbers")
    .select("id, profile_id, display_name, bio, area, avatar_url, avatar_path, cover_url, cover_path, shop_id")
    .eq("profile_id", user.id)
    .maybeSingle()) as unknown as { data: BarberRow | null };

  if (!barber) {
    return (
      <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 px-4 py-6">
        <div className="text-lg font-semibold text-[#111111]">Barber dashboard</div>
        <LuxuryCard className="bg-white p-6">
          <div className="text-sm font-semibold text-[#111111]">No barber profile linked</div>
          <div className="pt-1 text-sm text-muted-foreground">
            This account is marked as a barber, but no barber record is linked to it.
          </div>
          <div className="pt-4">
            <form action="/auth/sign-out" method="post">
              <Button type="submit" variant="ghost" className="w-full">
                Logout
              </Button>
            </form>
          </div>
        </LuxuryCard>
      </main>
    );
  }

  const avatarUrl = (await signedOrUrl(supabase, "barber-images", barber.avatar_path ?? barber.avatar_url)) ?? null;
  const coverUrl = (await signedOrUrl(supabase, "barber-images", barber.cover_path ?? barber.cover_url)) ?? null;

  async function updateBookingStatus(formData: FormData) {
    "use server";
    const bookingId = String(formData.get("booking_id") ?? "").trim();
    const status = String(formData.get("status") ?? "").trim();
    if (!bookingId) redirect("/barber-dashboard");
    if (!["pending", "confirmed", "in_progress", "no_show", "completed", "cancelled"].includes(status))
      redirect("/barber-dashboard");

    const supabase = await createAppSupabaseServerClient();
    if (status === "confirmed") {
      const { error } = await supabase.rpc("confirm_booking", { booking_id: bookingId });
      if (error) redirect(`/barber-dashboard?tab=bookings&error=${encodeURIComponent(error.message)}`);
      redirect("/barber-dashboard?tab=bookings");
    }
    if (status === "in_progress") {
      const { error } = await supabase.rpc("start_booking", { booking_id: bookingId });
      if (error) redirect(`/barber-dashboard?tab=bookings&error=${encodeURIComponent(error.message)}`);
      redirect("/barber-dashboard?tab=bookings");
    }
    if (status === "no_show") {
      const { error } = await supabase.rpc("mark_booking_no_show", { booking_id: bookingId });
      if (error) redirect(`/barber-dashboard?tab=bookings&error=${encodeURIComponent(error.message)}`);
      redirect("/barber-dashboard?tab=bookings");
    }
    if (status === "cancelled") {
      const { error } = await supabase.rpc("cancel_booking", { booking_id: bookingId, reason: "Cancelled by barber" });
      if (error) redirect(`/barber-dashboard?tab=bookings&error=${encodeURIComponent(error.message)}`);
      redirect("/barber-dashboard?tab=bookings");
    }
    if (status === "completed") {
      const { error } = await supabase.rpc("complete_booking", { booking_id: bookingId });
      if (error) redirect(`/barber-dashboard?tab=bookings&error=${encodeURIComponent(error.message)}`);
      redirect("/barber-dashboard?tab=bookings");
    }
    redirect("/barber-dashboard?tab=bookings");
  }

  async function saveProfile(formData: FormData) {
    "use server";
    const displayName = String(formData.get("display_name") ?? "").trim();
    const bio = String(formData.get("bio") ?? "").trim();
    const area = String(formData.get("area") ?? "").trim();
    const avatarFile = formData.get("avatar_file");
    const coverFile = formData.get("cover_file");

    if (!displayName) redirect("/barber-dashboard?tab=profile");

    const supabase = await createAppSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    if (!user) redirect("/auth/sign-in?next=/barber-dashboard");

    const { data: barber } = (await supabase
      .from("barbers")
      .select("id")
      .eq("profile_id", user.id)
      .maybeSingle()) as unknown as { data: { id: string } | null };
    if (!barber) redirect("/barber-dashboard?tab=profile");

    const updates: Record<string, string | null> = {
      display_name: displayName,
      bio: bio || null,
      area: area || null
    };

    const uploadImage = async (file: File, kind: "avatar" | "cover") => {
      const ext = (file.name.split(".").pop() ?? "jpg").toLowerCase();
      const objectPath = `barbers/${barber.id}/${kind}-${randomUUID()}.${ext}`;
      const { error: uploadError } = await supabase.storage.from("barber-images").upload(objectPath, file, {
        contentType: file.type || undefined,
        upsert: false
      });
      if (uploadError) throw new Error(uploadError.message);
      return objectPath;
    };

    try {
      if (avatarFile instanceof File && avatarFile.size > 0) {
        updates.avatar_path = await uploadImage(avatarFile, "avatar");
        updates.avatar_url = null;
      }
      if (coverFile instanceof File && coverFile.size > 0) {
        updates.cover_path = await uploadImage(coverFile, "cover");
        updates.cover_url = null;
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Failed to upload images.";
      redirect(`/barber-dashboard?tab=profile&error=${encodeURIComponent(msg)}`);
    }

    const { error } = await supabase.from("barbers").update(updates).eq("id", barber.id);
    if (error) redirect(`/barber-dashboard?tab=profile&error=${encodeURIComponent(error.message)}`);
    redirect("/barber-dashboard?tab=profile");
  }

  async function uploadPortfolio(formData: FormData) {
    "use server";
    const caption = String(formData.get("caption") ?? "").trim();
    const file = formData.get("file");

    if (!(file instanceof File) || file.size === 0) redirect("/barber-dashboard?tab=portfolio");
    if (!(file.type ?? "").startsWith("image/")) {
      redirect(`/barber-dashboard?tab=portfolio&error=${encodeURIComponent("Only images are supported.")}`);
    }

    const supabase = await createAppSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    if (!user) redirect("/auth/sign-in?next=/barber-dashboard");

    const { data: barber } = (await supabase
      .from("barbers")
      .select("id")
      .eq("profile_id", user.id)
      .maybeSingle()) as unknown as { data: { id: string } | null };
    if (!barber) redirect("/barber-dashboard?tab=portfolio");

    const ext = file.name.includes(".") ? file.name.split(".").pop() : undefined;
    const safeExt = ext ? `.${ext.toLowerCase()}` : "";
    const objectPath = `barbers/${barber.id}/${randomUUID()}${safeExt}`;

    const { error: uploadError } = await supabase.storage
      .from("portfolio")
      .upload(objectPath, file, { contentType: file.type || "image/jpeg", upsert: true });
    if (uploadError) redirect(`/barber-dashboard?tab=portfolio&error=${encodeURIComponent(uploadError.message)}`);

    const { error: insertError } = await supabase.from("portfolio_items").insert({
      owner_type: "barber",
      owner_id: barber.id,
      media_type: "image",
      media_path: objectPath,
      media_url: objectPath,
      image_url: objectPath,
      caption: caption || null,
      status: "approved",
      approved_by: user.id,
      approved_at: new Date().toISOString()
    });

    if (insertError) redirect(`/barber-dashboard?tab=portfolio&error=${encodeURIComponent(insertError.message)}`);
    redirect("/barber-dashboard?tab=portfolio");
  }

  async function replyToReview(formData: FormData) {
    "use server";

    const reviewId = String(formData.get("review_id") ?? "").trim();
    const replyText = String(formData.get("reply_text") ?? "").trim();
    if (!reviewId) redirect("/barber-dashboard?tab=reviews");

    const supabase = await createAppSupabaseServerClient();
    const {
      data: { user }
    } = await supabase.auth.getUser();
    if (!user) redirect("/auth/sign-in?next=/barber-dashboard");

    const { data: barber } = (await supabase
      .from("barbers")
      .select("id")
      .eq("profile_id", user.id)
      .maybeSingle()) as unknown as { data: { id: string } | null };
    if (!barber) redirect("/barber-dashboard?tab=reviews");

    const { error } = await supabase
      .from("reviews")
      .update({ reply_text: replyText || null })
      .eq("id", reviewId)
      .eq("target_type", "barber")
      .eq("target_id", barber.id);
    if (error) redirect(`/barber-dashboard?tab=reviews&error=${encodeURIComponent(error.message)}`);
    redirect("/barber-dashboard?tab=reviews");
  }

  const tabHref = (nextTab: string) => `/barber-dashboard?tab=${encodeURIComponent(nextTab)}`;

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 px-4 py-6 pb-12">
      <RealtimeRefresh
        subscriptions={[
          { table: "bookings", filter: `barber_id=eq.${barber.id}` },
          { table: "notifications", filter: `profile_id=eq.${barber.profile_id}` },
          { table: "barbers", filter: `id=eq.${barber.id}` }
        ]}
      />
      <div className="text-lg font-semibold text-[#111111]">Barber dashboard</div>

      <LuxuryCard className="bg-white p-4">
        <div className="flex items-center gap-3">
          <div className="h-14 w-14 overflow-hidden rounded-2xl border bg-secondary">
            <SafeImage src={avatarUrl} fallbackKey="default_barber_avatar" alt="" className="h-full w-full object-cover" />
          </div>
          <div className="flex flex-1 flex-col">
            <div className="text-sm font-semibold text-[#111111]">{barber.display_name ?? "Barber"}</div>
            <div className="pt-1 text-xs text-muted-foreground">Manage bookings, photos, and profile details.</div>
          </div>
          <Button asChild size="sm" variant="secondary" className="rounded-2xl">
            <Link href={`/barber/${encodeURIComponent(barber.id)}`}>View profile</Link>
          </Button>
        </div>
      </LuxuryCard>

      <div className="grid grid-cols-4 items-center justify-between gap-2 rounded-2xl bg-secondary/60 p-1">
        <Link
          href={tabHref("bookings")}
          className={`flex-1 rounded-2xl px-3 py-2 text-center text-xs font-semibold ${tab === "bookings" ? "bg-white text-[#111111] shadow-soft" : "text-muted-foreground"}`}
        >
          Bookings
        </Link>
        <Link
          href={tabHref("portfolio")}
          className={`flex-1 rounded-2xl px-3 py-2 text-center text-xs font-semibold ${tab === "portfolio" ? "bg-white text-[#111111] shadow-soft" : "text-muted-foreground"}`}
        >
          Portfolio
        </Link>
        <Link
          href={tabHref("reviews")}
          className={`flex-1 rounded-2xl px-3 py-2 text-center text-xs font-semibold ${tab === "reviews" ? "bg-white text-[#111111] shadow-soft" : "text-muted-foreground"}`}
        >
          Reviews
        </Link>
        <Link
          href={tabHref("profile")}
          className={`flex-1 rounded-2xl px-3 py-2 text-center text-xs font-semibold ${tab === "profile" ? "bg-white text-[#111111] shadow-soft" : "text-muted-foreground"}`}
        >
          Profile
        </Link>
      </div>

      {error ? (
        <div className="rounded-2xl border border-rose-500/20 bg-rose-500/10 px-4 py-3 text-sm text-rose-700">{error}</div>
      ) : null}

      {tab === "bookings" ? (
        <BookingsPanel barberId={barber.id} shopId={barber.shop_id} updateBookingStatus={updateBookingStatus} />
      ) : null}

      {tab === "portfolio" ? (
        <PortfolioPanel barberId={barber.id} uploadPortfolio={uploadPortfolio} />
      ) : null}

      {tab === "reviews" ? (
        <ReviewsPanel barberId={barber.id} replyToReview={replyToReview} />
      ) : null}

      {tab === "profile" ? (
        <LuxuryCard className="bg-white p-5">
          <form action={saveProfile} className="grid gap-4" encType="multipart/form-data">
            <div className="grid gap-2">
              <Label>Cover</Label>
              <div className="aspect-[16/9] overflow-hidden rounded-2xl bg-secondary">
                <SafeImage src={coverUrl} fallbackKey="default_barber_cover" alt="" className="h-full w-full object-cover" />
              </div>
              <Input name="cover_file" type="file" accept="image/*" />
            </div>
            <div className="grid gap-2">
              <Label>Avatar</Label>
              <div className="h-16 w-16 overflow-hidden rounded-2xl border bg-secondary">
                <SafeImage src={avatarUrl} fallbackKey="default_barber_avatar" alt="" className="h-full w-full object-cover" />
              </div>
              <Input name="avatar_file" type="file" accept="image/*" />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="display_name">Display name</Label>
              <Input id="display_name" name="display_name" defaultValue={barber.display_name ?? ""} required />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="bio">Bio</Label>
              <Input id="bio" name="bio" defaultValue={barber.bio ?? ""} />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="area">Area</Label>
              <Input id="area" name="area" defaultValue={barber.area ?? ""} />
            </div>
            <Button type="submit" className="w-full rounded-2xl">
              Save
            </Button>
          </form>
        </LuxuryCard>
      ) : null}

      <form action="/auth/sign-out" method="post" className="pt-2">
        <Button type="submit" variant="ghost" className="w-full">
          Logout
        </Button>
      </form>
    </main>
  );
}

async function ReviewsPanel({
  barberId,
  replyToReview
}: {
  barberId: string;
  replyToReview: (formData: FormData) => Promise<void>;
}) {
  const supabase = await createAppSupabaseServerClient();
  const { data: rows } = await supabase
    .from("reviews")
    .select("id, rating, comment, text, reply_text, replied_at, created_at, is_verified, profiles(full_name)")
    .eq("target_type", "barber")
    .eq("target_id", barberId)
    .eq("status", "approved")
    .order("created_at", { ascending: false })
    .limit(100);

  const list = (Array.isArray(rows) ? rows : []).map((row) => {
    const r = row as Record<string, unknown>;
    const rawProfile = r.profiles as unknown;
    const profile =
      (Array.isArray(rawProfile) ? (rawProfile[0] as Record<string, unknown> | undefined) : (rawProfile as Record<string, unknown> | null)) ??
      null;
    return {
      id: String(r.id ?? ""),
      rating: Number(r.rating ?? 0),
      text: String((r.comment ?? r.text ?? "") as string).trim(),
      reply_text: String((r.reply_text ?? "") as string),
      created_at: String(r.created_at ?? ""),
      is_verified: Boolean(r.is_verified ?? false),
      customerName: (profile?.full_name as string | null | undefined) ?? null
    };
  });

  return (
    <div className="flex flex-col gap-3">
      {list.length ? (
        list.map((r) => (
          <LuxuryCard key={r.id} className="bg-white p-5">
            <div className="flex items-start justify-between gap-3">
              <div className="flex flex-col gap-1">
                <div className="text-sm font-semibold text-[#111111]">{r.customerName ?? "Customer"}</div>
                <div className="text-xs text-muted-foreground">
                  {new Date(r.created_at).toLocaleDateString()} • {r.rating.toFixed(0)}/5 {r.is_verified ? "• Verified" : ""}
                </div>
              </div>
              <div className="rounded-full bg-black/5 px-3 py-2 text-[11px] font-semibold text-[#111111]">Reply</div>
            </div>
            {r.text ? <div className="pt-3 text-sm text-muted-foreground">{r.text}</div> : null}
            <form action={replyToReview} className="mt-4 grid gap-2">
              <input type="hidden" name="review_id" value={r.id} />
              <Label>Reply</Label>
              <Input name="reply_text" defaultValue={r.reply_text} placeholder="Thank you for your review..." />
              <Button type="submit" className="w-full rounded-2xl">
                Save reply
              </Button>
            </form>
          </LuxuryCard>
        ))
      ) : (
        <LuxuryCard className="bg-white p-6">
          <div className="text-sm font-semibold text-[#111111]">No reviews yet</div>
          <div className="pt-1 text-sm text-muted-foreground">Replies will appear under reviews in the customer app.</div>
        </LuxuryCard>
      )}
    </div>
  );
}

async function BookingsPanel({
  barberId,
  shopId,
  updateBookingStatus
}: {
  barberId: string;
  shopId: string | null;
  updateBookingStatus: (formData: FormData) => Promise<void>;
}) {
  const supabase = await createAppSupabaseServerClient();
  // Show bookings assigned to this barber OR "any staff" bookings (barber_id=null) for the same shop
  let query = supabase
    .from("bookings")
    .select("id, start_at, end_at, status, customer_profile_id, profiles(full_name), services(name_en, name_ar)");

  if (shopId) {
    query = query.eq("shop_id", shopId).or(`barber_id.eq.${barberId},barber_id.is.null`);
  } else {
    query = query.eq("barber_id", barberId);
  }

  const { data: rows } = await query
    .order("start_at", { ascending: false })
    .limit(60);

  const list = (Array.isArray(rows) ? rows : []).map((row) => {
    const r = row as Record<string, unknown>;
    const rawProfile = r.profiles as unknown;
    const profile =
      (Array.isArray(rawProfile) ? (rawProfile[0] as Record<string, unknown> | undefined) : (rawProfile as Record<string, unknown> | null)) ??
      null;

    const rawService = r.services as unknown;
    const service =
      (Array.isArray(rawService) ? (rawService[0] as Record<string, unknown> | undefined) : (rawService as Record<string, unknown> | null)) ??
      null;

    return {
      id: String(r.id ?? ""),
      start_at: String(r.start_at ?? ""),
      end_at: String(r.end_at ?? ""),
      status: String(r.status ?? ""),
      customerName: (profile?.full_name as string | null | undefined) ?? null,
      serviceNameEn: (service?.name_en as string | null | undefined) ?? null,
      serviceNameAr: (service?.name_ar as string | null | undefined) ?? null
    };
  });

  return (
    <div className="flex flex-col gap-3">
      {list.length ? (
        list.map((b) => (
          <LuxuryCard key={b.id} className="bg-white p-5">
            <div className="flex items-start justify-between gap-3">
              <div className="flex flex-col gap-1">
                <div className="text-sm font-semibold text-[#111111]">{formatDateTime(b.start_at)}</div>
                <div className="text-xs text-muted-foreground">{b.customerName ?? "Customer"}</div>
                <div className="text-xs text-muted-foreground">{(b.serviceNameEn ?? b.serviceNameAr ?? "Service").trim()}</div>
              </div>
              <div className="rounded-full border border-border bg-secondary/30 px-2.5 py-1 text-xs text-muted-foreground">
                {b.status}
              </div>
            </div>

            <div className="pt-4 grid grid-cols-2 gap-2">
              <form action={updateBookingStatus}>
                <input type="hidden" name="booking_id" value={b.id} />
                <input type="hidden" name="status" value="confirmed" />
                <Button type="submit" variant="secondary" className="w-full rounded-2xl" disabled={b.status !== "pending"}>
                  Confirm
                </Button>
              </form>
              <form action={updateBookingStatus}>
                <input type="hidden" name="booking_id" value={b.id} />
                <input type="hidden" name="status" value="cancelled" />
                <Button type="submit" variant="ghost" className="w-full rounded-2xl" disabled={b.status === "cancelled" || b.status === "completed"}>
                  Cancel
                </Button>
              </form>
              <form action={updateBookingStatus}>
                <input type="hidden" name="booking_id" value={b.id} />
                <input type="hidden" name="status" value="in_progress" />
                <Button type="submit" variant="secondary" className="w-full rounded-2xl" disabled={b.status !== "confirmed"}>
                  Start
                </Button>
              </form>
              <form action={updateBookingStatus}>
                <input type="hidden" name="booking_id" value={b.id} />
                <input type="hidden" name="status" value="completed" />
                <Button
                  type="submit"
                  variant="secondary"
                  className="w-full rounded-2xl"
                  disabled={b.status !== "confirmed" && b.status !== "in_progress"}
                >
                  Complete
                </Button>
              </form>
              <form action={updateBookingStatus}>
                <input type="hidden" name="booking_id" value={b.id} />
                <input type="hidden" name="status" value="no_show" />
                <Button type="submit" variant="ghost" className="w-full rounded-2xl" disabled={b.status !== "confirmed" && b.status !== "in_progress"}>
                  No show
                </Button>
              </form>
            </div>
          </LuxuryCard>
        ))
      ) : (
        <LuxuryCard className="bg-white p-6">
          <div className="text-sm font-semibold text-[#111111]">No bookings yet</div>
          <div className="pt-1 text-sm text-muted-foreground">New bookings will appear here instantly.</div>
        </LuxuryCard>
      )}
    </div>
  );
}

async function PortfolioPanel({
  barberId,
  uploadPortfolio
}: {
  barberId: string;
  uploadPortfolio: (formData: FormData) => Promise<void>;
}) {
  const supabase = await createAppSupabaseServerClient();
  const { data: items } = await supabase
    .from("portfolio_items")
    .select("id, media_url, media_path, caption, created_at, status")
    .eq("owner_type", "barber")
    .eq("owner_id", barberId)
    .order("created_at", { ascending: false })
    .limit(60);

  const signed = await Promise.all(
    ((items ?? []) as Array<{ id: string; media_url: string; media_path: string | null; caption: string | null; status: string }>).map(
      async (it) => {
        const media = await signedOrUrl(supabase, "portfolio", it.media_path ?? it.media_url);
        return { ...it, signed_media: media ?? null };
      }
    )
  );

  return (
    <div className="flex flex-col gap-4">
      <LuxuryCard className="bg-white p-5">
        <form action={uploadPortfolio} className="grid gap-3" encType="multipart/form-data">
          <div className="grid gap-2">
            <Label htmlFor="caption">Caption</Label>
            <Input id="caption" name="caption" placeholder="Fade / Beard / VIP..." />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="file">Photo</Label>
            <Input id="file" name="file" type="file" accept="image/*" required />
          </div>
          <Button type="submit" className="w-full rounded-2xl">
            Upload
          </Button>
        </form>
      </LuxuryCard>

      {signed.length ? (
        <div className="grid grid-cols-3 gap-3">
          {signed.map((it) => (
            <LuxuryCard key={it.id} className="aspect-square overflow-hidden bg-white p-0">
              {it.signed_media ? (
                <SafeImage src={it.signed_media} fallbackSrc={it.signed_media} alt="" className="h-full w-full object-cover" />
              ) : null}
            </LuxuryCard>
          ))}
        </div>
      ) : (
        <LuxuryCard className="bg-white p-6">
          <div className="text-sm font-semibold text-[#111111]">Your portfolio is empty</div>
          <div className="pt-1 text-sm text-muted-foreground">Upload your best work to attract more customers.</div>
        </LuxuryCard>
      )}
    </div>
  );
}

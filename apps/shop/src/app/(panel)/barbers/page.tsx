import Link from "next/link";
import { redirect } from "next/navigation";
import { randomUUID } from "crypto";

import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

import { MediaFileInput } from "@/components/media-file-input";
import { SafeImage } from "@/components/safe-image";
import { getMyShop } from "@/lib/my-shop";
import { createAppSupabaseServerClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type BarberRow = {
  id: string;
  display_name: string | null;
  specialty: string | null;
  bio: string | null;
  is_active: boolean | null;
  available_now: boolean | null;
  waiting_time_min: number | null;
  queue_length: number | null;
  avatar_url: string | null;
  avatar_path: string | null;
  cover_url: string | null;
  cover_path: string | null;
};

function userFacingDbError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong.";
  if (m.toLowerCase().includes("bucket not found")) {
    return "Storage bucket not found. Run the storage migrations in Supabase to create the buckets.";
  }
  if (m.toLowerCase().includes("permission denied") || m.toLowerCase().includes("row-level security")) {
    return "Permission denied. Make sure you are signed in as the shop owner account.";
  }
  return m;
}

export default async function ShopBarbersPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const error = userFacingDbError((params?.error ?? "").trim());

  const supabase = await createAppSupabaseServerClient();
  const shop = await getMyShop(supabase);
  if (!shop) return <div className="text-sm text-muted-foreground">No shop assigned to this account.</div>;

  const { data: barbers } = await supabase
    .from("barbers")
    .select(
      "id, display_name, specialty, bio, is_active, available_now, waiting_time_min, queue_length, avatar_url, avatar_path, cover_url, cover_path"
    )
    .eq("shop_id", shop.id)
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(200);

  async function updateBarber(formData: FormData) {
    "use server";

    const barberId = String(formData.get("barber_id") ?? "").trim();
    if (!barberId) redirect("/barbers");

    const displayName = String(formData.get("display_name") ?? "").trim();
    const specialty = String(formData.get("specialty") ?? "").trim();
    const bio = String(formData.get("bio") ?? "").trim();
    const isActive = String(formData.get("is_active") ?? "") === "on";
    const availableNow = String(formData.get("available_now") ?? "") === "on";
    const waitingTimeMin = Number(formData.get("waiting_time_min") ?? 0);
    const queueLength = Number(formData.get("queue_length") ?? 0);

    const avatarFile = formData.get("avatar_file");
    const coverFile = formData.get("cover_file");

    const supabase = await createAppSupabaseServerClient();
    const shop = await getMyShop(supabase);
    if (!shop) redirect("/barbers");

    let avatarPath: string | null = null;
    let coverPath: string | null = null;

    if (avatarFile instanceof File && avatarFile.size > 0) {
      const ext = avatarFile.name.includes(".") ? avatarFile.name.split(".").pop() : undefined;
      const safeExt = ext ? `.${ext.toLowerCase()}` : "";
      const objectPath = `barbers/${barberId}/avatar-${randomUUID()}${safeExt}`;
      const bytes = new Uint8Array(await avatarFile.arrayBuffer());
      const { error } = await supabase.storage.from("barber-images").upload(objectPath, bytes, { contentType: avatarFile.type, upsert: true });
      if (error) redirect(`/barbers?error=${encodeURIComponent(error.message)}`);
      avatarPath = objectPath;
    }

    if (coverFile instanceof File && coverFile.size > 0) {
      const ext = coverFile.name.includes(".") ? coverFile.name.split(".").pop() : undefined;
      const safeExt = ext ? `.${ext.toLowerCase()}` : "";
      const objectPath = `barbers/${barberId}/cover-${randomUUID()}${safeExt}`;
      const bytes = new Uint8Array(await coverFile.arrayBuffer());
      const { error } = await supabase.storage.from("barber-images").upload(objectPath, bytes, { contentType: coverFile.type, upsert: true });
      if (error) redirect(`/barbers?error=${encodeURIComponent(error.message)}`);
      coverPath = objectPath;
    }

    const avatarUrl = avatarPath ? supabase.storage.from("barber-images").getPublicUrl(avatarPath).data.publicUrl : null;
    const coverUrl = coverPath ? supabase.storage.from("barber-images").getPublicUrl(coverPath).data.publicUrl : null;

    const { error: updateError } = await supabase
      .from("barbers")
      .update({
        display_name: displayName || null,
        specialty: specialty || null,
        bio: bio || null,
        is_active: isActive,
        available_now: availableNow,
        waiting_time_min: Number.isFinite(waitingTimeMin) ? waitingTimeMin : null,
        queue_length: Number.isFinite(queueLength) ? queueLength : null,
        ...(avatarPath ? { avatar_path: avatarPath, avatar_url: avatarUrl } : null),
        ...(coverPath ? { cover_path: coverPath, cover_url: coverUrl } : null)
      })
      .eq("id", barberId);

    if (updateError) redirect(`/barbers?error=${encodeURIComponent(updateError.message)}`);
    redirect("/barbers");
  }

  return (
    <div className="flex flex-col gap-4">
      <LuxuryCard className="p-4">
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col gap-1">
            <div className="text-base font-semibold">Barbers</div>
            <div className="text-sm text-muted-foreground">Edit your connected barbers (profile, photos, availability status).</div>
            {error && params?.error ? <div className="pt-2 text-sm text-red-400">{error}</div> : null}
          </div>
          <Button asChild size="sm">
            <Link href="/barber-requests">Add Barber</Link>
          </Button>
        </div>
      </LuxuryCard>

      {(barbers as BarberRow[] | null)?.length ? (
        <div className="grid gap-4">
          {(barbers as BarberRow[]).map((b) => {
            const avatarSrc = b.avatar_url ?? (b.avatar_path ? supabase.storage.from("barber-images").getPublicUrl(b.avatar_path).data.publicUrl : null);
            const coverSrc = b.cover_url ?? (b.cover_path ? supabase.storage.from("barber-images").getPublicUrl(b.cover_path).data.publicUrl : null);
            return (
              <LuxuryCard key={b.id} className="p-4">
                <form action={updateBarber} className="grid gap-4">
                  <input type="hidden" name="barber_id" value={b.id} />

                  <div className="grid gap-2">
                    <div className="text-sm font-semibold">{b.display_name ?? "Barber"}</div>
                    <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
                      <div className="grid gap-2">
                        <Label>Cover</Label>
                        <SafeImage src={coverSrc} alt="Cover" className="h-28 w-full rounded-md object-cover" />
                        <MediaFileInput name="cover_file" accept="image/*" />
                      </div>
                      <div className="grid gap-2">
                        <Label>Avatar</Label>
                        <SafeImage src={avatarSrc} alt="Avatar" className="h-20 w-20 rounded-full object-cover" />
                        <MediaFileInput name="avatar_file" accept="image/*" />
                      </div>
                    </div>
                  </div>

                  <div className="grid gap-2">
                    <Label htmlFor={`display_name_${b.id}`}>Display name</Label>
                    <Input id={`display_name_${b.id}`} name="display_name" defaultValue={b.display_name ?? ""} />
                  </div>
                  <div className="grid gap-2">
                    <Label htmlFor={`specialty_${b.id}`}>Specialty</Label>
                    <Input id={`specialty_${b.id}`} name="specialty" defaultValue={b.specialty ?? ""} />
                  </div>
                  <div className="grid gap-2">
                    <Label htmlFor={`bio_${b.id}`}>Bio</Label>
                    <Input id={`bio_${b.id}`} name="bio" defaultValue={b.bio ?? ""} />
                  </div>

                  <div className="grid gap-2 md:grid-cols-2">
                    <label className="flex items-center gap-2 text-sm">
                      <input type="checkbox" name="is_active" defaultChecked={b.is_active ?? true} />
                      Active
                    </label>
                    <label className="flex items-center gap-2 text-sm">
                      <input type="checkbox" name="available_now" defaultChecked={b.available_now ?? false} />
                      Available now
                    </label>
                  </div>

                  <div className="grid gap-3 md:grid-cols-2">
                    <div className="grid gap-2">
                      <Label htmlFor={`waiting_${b.id}`}>Waiting time (min)</Label>
                      <Input id={`waiting_${b.id}`} name="waiting_time_min" type="number" step="1" defaultValue={b.waiting_time_min ?? 0} />
                    </div>
                    <div className="grid gap-2">
                      <Label htmlFor={`queue_${b.id}`}>Queue length</Label>
                      <Input id={`queue_${b.id}`} name="queue_length" type="number" step="1" defaultValue={b.queue_length ?? 0} />
                    </div>
                  </div>

                  <div className="flex justify-end">
                    <Button type="submit" size="sm" variant="secondary">
                      Save
                    </Button>
                  </div>
                </form>
              </LuxuryCard>
            );
          })}
        </div>
      ) : (
        <div className="text-sm text-muted-foreground">No barbers assigned to this shop yet.</div>
      )}
    </div>
  );
}

import { createSupabaseServerClient } from "@hallaq/supabase/server";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const q = (url.searchParams.get("q") ?? "").trim();

  if (q.length < 2) {
    return Response.json({ results: [] });
  }

  const supabase = await createSupabaseServerClient();

  const [profiles, shops, barbers, reels] = await Promise.all([
    supabase
      .from("profiles")
      .select("id, full_name, role, phone")
      .ilike("full_name", `%${q}%`)
      .limit(6),
    supabase.from("barbershops").select("id, name, area").ilike("name", `%${q}%`).limit(6),
    supabase.from("barbers").select("id, display_name, area").ilike("display_name", `%${q}%`).limit(6),
    supabase.from("reels").select("id, caption, status").ilike("caption", `%${q}%`).limit(6)
  ]);

  const results = [
    ...(profiles.data ?? []).map((p) => ({
      type: "user",
      title: p.full_name ?? p.id,
      subtitle: `${p.role ?? "user"} • ${p.phone ?? ""}`.trim(),
      href: `/users/${p.id}`
    })),
    ...(shops.data ?? []).map((s) => ({
      type: "store",
      title: s.name ?? s.id,
      subtitle: s.area ?? "Store",
      href: `/stores/${s.id}`
    })),
    ...(barbers.data ?? []).map((b) => ({
      type: "barber",
      title: b.display_name ?? b.id,
      subtitle: b.area ?? "Barber",
      href: `/barbers/${b.id}`
    })),
    ...(reels.data ?? []).map((r) => ({
      type: "reel",
      title: r.caption ?? r.id,
      subtitle: r.status ?? "reel",
      href: `/posts-reels/${r.id}`
    }))
  ];

  return Response.json({ results });
}

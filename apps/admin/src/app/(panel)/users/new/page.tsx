import Link from "next/link";
import { redirect } from "next/navigation";

import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";
import { Label } from "@hallaq/ui/label";

import { PageFrame } from "@/components/page-frame";
import { createAuthUserWithProfile, type CreateUserRole } from "@/lib/admin/users";

export const dynamic = "force-dynamic";

function userFacingError(message: string) {
  const m = (message ?? "").trim();
  if (!m) return "Something went wrong.";
  const lower = m.toLowerCase();
  if (lower.includes("already registered") || lower.includes("already exists")) {
    return "This email is already registered.";
  }
  if (lower.includes("password") && lower.includes("short")) {
    return "Password is too short.";
  }
  if (lower.includes("invalid") && lower.includes("email")) {
    return "Please enter a valid email address.";
  }
  return m;
}

export default async function NewUserPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const params = searchParams ? await searchParams : undefined;
  const error = userFacingError((params?.error ?? "").trim());

  async function createUser(formData: FormData) {
    "use server";

    const role = String(formData.get("role") ?? "").trim() as CreateUserRole;
    const email = String(formData.get("email") ?? "").trim();
    const password = String(formData.get("password") ?? "").trim();
    const fullName = String(formData.get("full_name") ?? "").trim();
    const phone = String(formData.get("phone") ?? "").trim();

    if (!role || !email || !password || !fullName) {
      redirect(`/users/new?error=${encodeURIComponent("Role, email, password, and full name are required.")}`);
    }

    if (!["customer", "barber", "shop_owner", "admin"].includes(role)) {
      redirect(`/users/new?error=${encodeURIComponent("Invalid role.")}`);
    }

    try {
      const { userId } = await createAuthUserWithProfile({ role, email, password, fullName, phone });
      redirect(`/users/${encodeURIComponent(userId)}`);
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Failed to create user.";
      redirect(`/users/new?error=${encodeURIComponent(userFacingError(msg))}`);
    }
  }

  return (
    <PageFrame
      title="Create User"
      subtitle="Creates a Supabase Auth user and the matching profiles row."
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/users">Back</Link>
        </Button>
      }
    >
      {params?.error ? (
        <div className="mb-4 rounded-xl border border-rose-500/20 bg-rose-500/10 px-4 py-3 text-sm text-rose-100">
          {error}
        </div>
      ) : null}
      <form action={createUser} className="grid gap-4">
        <div className="grid gap-2">
          <Label htmlFor="role">Role</Label>
          <select
            id="role"
            name="role"
            defaultValue="shop_owner"
            className="flex h-10 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-soft outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring"
          >
            <option value="shop_owner">Shop owner</option>
            <option value="barber">Barber</option>
            <option value="customer">Customer</option>
            <option value="admin">Admin</option>
          </select>
        </div>
        <div className="grid gap-2">
          <Label htmlFor="email">Email</Label>
          <Input id="email" name="email" type="email" placeholder="name@domain.com" required />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="password">Password</Label>
          <Input id="password" name="password" type="password" placeholder="Minimum 6 characters" required />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="full_name">Full name</Label>
          <Input id="full_name" name="full_name" placeholder="Full name" required />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="phone">Phone</Label>
          <Input id="phone" name="phone" placeholder="+973 ..." />
        </div>
        <div className="flex items-center justify-end gap-2 pt-2">
          <Button asChild variant="ghost">
            <Link href="/users">Cancel</Link>
          </Button>
          <Button type="submit">Create</Button>
        </div>
      </form>
    </PageFrame>
  );
}


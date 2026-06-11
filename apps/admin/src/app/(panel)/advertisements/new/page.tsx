export const dynamic = "force-dynamic";
import { redirect } from "next/navigation";

export default function NewAdvertisementPage() {
  redirect("/dashboard");
}

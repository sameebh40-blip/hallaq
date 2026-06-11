import { redirect } from "next/navigation";

export default function ShopHomePage() {
  const mode = (process.env.NEXT_PUBLIC_HALLAQ_ROUTING_MODE ?? "path").toLowerCase();
  redirect(mode === "subdomain" ? "/business/dashboard" : "/dashboard");
}

import Link from "next/link";

import { CustomerBottomNav } from "@/components/customer-bottom-nav";
import { ScanClient } from "./scan-client";

export const dynamic = "force-dynamic";

export default function ScanPage() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-4 bg-black px-4 py-6 pb-28 text-white">
      <div className="flex items-center justify-between">
        <Link href="/home" className="text-sm font-semibold text-[#9E9E9E]">
          Back
        </Link>
        <div className="text-sm font-extrabold">QR Scanner</div>
        <div className="w-10" />
      </div>
      <ScanClient />
      <CustomerBottomNav />
    </main>
  );
}


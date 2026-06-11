"use client";

import { useEffect } from "react";
import { usePathname, useRouter } from "next/navigation";

export function BusinessMobileRedirect({ redirectTo }: { redirectTo: string }) {
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    const run = () => {
      if (typeof window === "undefined") return;
      const w = window.innerWidth;
      if (w < 768) router.replace(redirectTo);
    };
    run();
    window.addEventListener("resize", run);
    return () => window.removeEventListener("resize", run);
  }, [router, redirectTo, pathname]);

  return null;
}

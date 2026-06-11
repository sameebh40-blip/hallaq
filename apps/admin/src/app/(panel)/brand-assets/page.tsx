import { PageFrame } from "@/components/page-frame";

import { BrandAssetsManager } from "./brand-assets-manager";

export const dynamic = "force-dynamic";

export default function BrandAssetsPage() {
  return (
    <PageFrame title="Brand Assets" subtitle="Upload and control every default image and logo used across the platform.">
      <BrandAssetsManager />
    </PageFrame>
  );
}


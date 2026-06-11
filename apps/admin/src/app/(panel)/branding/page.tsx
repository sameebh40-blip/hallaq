import { PageFrame } from "@/components/page-frame";

import { BrandAssetsManager } from "@/app/(panel)/brand-assets/brand-assets-manager";

export const dynamic = "force-dynamic";

export default function BrandingPage() {
  return (
    <PageFrame title="Branding Center" subtitle="Upload and control every default image and logo used across the platform.">
      <BrandAssetsManager />
    </PageFrame>
  );
}

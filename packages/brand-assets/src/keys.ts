export const REQUIRED_BRAND_ASSET_KEYS = [
  "app_logo",
  "app_logo_dark",
  "app_logo_light",
  "splash_logo",
  "login_logo",
  "default_profile_avatar",
  "default_profile_cover",
  "default_customer_avatar",
  "default_barber_avatar",
  "default_barber_cover",
  "default_shop_logo",
  "default_shop_cover",
  "default_service_image",
  "default_product_image",
  "default_reel_thumbnail",
  "default_offer_image",
  "default_style_image",
  "default_empty_state",
  "default_error_state",
  "default_booking_image",
  "default_hallaq_city_banner",
  "default_home_banner",
  "default_login_background",
  "default_home_hero_banner",
  "default_notification_image",
  "default_gift_card_image",
  "default_membership_banner"
] as const;

export type BrandAssetKey = (typeof REQUIRED_BRAND_ASSET_KEYS)[number];

export const BRAND_ASSET_ALIASES: Readonly<Record<string, string>> = {
  default_profile_image: "default_profile_avatar"
};

export function resolveBrandAssetKey(key: string) {
  const k = String(key ?? "").trim();
  return BRAND_ASSET_ALIASES[k] ?? k;
}

export function getLocalizedAssetKey(baseKey: string, locale: string) {
  const base = resolveBrandAssetKey(baseKey);
  const loc = String(locale ?? "").trim().toLowerCase();
  if (!base || !loc) return base;
  return `${base}_${loc}`;
}

export type BrandAssetRow = {
  asset_key: string;
  asset_name: string;
  asset_url: string | null;
  asset_type: string | null;
  is_active: boolean;
  updated_at: string;
  created_at: string;
  updated_by: string | null;
};

export type BrandAssetsMap = Record<string, string>;

export const EMERGENCY_FALLBACK_IMAGE = "/icon.png";

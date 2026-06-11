const IMG = {
  onboardingBg:
    "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Luxury%20barbershop%20interior%2C%20warm%20golden%20lighting%2C%20premium%20salon%20chairs%2C%20clean%20modern%20design%2C%20photorealistic%2C%20high%20detail%2C%20soft%20depth%20of%20field&image_size=portrait_16_9",
  shopCover:
    "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Premium%20barbershop%20cover%20photo%2C%20luxury%20salon%20interior%2C%20gold%20accents%2C%20ivory%20and%20black%20palette%2C%20photorealistic%2C%20high%20detail&image_size=landscape_16_9",
  shopLogo:
    "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Minimal%20luxury%20barbershop%20logo%20mark%2C%20gold%20monogram%20on%20white%20background%2C%20clean%20branding%2C%20photorealistic%20render&image_size=square",
  barberAvatar:
    "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Professional%20barber%20portrait%2C%20studio%20lighting%2C%20neutral%20background%2C%20photorealistic%2C%20high%20detail&image_size=square",
  reelPoster:
    "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Close-up%20men%27s%20haircut%20fade%2C%20barbershop%20lighting%2C%20premium%20grooming%20photography%2C%20photorealistic%2C%20high%20detail&image_size=portrait_16_9"
} as const;

export function demoCustomerHomeData() {
  return {
    featuredShops: [
      {
        id: "demo-shop-1",
        name: "The Elite Barbers",
        area: "Seef",
        address: "Manama, Bahrain",
        is_featured: true,
        is_verified: true,
        status: "approved",
        cover_url: IMG.shopCover,
        logo_url: IMG.shopLogo
      }
    ],
    topBarbers: [
      {
        id: "demo-barber-1",
        display_name: "Ali Al Hassan",
        shop_id: "demo-shop-1",
        avatar_url: IMG.barberAvatar,
        rating: 4.9
      }
    ],
    trendingReels: [
      {
        id: "demo-reel-1",
        caption: "Clean mid fade with texture",
        media_url: IMG.reelPoster,
        media_type: "image",
        shop_id: "demo-shop-1",
        barber_id: "demo-barber-1"
      }
    ],
    images: IMG
  };
}


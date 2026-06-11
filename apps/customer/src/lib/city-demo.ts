const IMG = {
  heroBarber:
    "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Premium%20men%27s%20haircut%20fade%20close-up%2C%20luxury%20barbershop%20lighting%2C%20clean%20white%20background%20accents%2C%20high-end%20grooming%20photography%2C%20photorealistic%2C%20high%20detail&image_size=portrait_16_9",
  heroShop:
    "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Luxury%20barbershop%20interior%20in%20Bahrain%2C%20gold%20accents%2C%20clean%20modern%20design%2C%20premium%20chairs%2C%20warm%20lighting%2C%20photorealistic%2C%20high%20detail&image_size=portrait_16_9",
  heroAward:
    "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Luxury%20gold%20trophy%20on%20marble%20pedestal%2C%20soft%20studio%20light%2C%20premium%20award%20photography%2C%20photorealistic%2C%20high%20detail&image_size=portrait_16_9",
  heroStyle:
    "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Men%27s%20haircut%20style%20editorial%20photo%2C%20skin%20fade%2C%20high%20contrast%20studio%20lighting%2C%20clean%20premium%20look%2C%20photorealistic%2C%20high%20detail&image_size=portrait_16_9",
  reelPoster:
    "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Close-up%20men%27s%20fade%20haircut%2C%20barbershop%20lighting%2C%20premium%20grooming%20photography%2C%20photorealistic%2C%20high%20detail&image_size=portrait_16_9",
  styleGrid:
    "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Men%27s%20haircut%20style%20reference%20photo%2C%20clean%20neutral%20background%2C%20premium%20editorial%20lighting%2C%20photorealistic%2C%20high%20detail&image_size=square_hd"
} as const;

export type CityStyleDemo = {
  id: string;
  name: string;
  category: string;
  heroImageUrl: string;
  gallery: string[];
  difficulty: "Easy" | "Medium" | "Hard";
  avgPriceBhd: number;
  aiStyleKey: string;
};

export function demoCityData() {
  const styles: CityStyleDemo[] = [
    { id: "skin-fade", name: "Skin Fade", category: "Fade", heroImageUrl: IMG.heroStyle, gallery: [IMG.styleGrid, IMG.styleGrid, IMG.styleGrid], difficulty: "Medium", avgPriceBhd: 6.0, aiStyleKey: "skin_fade" },
    { id: "mid-fade", name: "Mid Fade", category: "Fade", heroImageUrl: IMG.styleGrid, gallery: [IMG.styleGrid, IMG.styleGrid, IMG.styleGrid], difficulty: "Medium", avgPriceBhd: 5.5, aiStyleKey: "mid_fade" },
    { id: "low-fade", name: "Low Fade", category: "Fade", heroImageUrl: IMG.styleGrid, gallery: [IMG.styleGrid, IMG.styleGrid, IMG.styleGrid], difficulty: "Easy", avgPriceBhd: 5.0, aiStyleKey: "low_fade" },
    { id: "burst-fade", name: "Burst Fade", category: "Fade", heroImageUrl: IMG.styleGrid, gallery: [IMG.styleGrid, IMG.styleGrid, IMG.styleGrid], difficulty: "Hard", avgPriceBhd: 7.0, aiStyleKey: "burst_fade" },
    { id: "french-crop", name: "French Crop", category: "Crop", heroImageUrl: IMG.styleGrid, gallery: [IMG.styleGrid, IMG.styleGrid, IMG.styleGrid], difficulty: "Medium", avgPriceBhd: 6.0, aiStyleKey: "french_crop" },
    { id: "buzz-cut", name: "Buzz Cut", category: "Classic", heroImageUrl: IMG.styleGrid, gallery: [IMG.styleGrid, IMG.styleGrid, IMG.styleGrid], difficulty: "Easy", avgPriceBhd: 4.0, aiStyleKey: "buzz_cut" },
    { id: "mullet", name: "Mullet", category: "Trending", heroImageUrl: IMG.styleGrid, gallery: [IMG.styleGrid, IMG.styleGrid, IMG.styleGrid], difficulty: "Hard", avgPriceBhd: 8.0, aiStyleKey: "mullet" },
    { id: "slick-back", name: "Slick Back", category: "Classic", heroImageUrl: IMG.styleGrid, gallery: [IMG.styleGrid, IMG.styleGrid, IMG.styleGrid], difficulty: "Medium", avgPriceBhd: 7.0, aiStyleKey: "slick_back" },
    { id: "pompadour", name: "Pompadour", category: "Classic", heroImageUrl: IMG.styleGrid, gallery: [IMG.styleGrid, IMG.styleGrid, IMG.styleGrid], difficulty: "Hard", avgPriceBhd: 8.0, aiStyleKey: "pompadour" },
    { id: "undercut", name: "Undercut", category: "Classic", heroImageUrl: IMG.styleGrid, gallery: [IMG.styleGrid, IMG.styleGrid, IMG.styleGrid], difficulty: "Medium", avgPriceBhd: 6.5, aiStyleKey: "undercut" }
  ];

  const hero = [
    { id: "best-barber-week", title: "Best Barber of Week", subtitle: "Award: Clean Fade Master", imageUrl: IMG.heroBarber, href: "/city/barbers" },
    { id: "top-shop-week", title: "Top Shop of Week", subtitle: "Premium interior & service", imageUrl: IMG.heroShop, href: "/city/shops/new" },
    { id: "award-winner", title: "Award Winner", subtitle: "Hallaq Awards Spotlight", imageUrl: IMG.heroAward, href: "/city/awards" },
    { id: "trending-style", title: "Trending Style", subtitle: "Skin Fade • This week", imageUrl: IMG.heroStyle, href: "/city/styles/skin-fade" },
    { id: "upcoming-event", title: "Upcoming Event", subtitle: "Bahrain Grooming Night", imageUrl: IMG.heroShop, href: "/city" }
  ] as const;

  return { images: IMG, styles, hero };
}

export function demoAiResultImage(styleKey: string) {
  const map: Record<string, string> = {
    skin_fade:
      "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Photorealistic%20AI%20haircut%20preview%2C%20men%27s%20skin%20fade%2C%20neutral%20background%2C%20high%20end%20editorial%20lighting%2C%20before%20and%20after%20feel%2C%20high%20detail&image_size=portrait_16_9",
    mid_fade:
      "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Photorealistic%20AI%20haircut%20preview%2C%20men%27s%20mid%20fade%20with%20texture%2C%20neutral%20background%2C%20premium%20studio%20lighting%2C%20high%20detail&image_size=portrait_16_9",
    low_fade:
      "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Photorealistic%20AI%20haircut%20preview%2C%20men%27s%20low%20fade%2C%20clean%20natural%20look%2C%20neutral%20background%2C%20premium%20studio%20lighting%2C%20high%20detail&image_size=portrait_16_9",
    burst_fade:
      "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Photorealistic%20AI%20haircut%20preview%2C%20men%27s%20burst%20fade%2C%20modern%20style%2C%20neutral%20background%2C%20premium%20studio%20lighting%2C%20high%20detail&image_size=portrait_16_9",
    french_crop:
      "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Photorealistic%20AI%20haircut%20preview%2C%20men%27s%20french%20crop%2C%20clean%20fringe%2C%20neutral%20background%2C%20premium%20studio%20lighting%2C%20high%20detail&image_size=portrait_16_9",
    buzz_cut:
      "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Photorealistic%20AI%20haircut%20preview%2C%20men%27s%20buzz%20cut%2C%20clean%20minimal%2C%20neutral%20background%2C%20premium%20studio%20lighting%2C%20high%20detail&image_size=portrait_16_9",
    mullet:
      "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Photorealistic%20AI%20haircut%20preview%2C%20modern%20mullet%2C%20premium%20editorial%20look%2C%20neutral%20background%2C%20high%20detail&image_size=portrait_16_9",
    slick_back:
      "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Photorealistic%20AI%20haircut%20preview%2C%20men%27s%20slick%20back%20hair%2C%20premium%20editorial%20lighting%2C%20neutral%20background%2C%20high%20detail&image_size=portrait_16_9",
    pompadour:
      "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Photorealistic%20AI%20haircut%20preview%2C%20men%27s%20pompadour%2C%20volume%20style%2C%20neutral%20background%2C%20premium%20studio%20lighting%2C%20high%20detail&image_size=portrait_16_9",
    undercut:
      "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Photorealistic%20AI%20haircut%20preview%2C%20men%27s%20undercut%2C%20clean%20modern%2C%20neutral%20background%2C%20premium%20studio%20lighting%2C%20high%20detail&image_size=portrait_16_9"
  };
  return map[styleKey] ?? map.skin_fade;
}


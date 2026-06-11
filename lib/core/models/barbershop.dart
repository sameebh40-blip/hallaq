class Barbershop {
  final String id;
  final String ownerProfileId;
  final String name;
  final String? description;
  final String? aboutUs;
  final String? story;
  final int? yearsInBusiness;
  final List<String> specialties;
  final List<String> awards;
  final List<String> languages;
  final String? coverUrl;
  final String? logoUrl;
  final String? coverPath;
  final String? logoPath;
  final String? area;
  final String? address;
  final double? lat;
  final double? lng;
  final String? googleMapsUrl;
  final bool homeService;
  final String? phone;
  final String? whatsapp;
  final String? instagram;
  final Map<String, dynamic>? openingHours;
  final bool isFeatured;
  final double ratingAvg;
  final int ratingCount;
  final bool badgeVerified;
  final bool badgeElite;
  final bool badgeTrending;
  final bool badgeTopRated;
  final bool badgeCertified;
  final double? distanceKm;
  final double? startingPriceBhd;

  const Barbershop({
    required this.id,
    required this.ownerProfileId,
    required this.name,
    required this.ratingAvg,
    required this.ratingCount,
    this.description,
    this.aboutUs,
    this.story,
    this.yearsInBusiness,
    this.specialties = const [],
    this.awards = const [],
    this.languages = const [],
    this.coverUrl,
    this.logoUrl,
    this.coverPath,
    this.logoPath,
    this.area,
    this.address,
    this.lat,
    this.lng,
    this.googleMapsUrl,
    this.homeService = false,
    this.phone,
    this.whatsapp,
    this.instagram,
    this.openingHours,
    this.isFeatured = false,
    this.badgeVerified = false,
    this.badgeElite = false,
    this.badgeTrending = false,
    this.badgeTopRated = false,
    this.badgeCertified = false,
    this.distanceKm,
    this.startingPriceBhd,
  });

  Barbershop copyWith({
    String? id,
    String? ownerProfileId,
    String? name,
    String? description,
    String? aboutUs,
    String? story,
    int? yearsInBusiness,
    List<String>? specialties,
    List<String>? awards,
    List<String>? languages,
    String? coverUrl,
    String? logoUrl,
    String? coverPath,
    String? logoPath,
    String? area,
    String? address,
    double? lat,
    double? lng,
    String? googleMapsUrl,
    bool? homeService,
    String? phone,
    String? whatsapp,
    String? instagram,
    Map<String, dynamic>? openingHours,
    bool? isFeatured,
    double? ratingAvg,
    int? ratingCount,
    bool? badgeVerified,
    bool? badgeElite,
    bool? badgeTrending,
    bool? badgeTopRated,
    bool? badgeCertified,
    double? distanceKm,
    double? startingPriceBhd,
  }) {
    return Barbershop(
      id: id ?? this.id,
      ownerProfileId: ownerProfileId ?? this.ownerProfileId,
      name: name ?? this.name,
      description: description ?? this.description,
      aboutUs: aboutUs ?? this.aboutUs,
      story: story ?? this.story,
      yearsInBusiness: yearsInBusiness ?? this.yearsInBusiness,
      specialties: specialties ?? this.specialties,
      awards: awards ?? this.awards,
      languages: languages ?? this.languages,
      coverUrl: coverUrl ?? this.coverUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      coverPath: coverPath ?? this.coverPath,
      logoPath: logoPath ?? this.logoPath,
      area: area ?? this.area,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      googleMapsUrl: googleMapsUrl ?? this.googleMapsUrl,
      homeService: homeService ?? this.homeService,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      instagram: instagram ?? this.instagram,
      openingHours: openingHours ?? this.openingHours,
      isFeatured: isFeatured ?? this.isFeatured,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      ratingCount: ratingCount ?? this.ratingCount,
      badgeVerified: badgeVerified ?? this.badgeVerified,
      badgeElite: badgeElite ?? this.badgeElite,
      badgeTrending: badgeTrending ?? this.badgeTrending,
      badgeTopRated: badgeTopRated ?? this.badgeTopRated,
      badgeCertified: badgeCertified ?? this.badgeCertified,
      distanceKm: distanceKm ?? this.distanceKm,
      startingPriceBhd: startingPriceBhd ?? this.startingPriceBhd,
    );
  }

  factory Barbershop.fromJson(Map<String, dynamic> json) {
    final isVerified = (json['is_verified'] as bool?) ?? (json['badge_verified'] as bool?) ?? false;
    final isFeatured = (json['is_featured'] as bool?) ?? (json['badge_elite'] as bool?) ?? false;
    final openingHours = json['opening_hours'];
    final specialties = (json['specialties'] as List?)?.whereType<String>().toList(growable: false) ?? const <String>[];
    final awards = (json['awards'] as List?)?.whereType<String>().toList(growable: false) ?? const <String>[];
    final languages = (json['languages'] as List?)?.whereType<String>().toList(growable: false) ?? const <String>[];
    return Barbershop(
      id: json['id'] as String,
      ownerProfileId: json['owner_profile_id'] as String,
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      aboutUs: json['about_us'] as String?,
      story: json['story'] as String?,
      yearsInBusiness: (json['years_in_business'] as num?)?.toInt(),
      specialties: specialties,
      awards: awards,
      languages: languages,
      coverUrl: json['cover_url'] as String?,
      logoUrl: json['logo_url'] as String?,
      coverPath: json['cover_path'] as String?,
      logoPath: json['logo_path'] as String?,
      area: json['area'] as String?,
      address: json['address'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      googleMapsUrl: json['google_maps_url'] as String?,
      homeService: (json['home_service'] as bool?) ?? false,
      phone: json['phone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      instagram: json['instagram'] as String?,
      openingHours: openingHours is Map ? Map<String, dynamic>.from(openingHours) : null,
      isFeatured: isFeatured,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      badgeVerified: isVerified,
      badgeElite: (json['badge_elite'] as bool?) ?? false,
      badgeTrending: (json['badge_trending'] as bool?) ?? false,
      badgeTopRated: (json['badge_top_rated'] as bool?) ?? false,
      badgeCertified: (json['badge_certified'] as bool?) ?? false,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      startingPriceBhd: (json['starting_price_bhd'] as num?)?.toDouble(),
    );
  }
}

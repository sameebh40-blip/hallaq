class Barber {
  final String id;
  final String profileId;
  final String slug;
  final String displayName;
  final String? avatarUrl;
  final String? coverUrl;
  final String? avatarPath;
  final String? coverPath;
  final String? bio;
  final String? specialty;
  final String? shopId;
  final String? area;
  final String? address;
  final double? lat;
  final double? lng;
  final double ratingAvg;
  final int ratingCount;
  final int followersCount;
  final int reviewsCount;
  final bool isIndependent;
  final bool homeService;
  final bool availableNow;
  final bool isActive;
  final int? waitingTimeMin;
  final int? queueLength;
  final bool badgeVerified;
  final bool badgeElite;
  final bool badgeTrending;
  final bool badgeTopRated;
  final bool badgeCertified;
  final String status;
  final DateTime? createdAt;
  final double? distanceKm;
  final double? startingPriceBhd;

  const Barber({
    required this.id,
    required this.profileId,
    required this.slug,
    required this.displayName,
    required this.ratingAvg,
    required this.ratingCount,
    required this.followersCount,
    required this.reviewsCount,
    required this.isIndependent,
    this.homeService = false,
    required this.availableNow,
    this.isActive = true,
    this.status = 'approved',
    this.avatarUrl,
    this.coverUrl,
    this.avatarPath,
    this.coverPath,
    this.bio,
    this.specialty,
    this.shopId,
    this.area,
    this.address,
    this.lat,
    this.lng,
    this.waitingTimeMin,
    this.queueLength,
    this.badgeVerified = false,
    this.badgeElite = false,
    this.badgeTrending = false,
    this.badgeTopRated = false,
    this.badgeCertified = false,
    this.createdAt,
    this.distanceKm,
    this.startingPriceBhd,
  });

  Barber copyWith({
    String? id,
    String? profileId,
    String? slug,
    String? displayName,
    String? avatarUrl,
    String? coverUrl,
    String? avatarPath,
    String? coverPath,
    String? bio,
    String? specialty,
    String? shopId,
    String? area,
    String? address,
    double? lat,
    double? lng,
    double? ratingAvg,
    int? ratingCount,
    int? followersCount,
    int? reviewsCount,
    bool? isIndependent,
    bool? homeService,
    bool? availableNow,
    bool? isActive,
    int? waitingTimeMin,
    int? queueLength,
    bool? badgeVerified,
    bool? badgeElite,
    bool? badgeTrending,
    bool? badgeTopRated,
    bool? badgeCertified,
    String? status,
    DateTime? createdAt,
    double? distanceKm,
    double? startingPriceBhd,
  }) {
    return Barber(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      slug: slug ?? this.slug,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      avatarPath: avatarPath ?? this.avatarPath,
      coverPath: coverPath ?? this.coverPath,
      bio: bio ?? this.bio,
      specialty: specialty ?? this.specialty,
      shopId: shopId ?? this.shopId,
      area: area ?? this.area,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      ratingCount: ratingCount ?? this.ratingCount,
      followersCount: followersCount ?? this.followersCount,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      isIndependent: isIndependent ?? this.isIndependent,
      homeService: homeService ?? this.homeService,
      availableNow: availableNow ?? this.availableNow,
      isActive: isActive ?? this.isActive,
      waitingTimeMin: waitingTimeMin ?? this.waitingTimeMin,
      queueLength: queueLength ?? this.queueLength,
      badgeVerified: badgeVerified ?? this.badgeVerified,
      badgeElite: badgeElite ?? this.badgeElite,
      badgeTrending: badgeTrending ?? this.badgeTrending,
      badgeTopRated: badgeTopRated ?? this.badgeTopRated,
      badgeCertified: badgeCertified ?? this.badgeCertified,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      distanceKm: distanceKm ?? this.distanceKm,
      startingPriceBhd: startingPriceBhd ?? this.startingPriceBhd,
    );
  }

  factory Barber.fromJson(Map<String, dynamic> json) {
    final shopId = json['shop_id'] as String?;
    final isIndependent = (json['is_independent'] as bool?) ?? (shopId == null);
    final isVerified = (json['is_verified'] as bool?) ?? (json['badge_verified'] as bool?) ?? false;
    final isCertified = (json['is_hallaq_certified'] as bool?) ?? (json['badge_certified'] as bool?) ?? false;
    final status = (json['status'] as String?) ?? 'approved';
    final isActive = (json['is_active'] as bool?) ?? true;
    DateTime? createdAt;
    final rawCreatedAt = json['created_at'];
    if (rawCreatedAt is String && rawCreatedAt.isNotEmpty) {
      createdAt = DateTime.tryParse(rawCreatedAt);
    }
    return Barber(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      slug: (json['slug'] as String?) ?? (json['id'] as String),
      displayName: (json['display_name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      avatarPath: json['avatar_path'] as String?,
      coverPath: json['cover_path'] as String?,
      bio: json['bio'] as String?,
      specialty: json['specialty'] as String?,
      shopId: shopId,
      area: json['area'] as String?,
      address: json['address'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      reviewsCount: (json['reviews_count'] as num?)?.toInt() ?? 0,
      isIndependent: isIndependent,
      homeService: (json['home_service'] as bool?) ?? false,
      availableNow: (json['available_now'] as bool?) ?? false,
      isActive: isActive,
      waitingTimeMin: (json['waiting_time_min'] as num?)?.toInt(),
      queueLength: (json['queue_length'] as num?)?.toInt(),
      badgeVerified: isVerified,
      badgeElite: (json['badge_elite'] as bool?) ?? false,
      badgeTrending: (json['badge_trending'] as bool?) ?? false,
      badgeTopRated: (json['badge_top_rated'] as bool?) ?? false,
      badgeCertified: isCertified,
      status: status,
      createdAt: createdAt,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      startingPriceBhd: (json['starting_price_bhd'] as num?)?.toDouble(),
    );
  }
}

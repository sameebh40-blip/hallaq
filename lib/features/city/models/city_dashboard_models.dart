class CityBanner {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String href;

  const CityBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.href,
  });

  factory CityBanner.fromJson(Map<String, dynamic> json) {
    return CityBanner(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      subtitle: (json['subtitle'] as String?) ?? '',
      imageUrl: (json['image_url'] as String?) ?? '',
      href: (json['href'] as String?) ?? '/city',
    );
  }
}

class CityStats {
  final int activeBarbers;
  final int barberShops;
  final int activeOffers;
  final int monthlyBookings;
  final double averageRating;

  const CityStats({
    required this.activeBarbers,
    required this.barberShops,
    required this.activeOffers,
    required this.monthlyBookings,
    required this.averageRating,
  });
}

class TrendingBarber {
  final String barberId;
  final String displayName;
  final double ratingAvg;
  final int bookingsCount;
  final String? avatarUrl;
  final String? avatarPath;
  final String? area;

  const TrendingBarber({
    required this.barberId,
    required this.displayName,
    required this.ratingAvg,
    required this.bookingsCount,
    required this.avatarUrl,
    required this.avatarPath,
    required this.area,
  });

  factory TrendingBarber.fromJson(Map<String, dynamic> json) {
    return TrendingBarber(
      barberId: json['barber_id'] as String,
      displayName: (json['display_name'] as String?) ?? '',
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
      bookingsCount: (json['bookings_count'] as num?)?.toInt() ?? 0,
      avatarUrl: json['avatar_url'] as String?,
      avatarPath: json['avatar_path'] as String?,
      area: json['area'] as String?,
    );
  }
}

class TrendingShop {
  final String shopId;
  final String name;
  final double ratingAvg;
  final int bookingsCount;
  final String? logoUrl;
  final String? logoPath;
  final String? area;

  const TrendingShop({
    required this.shopId,
    required this.name,
    required this.ratingAvg,
    required this.bookingsCount,
    required this.logoUrl,
    required this.logoPath,
    required this.area,
  });

  factory TrendingShop.fromJson(Map<String, dynamic> json) {
    return TrendingShop(
      shopId: json['shop_id'] as String,
      name: (json['name'] as String?) ?? '',
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
      bookingsCount: (json['bookings_count'] as num?)?.toInt() ?? 0,
      logoUrl: json['logo_url'] as String?,
      logoPath: json['logo_path'] as String?,
      area: json['area'] as String?,
    );
  }
}

class TrendingReel {
  final String reelId;
  final int viewsCount;
  final String? caption;
  final String? thumbnailUrl;
  final String? thumbnailPath;
  final String? mediaUrl;
  final String? mediaPath;

  const TrendingReel({
    required this.reelId,
    required this.viewsCount,
    required this.caption,
    required this.thumbnailUrl,
    required this.thumbnailPath,
    required this.mediaUrl,
    required this.mediaPath,
  });

  factory TrendingReel.fromJson(Map<String, dynamic> json) {
    return TrendingReel(
      reelId: json['reel_id'] as String,
      viewsCount: (json['views_count'] as num?)?.toInt() ?? 0,
      caption: json['caption'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      thumbnailPath: json['thumbnail_path'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaPath: json['media_path'] as String?,
    );
  }
}

class StyleLibraryItem {
  final String id;
  final String slug;
  final String nameEn;
  final String nameAr;
  final String? coverUrl;
  final String? coverPath;
  final int viewsCount;

  const StyleLibraryItem({
    required this.id,
    required this.slug,
    required this.nameEn,
    required this.nameAr,
    required this.coverUrl,
    required this.coverPath,
    required this.viewsCount,
  });

  factory StyleLibraryItem.fromJson(Map<String, dynamic> json) {
    return StyleLibraryItem(
      id: json['id'] as String,
      slug: (json['slug'] as String?) ?? '',
      nameEn: (json['name_en'] as String?) ?? '',
      nameAr: (json['name_ar'] as String?) ?? '',
      coverUrl: json['cover_url'] as String?,
      coverPath: json['cover_path'] as String?,
      viewsCount: (json['views_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class CityTrendingToday {
  final TrendingBarber? mostBookedBarber;
  final TrendingShop? mostBookedShop;
  final TrendingReel? mostWatchedReel;
  final StyleLibraryItem? mostLikedStyle;

  const CityTrendingToday({
    required this.mostBookedBarber,
    required this.mostBookedShop,
    required this.mostWatchedReel,
    required this.mostLikedStyle,
  });
}

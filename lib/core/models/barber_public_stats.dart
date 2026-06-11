class BarberPublicStats {
  final String barberId;
  final int yearsExperience;
  final int totalBookings;
  final double averageRating;
  final double? responseTimeMinutes;
  final double? completionRate;
  final int followers;
  final int portfolioCount;
  final int reelViews;

  const BarberPublicStats({
    required this.barberId,
    required this.yearsExperience,
    required this.totalBookings,
    required this.averageRating,
    required this.followers,
    required this.portfolioCount,
    required this.reelViews,
    this.responseTimeMinutes,
    this.completionRate,
  });

  factory BarberPublicStats.fromJson(Map<String, dynamic> json) {
    return BarberPublicStats(
      barberId: (json['barber_id'] as String?) ?? '',
      yearsExperience: (json['years_experience'] as num?)?.toInt() ?? 0,
      totalBookings: (json['total_bookings'] as num?)?.toInt() ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      responseTimeMinutes: (json['response_time_minutes'] as num?)?.toDouble(),
      completionRate: (json['completion_rate'] as num?)?.toDouble(),
      followers: (json['followers'] as num?)?.toInt() ?? 0,
      portfolioCount: (json['portfolio_count'] as num?)?.toInt() ?? 0,
      reelViews: (json['reel_views'] as num?)?.toInt() ?? 0,
    );
  }
}


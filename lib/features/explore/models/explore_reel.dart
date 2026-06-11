import '../../../core/models/reel.dart';

enum ExploreAuthorType { barber, shop }

class ExploreAuthor {
  final ExploreAuthorType type;
  final String id;
  final String slug;
  final String displayName;
  final String? avatarUrl;
  final String? area;
  final String? address;
  final double? lat;
  final double? lng;
  final bool verified;
  final String? shopId;
  final String? shopName;

  const ExploreAuthor({
    required this.type,
    required this.id,
    required this.slug,
    required this.displayName,
    required this.verified,
    this.avatarUrl,
    this.area,
    this.address,
    this.lat,
    this.lng,
    this.shopId,
    this.shopName,
  });
}

class ExploreReel {
  final Reel reel;
  final ExploreAuthor author;
  final String status;
  final String? rejectionReason;
  final bool isLiked;
  final bool isSaved;
  final bool isFollowing;

  const ExploreReel({
    required this.reel,
    required this.author,
    this.status = 'approved',
    this.rejectionReason,
    required this.isLiked,
    required this.isSaved,
    required this.isFollowing,
  });

  ExploreReel copyWith({
    Reel? reel,
    ExploreAuthor? author,
    String? status,
    String? rejectionReason,
    bool? isLiked,
    bool? isSaved,
    bool? isFollowing,
  }) {
    return ExploreReel(
      reel: reel ?? this.reel,
      author: author ?? this.author,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}

class Reel {
  final String id;
  final String? barberId;
  final String? shopId;
  final String mediaType;
  final String mediaUrl;
  final String? mediaPath;
  final String? mediaBucket;
  final String? imageUrl;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? thumbnailPath;
  final String? thumbnailBucket;
  final String? caption;
  final String? location;
  final List<String> hashtags;
  final String status;
  final String? rejectionReason;
  final int viewsCount;
  final int likesCount;
  final int commentsCount;
  final int savesCount;
  final int sharesCount;
  final DateTime createdAt;

  const Reel({
    required this.id,
    required this.barberId,
    required this.shopId,
    required this.mediaType,
    required this.mediaUrl,
    required this.viewsCount,
    required this.likesCount,
    required this.commentsCount,
    required this.savesCount,
    required this.sharesCount,
    required this.createdAt,
    this.mediaPath,
    this.mediaBucket,
    this.imageUrl,
    this.videoUrl,
    this.thumbnailUrl,
    this.thumbnailPath,
    this.thumbnailBucket,
    this.caption,
    this.location,
    this.hashtags = const [],
    this.status = 'approved',
    this.rejectionReason,
  });

  Reel copyWith({
    String? id,
    String? barberId,
    String? shopId,
    String? mediaType,
    String? mediaUrl,
    String? mediaPath,
    String? mediaBucket,
    String? imageUrl,
    String? videoUrl,
    String? thumbnailUrl,
    String? thumbnailPath,
    String? thumbnailBucket,
    String? caption,
    String? location,
    List<String>? hashtags,
    String? status,
    String? rejectionReason,
    int? viewsCount,
    int? likesCount,
    int? commentsCount,
    int? savesCount,
    int? sharesCount,
    DateTime? createdAt,
  }) {
    return Reel(
      id: id ?? this.id,
      barberId: barberId ?? this.barberId,
      shopId: shopId ?? this.shopId,
      mediaType: mediaType ?? this.mediaType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaBucket: mediaBucket ?? this.mediaBucket,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailBucket: thumbnailBucket ?? this.thumbnailBucket,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      hashtags: hashtags ?? this.hashtags,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      viewsCount: viewsCount ?? this.viewsCount,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      savesCount: savesCount ?? this.savesCount,
      sharesCount: sharesCount ?? this.sharesCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Reel.fromJson(Map<String, dynamic> json) {
    final imageUrl = json['image_url'] as String?;
    final videoUrl = json['video_url'] as String?;
    final existingMediaType = (json['media_type'] as String?)?.trim();
    final existingMediaUrl = (json['media_url'] as String?)?.trim();
    final resolvedMediaType = (existingMediaType != null && existingMediaType.isNotEmpty)
        ? existingMediaType
        : (videoUrl != null && videoUrl.isNotEmpty)
            ? 'video'
            : 'image';
    final resolvedMediaUrl = (existingMediaUrl != null && existingMediaUrl.isNotEmpty)
        ? existingMediaUrl
        : (resolvedMediaType == 'video')
            ? (videoUrl ?? '')
            : (imageUrl ?? '');
    final rawHashtags = json['hashtags'];
    final hashtags = (rawHashtags is List) ? rawHashtags.map((e) => e.toString()).toList(growable: false) : const <String>[];
    return Reel(
      id: json['id'] as String,
      barberId: json['barber_id'] as String?,
      shopId: json['shop_id'] as String?,
      mediaType: resolvedMediaType,
      mediaUrl: resolvedMediaUrl,
      mediaPath: json['media_path'] as String?,
      mediaBucket: (json['media_bucket'] as String?)?.trim().isEmpty == true ? null : (json['media_bucket'] as String?),
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      thumbnailUrl: json['thumbnail_url'] as String?,
      thumbnailPath: json['thumbnail_path'] as String?,
      thumbnailBucket: (json['thumbnail_bucket'] as String?)?.trim().isEmpty == true ? null : (json['thumbnail_bucket'] as String?),
      caption: json['caption'] as String?,
      location: json['location'] as String?,
      hashtags: hashtags,
      status: (json['status'] as String?) ?? 'approved',
      rejectionReason: json['rejection_reason'] as String?,
      viewsCount: (json['views_count'] as num?)?.toInt() ?? 0,
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      savesCount: (json['saves_count'] as num?)?.toInt() ?? 0,
      sharesCount: (json['shares_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

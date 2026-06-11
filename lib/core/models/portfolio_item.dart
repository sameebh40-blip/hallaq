class PortfolioItem {
  final String id;
  final String ownerType;
  final String ownerId;
  final String? barberId;
  final String? shopId;
  final String mediaType;
  final String mediaUrl;
  final String? thumbnailUrl;
  final String? imageUrl;
  final String? mediaPath;
  final String? thumbnailPath;
  final String status;
  final String? caption;
  final String? captionEn;
  final String? captionAr;
  final String? category;
  final bool isFeatured;
  final DateTime createdAt;

  const PortfolioItem({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.barberId,
    required this.shopId,
    required this.mediaType,
    required this.mediaUrl,
    required this.createdAt,
    this.thumbnailUrl,
    this.imageUrl,
    this.mediaPath,
    this.thumbnailPath,
    this.status = 'approved',
    this.caption,
    this.captionEn,
    this.captionAr,
    this.category,
    this.isFeatured = false,
  });

  PortfolioItem copyWith({
    String? id,
    String? ownerType,
    String? ownerId,
    String? barberId,
    String? shopId,
    String? mediaType,
    String? mediaUrl,
    String? thumbnailUrl,
    String? imageUrl,
    String? mediaPath,
    String? thumbnailPath,
    String? status,
    String? caption,
    String? captionEn,
    String? captionAr,
    String? category,
    bool? isFeatured,
    DateTime? createdAt,
  }) {
    return PortfolioItem(
      id: id ?? this.id,
      ownerType: ownerType ?? this.ownerType,
      ownerId: ownerId ?? this.ownerId,
      barberId: barberId ?? this.barberId,
      shopId: shopId ?? this.shopId,
      mediaType: mediaType ?? this.mediaType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      mediaPath: mediaPath ?? this.mediaPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      status: status ?? this.status,
      caption: caption ?? this.caption,
      captionEn: captionEn ?? this.captionEn,
      captionAr: captionAr ?? this.captionAr,
      category: category ?? this.category,
      isFeatured: isFeatured ?? this.isFeatured,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String displayCaption(String languageCode) {
    final isAr = languageCode.toLowerCase().startsWith('ar');
    final v = isAr ? (captionAr ?? '') : (captionEn ?? '');
    if (v.trim().isNotEmpty) return v;
    if ((caption ?? '').trim().isNotEmpty) return caption!.trim();
    return (isAr ? (captionEn ?? '') : (captionAr ?? '')).trim();
  }

  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    final ownerType = (json['owner_type'] as String?) ?? (json['barber_id'] != null ? 'barber' : 'shop');
    final ownerId = (json['owner_id'] as String?) ?? (json['barber_id'] as String?) ?? (json['shop_id'] as String?) ?? '';
    return PortfolioItem(
      id: json['id'] as String,
      ownerType: ownerType,
      ownerId: ownerId,
      barberId: json['barber_id'] as String?,
      shopId: json['shop_id'] as String?,
      mediaType: (json['media_type'] as String?) ?? 'image',
      mediaUrl: (json['media_url'] as String?) ?? (json['image_url'] as String?) ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      imageUrl: json['image_url'] as String?,
      mediaPath: json['media_path'] as String?,
      thumbnailPath: json['thumbnail_path'] as String?,
      status: (json['status'] as String?) ?? 'approved',
      caption: json['caption'] as String?,
      captionEn: json['caption_en'] as String?,
      captionAr: json['caption_ar'] as String?,
      category: json['category'] as String?,
      isFeatured: (json['is_featured'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

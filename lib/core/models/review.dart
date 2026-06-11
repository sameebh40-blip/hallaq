class Review {
  final String id;
  final String customerId;
  final String? shopId;
  final String? barberId;
  final int rating;
  final String? comment;
  final String? imageUrl;
  final String? imagePath;
  final bool isVerified;
  final String? replyText;
  final DateTime? repliedAt;
  final String? customerName;
  final String? customerAvatarUrl;
  final String? customerAvatarPath;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.customerId,
    required this.shopId,
    required this.barberId,
    required this.rating,
    required this.createdAt,
    this.comment,
    this.imageUrl,
    this.imagePath,
    this.isVerified = false,
    this.replyText,
    this.repliedAt,
    this.customerName,
    this.customerAvatarUrl,
    this.customerAvatarPath,
  });

  Review copyWith({
    String? id,
    String? customerId,
    String? shopId,
    String? barberId,
    int? rating,
    String? comment,
    String? imageUrl,
    String? imagePath,
    bool? isVerified,
    String? replyText,
    DateTime? repliedAt,
    String? customerName,
    String? customerAvatarUrl,
    String? customerAvatarPath,
    DateTime? createdAt,
  }) {
    return Review(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      shopId: shopId ?? this.shopId,
      barberId: barberId ?? this.barberId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      isVerified: isVerified ?? this.isVerified,
      replyText: replyText ?? this.replyText,
      repliedAt: repliedAt ?? this.repliedAt,
      customerName: customerName ?? this.customerName,
      customerAvatarUrl: customerAvatarUrl ?? this.customerAvatarUrl,
      customerAvatarPath: customerAvatarPath ?? this.customerAvatarPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    final customerId = (json['customer_id'] as String?) ?? (json['customer_profile_id'] as String?) ?? '';
    final barberId = json['barber_id'] as String?;
    final shopId = json['shop_id'] as String?;

    final profile = json['profiles'];
    String? customerName;
    String? customerAvatarUrl;
    String? customerAvatarPath;
    if (profile is Map) {
      customerName = profile['full_name'] as String?;
      customerAvatarUrl = profile['avatar_url'] as String?;
      customerAvatarPath = profile['avatar_path'] as String?;
    }

    return Review(
      id: json['id'] as String,
      customerId: customerId,
      shopId: shopId,
      barberId: barberId,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: (json['comment'] as String?) ?? (json['text'] as String?),
      imageUrl: (json['image_url'] as String?) ?? (json['photo_url'] as String?),
      imagePath: json['image_path'] as String?,
      isVerified: (json['is_verified'] as bool?) ?? false,
      replyText: json['reply_text'] as String?,
      repliedAt: json['replied_at'] != null ? DateTime.tryParse(json['replied_at'] as String) : null,
      customerName: customerName,
      customerAvatarUrl: customerAvatarUrl,
      customerAvatarPath: customerAvatarPath,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

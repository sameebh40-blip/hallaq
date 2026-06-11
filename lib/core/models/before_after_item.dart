class BeforeAfterItem {
  final String id;
  final String? barberId;
  final String? shopId;
  final String beforeImageUrl;
  final String afterImageUrl;
  final String? beforeImagePath;
  final String? afterImagePath;
  final String? caption;
  final String? category;
  final DateTime createdAt;

  const BeforeAfterItem({
    required this.id,
    required this.beforeImageUrl,
    required this.afterImageUrl,
    required this.createdAt,
    this.barberId,
    this.shopId,
    this.beforeImagePath,
    this.afterImagePath,
    this.caption,
    this.category,
  });

  factory BeforeAfterItem.fromJson(Map<String, dynamic> json) {
    return BeforeAfterItem(
      id: json['id'] as String,
      barberId: json['barber_id'] as String?,
      shopId: json['shop_id'] as String?,
      beforeImagePath: json['before_image_path'] as String?,
      afterImagePath: json['after_image_path'] as String?,
      beforeImageUrl: (json['before_image_url'] as String?) ?? '',
      afterImageUrl: (json['after_image_url'] as String?) ?? '',
      caption: json['caption'] as String?,
      category: json['category'] as String?,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}


class Offer {
  final String id;
  final String? shopId;
  final String? barberId;
  final String title;
  final String? description;
  final String offerType;
  final double? discountPercent;
  final double? discountAmount;
  final Map<String, dynamic> packageDetails;
  final DateTime? validFrom;
  final DateTime? validTo;
  final bool active;
  final String? bannerUrl;
  final String? bannerPath;
  final DateTime createdAt;

  const Offer({
    required this.id,
    required this.title,
    required this.active,
    required this.createdAt,
    this.shopId,
    this.barberId,
    this.description,
    this.offerType = 'percentage',
    this.discountPercent,
    this.discountAmount,
    this.packageDetails = const {},
    this.validFrom,
    this.validTo,
    this.bannerUrl,
    this.bannerPath,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    final pkg = json['package_details'];
    return Offer(
      id: json['id'] as String,
      shopId: json['shop_id'] as String?,
      barberId: json['barber_id'] as String?,
      title: (json['title'] as String?) ?? '',
      description: json['description'] as String?,
      offerType: (json['offer_type'] as String?) ?? 'percentage',
      discountPercent: (json['discount_percent'] as num?)?.toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble(),
      packageDetails: pkg is Map ? Map<String, dynamic>.from(pkg) : const <String, dynamic>{},
      validFrom: json['valid_from'] == null ? null : DateTime.parse(json['valid_from'] as String),
      validTo: json['valid_to'] == null ? null : DateTime.parse(json['valid_to'] as String),
      active: (json['active'] as bool?) ?? true,
      bannerUrl: json['banner_url'] as String?,
      bannerPath: json['banner_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

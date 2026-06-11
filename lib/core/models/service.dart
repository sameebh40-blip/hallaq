class Service {
  final String id;
  final String? shopId;
  final String? barberId;
  final String nameEn;
  final String nameAr;
  final String descriptionEn;
  final String descriptionAr;
  final double priceBhd;
  final int durationMinutes;
  final String? imageUrl;
  final String? category;
  final bool isPopular;
  final bool isActive;
  final DateTime? createdAt;

  const Service({
    required this.id,
    required this.shopId,
    required this.barberId,
    required this.nameEn,
    required this.nameAr,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.priceBhd,
    required this.durationMinutes,
    required this.imageUrl,
    required this.category,
    required this.isPopular,
    required this.isActive,
    required this.createdAt,
  });

  String displayName(String languageCode) {
    final isAr = languageCode.toLowerCase().startsWith('ar');
    final name = isAr ? nameAr : nameEn;
    if (name.trim().isNotEmpty) return name;
    return (isAr ? nameEn : nameAr).trim().isNotEmpty ? (isAr ? nameEn : nameAr) : nameEn;
  }

  String displayDescription(String languageCode) {
    final isAr = languageCode.toLowerCase().startsWith('ar');
    final d = isAr ? descriptionAr : descriptionEn;
    if (d.trim().isNotEmpty) return d;
    return (isAr ? descriptionEn : descriptionAr).trim().isNotEmpty ? (isAr ? descriptionEn : descriptionAr) : descriptionEn;
  }

  String get name => nameEn;
  int get durationMin => durationMinutes;
  double get price => priceBhd;
  bool get active => isActive;

  factory Service.fromJson(Map<String, dynamic> json) {
    final rawShopId = json['shop_id'];
    final rawBarberId = json['barber_id'];
    final legacyOwnerType = json['owner_type'] as String?;
    final legacyOwnerId = json['owner_id'];

    String? shopId;
    String? barberId;
    if (rawShopId is String) shopId = rawShopId;
    if (rawBarberId is String) barberId = rawBarberId;
    if (shopId == null && legacyOwnerType == 'shop' && legacyOwnerId is String) shopId = legacyOwnerId;
    if (barberId == null && legacyOwnerType == 'barber' && legacyOwnerId is String) barberId = legacyOwnerId;

    final nameEn = (json['name_en'] as String?) ?? (json['name'] as String?) ?? '';
    final nameAr = (json['name_ar'] as String?) ?? '';
    final descriptionEn = (json['description_en'] as String?) ?? (json['description'] as String?) ?? '';
    final descriptionAr = (json['description_ar'] as String?) ?? '';

    final priceBhd = ((json['price_bhd'] as num?) ?? (json['price'] as num?) ?? 0).toDouble();
    final durationMinutes = ((json['duration_minutes'] as num?) ?? (json['duration_min'] as num?) ?? 30).toInt();
    final isPopular = (json['is_popular'] as bool?) ?? false;
    final isActive = (json['is_active'] as bool?) ?? (json['active'] as bool?) ?? true;

    DateTime? createdAt;
    final rawCreatedAt = json['created_at'];
    if (rawCreatedAt is String && rawCreatedAt.isNotEmpty) {
      createdAt = DateTime.tryParse(rawCreatedAt);
    }

    return Service(
      id: json['id'] as String,
      shopId: shopId,
      barberId: barberId,
      nameEn: nameEn,
      nameAr: nameAr,
      descriptionEn: descriptionEn,
      descriptionAr: descriptionAr,
      priceBhd: priceBhd,
      durationMinutes: durationMinutes,
      imageUrl: json['image_url'] as String?,
      category: json['category'] as String?,
      isPopular: isPopular,
      isActive: isActive,
      createdAt: createdAt,
    );
  }
}

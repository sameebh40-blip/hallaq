class Category {
  final String id;
  final String nameEn;
  final String nameAr;

  const Category({
    required this.id,
    required this.nameEn,
    required this.nameAr,
  });

  String displayName(String languageCode) {
    final isAr = languageCode.toLowerCase().startsWith('ar');
    final primary = (isAr ? nameAr : nameEn).trim();
    if (primary.isNotEmpty) return primary;
    final fallback = (isAr ? nameEn : nameAr).trim();
    return fallback.isNotEmpty ? fallback : nameEn;
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      nameEn: (json['name_en'] as String?) ?? '',
      nameAr: (json['name_ar'] as String?) ?? '',
    );
  }
}


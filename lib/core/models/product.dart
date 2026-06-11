class Product {
  final String id;
  final String shopId;
  final String name;
  final String? description;
  final double price;
  final String currency;
  final int stock;
  final String? imageUrl;
  final List<String> images;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.shopId,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.stock,
    required this.imageUrl,
    required this.images,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['id'] as String?) ?? '',
      shopId: (json['shop_id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: (json['currency'] as String?) ?? 'BHD',
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url'] as String?,
      images: _parseImages(json['images']),
      active: (json['active'] as bool?) ?? true,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  static List<String> _parseImages(dynamic value) {
    if (value is List) {
      return value.where((e) => e != null).map((e) => e.toString()).toList();
    }
    return const <String>[];
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

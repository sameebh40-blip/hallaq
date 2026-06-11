class Customer {
  final String id;
  final String fullName;
  final String phone;
  final String email;
  final String language;
  final int loyaltyPoints;
  final DateTime createdAt;

  const Customer({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.language,
    required this.loyaltyPoints,
    required this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      fullName: (json['full_name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      language: (json['language'] as String?) ?? 'en',
      loyaltyPoints: (json['loyalty_points'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'language': language,
      'loyalty_points': loyaltyPoints,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

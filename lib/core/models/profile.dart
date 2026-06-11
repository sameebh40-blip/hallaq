import 'role.dart';

class UserProfile {
  final String id;
  final String? fullName;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final String? coverUrl;
  final String? avatarPath;
  final String? coverPath;
  final String? myBarberId;
  final AppUserRole role;
  final bool verified;
  final String? bio;
  final String? location;
  final String? membershipTier;
  final String? area;
  final double? lat;
  final double? lng;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.role,
    required this.verified,
    required this.createdAt,
    required this.updatedAt,
    this.fullName,
    this.phone,
    this.email,
    this.avatarUrl,
    this.coverUrl,
    this.avatarPath,
    this.coverPath,
    this.myBarberId,
    this.bio,
    this.location,
    this.membershipTier,
    this.area,
    this.lat,
    this.lng,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      avatarPath: json['avatar_path'] as String?,
      coverPath: json['cover_path'] as String?,
      myBarberId: json['my_barber_id'] as String?,
      role: AppUserRole.fromDb(json['role'] as String?),
      verified: (json['verified'] as bool?) ?? false,
      bio: json['bio'] as String?,
      location: json['location'] as String?,
      membershipTier: json['membership_tier'] as String?,
      area: json['area'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'avatar_url': avatarUrl,
      'cover_url': coverUrl,
      'avatar_path': avatarPath,
      'cover_path': coverPath,
      'my_barber_id': myBarberId,
      'role': role.toDb(),
      'verified': verified,
      'bio': bio,
      'location': location,
      'membership_tier': membershipTier,
      'area': area,
      'lat': lat,
      'lng': lng,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? fullName,
    String? phone,
    String? email,
    String? avatarUrl,
    String? coverUrl,
    String? avatarPath,
    String? coverPath,
    String? myBarberId,
    AppUserRole? role,
    bool? verified,
    String? bio,
    String? location,
    String? membershipTier,
    String? area,
    double? lat,
    double? lng,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      avatarPath: avatarPath ?? this.avatarPath,
      coverPath: coverPath ?? this.coverPath,
      myBarberId: myBarberId ?? this.myBarberId,
      role: role ?? this.role,
      verified: verified ?? this.verified,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      membershipTier: membershipTier ?? this.membershipTier,
      area: area ?? this.area,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

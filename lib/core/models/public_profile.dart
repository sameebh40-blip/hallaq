class PublicProfile {
  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String? area;

  const PublicProfile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.area,
  });
}


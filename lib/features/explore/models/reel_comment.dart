class ReelComment {
  final String id;
  final String reelId;
  final String profileId;
  final String? authorName;
  final String? authorAvatarUrl;
  final String text;
  final DateTime createdAt;

  const ReelComment({
    required this.id,
    required this.reelId,
    required this.profileId,
    required this.text,
    required this.createdAt,
    this.authorName,
    this.authorAvatarUrl,
  });

  factory ReelComment.fromJson(Map<String, dynamic> json) {
    final p = json['profiles'] as Map<String, dynamic>?;
    return ReelComment(
      id: json['id'] as String,
      reelId: json['reel_id'] as String,
      profileId: json['profile_id'] as String,
      text: (json['text'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      authorName: p?['full_name'] as String?,
      authorAvatarUrl: p?['avatar_url'] as String?,
    );
  }
}

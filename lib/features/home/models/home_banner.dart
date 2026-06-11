class HomeBanner {
  final String id;
  final String title;
  final String? imageUrl;
  final String? linkUrl;

  const HomeBanner({
    required this.id,
    required this.title,
    this.imageUrl,
    this.linkUrl,
  });

  factory HomeBanner.fromJson(Map<String, dynamic> json) {
    return HomeBanner(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      imageUrl: json['image_url'] as String?,
      linkUrl: json['link_url'] as String?,
    );
  }
}


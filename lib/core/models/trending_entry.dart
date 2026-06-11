class TrendingEntry {
  final String kind;
  final String entityType;
  final String entityId;
  final int score;

  const TrendingEntry({
    required this.kind,
    required this.entityType,
    required this.entityId,
    required this.score,
  });

  factory TrendingEntry.fromJson(Map<String, dynamic> json) {
    return TrendingEntry(
      kind: (json['kind'] as String?) ?? '',
      entityType: (json['entity_type'] as String?) ?? '',
      entityId: (json['entity_id'] as String?) ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
    );
  }
}


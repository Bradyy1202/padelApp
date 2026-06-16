// Modelos de ranking y evolución de rating (espejo del backend §11.3).

class RankingEntry {
  final int rank;
  final String playerId;
  final String fullName;
  final String? city;
  final double rating;
  final int confidence;
  final String state;

  const RankingEntry({
    required this.rank,
    required this.playerId,
    required this.fullName,
    required this.rating,
    required this.confidence,
    required this.state,
    this.city,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> j) => RankingEntry(
        rank: j['rank'] as int,
        playerId: j['playerId'] as String,
        fullName: j['fullName'] as String,
        city: j['city'] as String?,
        rating: (j['rating'] as num).toDouble(),
        confidence: j['confidence'] as int,
        state: j['state'] as String,
      );
}

class RatingPoint {
  final double? ratingAfter;
  final double? delta;
  final DateTime createdAt;

  const RatingPoint({required this.createdAt, this.ratingAfter, this.delta});

  factory RatingPoint.fromJson(Map<String, dynamic> j) => RatingPoint(
        ratingAfter: (j['ratingAfter'] as num?)?.toDouble(),
        delta: (j['delta'] as num?)?.toDouble(),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

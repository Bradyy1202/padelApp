// Modelos de dominio de identidad/perfil (espejo de las respuestas del backend §11.1).

class RatingSummary {
  final double rating;
  final int confidence;
  final String state;

  const RatingSummary({required this.rating, required this.confidence, required this.state});

  factory RatingSummary.fromJson(Map<String, dynamic> j) => RatingSummary(
        rating: (j['rating'] as num).toDouble(),
        confidence: j['confidence'] as int,
        state: j['state'] as String,
      );
}

class Player {
  final String id;
  final String fullName;
  final String? photoUrl;
  final String? city;
  final String? clubId;
  final String? dominantHand;
  final String? favSide;
  final String? gender;
  final String status;
  final double? estLevel;
  final RatingSummary? rating;

  const Player({
    required this.id,
    required this.fullName,
    required this.status,
    this.photoUrl,
    this.city,
    this.clubId,
    this.dominantHand,
    this.favSide,
    this.gender,
    this.estLevel,
    this.rating,
  });

  factory Player.fromJson(Map<String, dynamic> j) => Player(
        id: j['id'] as String,
        fullName: j['fullName'] as String,
        status: j['status'] as String,
        photoUrl: j['photoUrl'] as String?,
        city: j['city'] as String?,
        clubId: j['clubId'] as String?,
        dominantHand: j['dominantHand'] as String?,
        favSide: j['favSide'] as String?,
        gender: j['gender'] as String?,
        estLevel: (j['estLevel'] as num?)?.toDouble(),
        rating: j['rating'] == null
            ? null
            : RatingSummary.fromJson(j['rating'] as Map<String, dynamic>),
      );
}

class Me {
  final String userId;
  final String role;
  final bool onboarded;
  final Player? player;

  const Me({
    required this.userId,
    required this.role,
    required this.onboarded,
    this.player,
  });

  bool get isAdmin => role == 'administrador';

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        userId: j['userId'] as String,
        role: (j['role'] as String?) ?? 'jugador',
        onboarded: j['onboarded'] as bool,
        player: j['player'] == null ? null : Player.fromJson(j['player'] as Map<String, dynamic>),
      );
}

class GuestSuggestion {
  final String id;
  final String fullName;
  final String? city;
  final double similarity;

  const GuestSuggestion({
    required this.id,
    required this.fullName,
    required this.similarity,
    this.city,
  });

  factory GuestSuggestion.fromJson(Map<String, dynamic> j) => GuestSuggestion(
        id: j['id'] as String,
        fullName: j['fullName'] as String,
        city: j['city'] as String?,
        similarity: (j['similarity'] as num).toDouble(),
      );
}

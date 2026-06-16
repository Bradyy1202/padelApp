// Modelos de dominio de partidos (espejo de las respuestas del backend §11.2).

class MatchPlayerRef {
  final String id;
  final String fullName;
  final String status;
  const MatchPlayerRef({required this.id, required this.fullName, required this.status});

  factory MatchPlayerRef.fromJson(Map<String, dynamic> j) => MatchPlayerRef(
        id: j['id'] as String,
        fullName: j['fullName'] as String,
        status: j['status'] as String,
      );
}

class MatchTeam {
  final int side;
  final List<MatchPlayerRef> players;
  const MatchTeam({required this.side, required this.players});

  factory MatchTeam.fromJson(Map<String, dynamic> j) => MatchTeam(
        side: j['side'] as int,
        players: (j['players'] as List<dynamic>)
            .map((e) => MatchPlayerRef.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class MatchSet {
  final int setNo;
  final int games1;
  final int games2;
  const MatchSet({required this.setNo, required this.games1, required this.games2});

  factory MatchSet.fromJson(Map<String, dynamic> j) => MatchSet(
        setNo: j['setNo'] as int,
        games1: j['games1'] as int,
        games2: j['games2'] as int,
      );
}

class MatchResult {
  final int winnerSide;
  final int gamesDiff;
  const MatchResult({required this.winnerSide, required this.gamesDiff});

  factory MatchResult.fromJson(Map<String, dynamic> j) =>
      MatchResult(winnerSide: j['winnerSide'] as int, gamesDiff: j['gamesDiff'] as int);
}

class MatchDetail {
  final String id;
  final String type;
  final String status;
  final int bestOf;
  final String createdBy;
  final List<MatchTeam> teams;
  final List<MatchSet> sets;
  final MatchResult? result;

  const MatchDetail({
    required this.id,
    required this.type,
    required this.status,
    required this.bestOf,
    required this.createdBy,
    required this.teams,
    required this.sets,
    this.result,
  });

  factory MatchDetail.fromJson(Map<String, dynamic> j) => MatchDetail(
        id: j['id'] as String,
        type: j['type'] as String,
        status: j['status'] as String,
        bestOf: j['bestOf'] as int,
        createdBy: j['createdBy'] as String,
        teams: (j['teams'] as List<dynamic>)
            .map((e) => MatchTeam.fromJson(e as Map<String, dynamic>))
            .toList(),
        sets: (j['sets'] as List<dynamic>)
            .map((e) => MatchSet.fromJson(e as Map<String, dynamic>))
            .toList(),
        result: j['result'] == null
            ? null
            : MatchResult.fromJson(j['result'] as Map<String, dynamic>),
      );

  int get playerCount => teams.fold(0, (sum, t) => sum + t.players.length);
}

class QrInfo {
  final String token;
  final String shortCode;
  const QrInfo({required this.token, required this.shortCode});

  factory QrInfo.fromJson(Map<String, dynamic> j) =>
      QrInfo(token: j['token'] as String, shortCode: j['shortCode'] as String);
}

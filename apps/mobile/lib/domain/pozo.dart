// Modelos de pozos (espejo del backend §11.4).

class PozoSummary {
  final String id;
  final String name;
  final String mode;
  final String status;
  final int participants;
  final bool isOwner;

  const PozoSummary({
    required this.id,
    required this.name,
    required this.mode,
    required this.status,
    required this.participants,
    required this.isOwner,
  });

  factory PozoSummary.fromJson(Map<String, dynamic> j) => PozoSummary(
        id: j['id'] as String,
        name: j['name'] as String,
        mode: j['mode'] as String,
        status: j['status'] as String,
        participants: j['participants'] as int,
        isOwner: j['isOwner'] as bool,
      );
}

class PozoStandingRow {
  final int rank;
  final String fullName;
  final int wins;
  final int losses;
  final int gamesDiff;

  const PozoStandingRow({
    required this.rank,
    required this.fullName,
    required this.wins,
    required this.losses,
    required this.gamesDiff,
  });

  factory PozoStandingRow.fromJson(Map<String, dynamic> j) => PozoStandingRow(
        rank: j['rank'] as int,
        fullName: j['fullName'] as String,
        wins: j['wins'] as int,
        losses: j['losses'] as int,
        gamesDiff: j['gamesDiff'] as int,
      );
}

class PozoMatchView {
  final String pozoMatchId;
  final int? court;
  final String? status;
  final List<List<String>> teams; // [side1 names, side2 names]
  final List<List<int>> sets; // [[g1,g2], ...]
  final int? winnerSide;

  const PozoMatchView({
    required this.pozoMatchId,
    required this.teams,
    required this.sets,
    this.court,
    this.status,
    this.winnerSide,
  });

  bool get hasResult => winnerSide != null;

  factory PozoMatchView.fromJson(Map<String, dynamic> j) => PozoMatchView(
        pozoMatchId: j['pozoMatchId'] as String,
        court: j['court'] as int?,
        status: j['status'] as String?,
        teams: (j['teams'] as List<dynamic>)
            .map((t) => ((t as Map)['players'] as List<dynamic>).cast<String>())
            .toList(),
        sets: (j['sets'] as List<dynamic>)
            .map((s) => [(s as Map)['games1'] as int, s['games2'] as int])
            .toList(),
        winnerSide: j['result'] == null ? null : (j['result'] as Map)['winnerSide'] as int?,
      );
}

class PozoRoundView {
  final int roundNo;
  final List<PozoMatchView> matches;
  const PozoRoundView({required this.roundNo, required this.matches});

  factory PozoRoundView.fromJson(Map<String, dynamic> j) => PozoRoundView(
        roundNo: j['roundNo'] as int,
        matches: (j['matches'] as List<dynamic>)
            .map((m) => PozoMatchView.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

class PozoDetail {
  final String id;
  final String name;
  final String mode;
  final String status;
  final List<PozoRoundView> rounds;
  final List<PozoStandingRow> standings;

  const PozoDetail({
    required this.id,
    required this.name,
    required this.mode,
    required this.status,
    required this.rounds,
    required this.standings,
  });

  factory PozoDetail.fromJson(Map<String, dynamic> j) => PozoDetail(
        id: j['id'] as String,
        name: j['name'] as String,
        mode: j['mode'] as String,
        status: j['status'] as String,
        rounds: (j['rounds'] as List<dynamic>)
            .map((r) => PozoRoundView.fromJson(r as Map<String, dynamic>))
            .toList(),
        standings: (j['standings'] as List<dynamic>)
            .map((s) => PozoStandingRow.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../domain/match.dart';

/// Lista de partidos del usuario (/me/matches).
final myMatchesProvider = FutureProvider<List<MatchDetail>>((ref) async {
  return ref.watch(apiClientProvider).listMyMatches();
});

/// Detalle de un partido por id.
final matchProvider =
    FutureProvider.family<MatchDetail, String>((ref, id) async {
  return ref.watch(apiClientProvider).getMatch(id);
});

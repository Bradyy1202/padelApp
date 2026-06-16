import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_client.dart';
import '../domain/player.dart';
import '../domain/match.dart';
import '../domain/ranking.dart';

/// Cliente del API de negocio (NestJS §11.1).
class ApiClient {
  ApiClient(this._dio);
  final Dio _dio;

  Future<Me> getMe() async {
    final res = await _dio.get<Map<String, dynamic>>('/me');
    return Me.fromJson(res.data!);
  }

  Future<Player> completeOnboarding(Map<String, dynamic> body) async {
    final res = await _dio.post<Map<String, dynamic>>('/me/onboarding', data: body);
    return Player.fromJson(res.data!);
  }

  Future<Player> updateMe(Map<String, dynamic> body) async {
    final res = await _dio.patch<Map<String, dynamic>>('/me', data: body);
    return Player.fromJson(res.data!);
  }

  Future<void> deleteAccount() => _dio.delete('/me');

  Future<Player> createGuest(Map<String, dynamic> body) async {
    final res = await _dio.post<Map<String, dynamic>>('/players/guest', data: body);
    return Player.fromJson(res.data!);
  }

  Future<List<GuestSuggestion>> guestSuggestions({String? name}) async {
    final res = await _dio.get<List<dynamic>>(
      '/players/guest/suggestions',
      queryParameters: name == null ? null : {'name': name},
    );
    return (res.data ?? [])
        .map((e) => GuestSuggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Me> claimGuest(String guestId) async {
    final res = await _dio.post<Map<String, dynamic>>('/players/$guestId/claim');
    return Me.fromJson(res.data!);
  }

  // ── Partidos (§11.2) ──────────────────────────────────────────
  Future<MatchDetail> createMatch({required String type, int bestOf = 3}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/matches',
      data: {'type': type, 'bestOf': bestOf},
    );
    return MatchDetail.fromJson(res.data!);
  }

  Future<MatchDetail> getMatch(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/matches/$id');
    return MatchDetail.fromJson(res.data!);
  }

  Future<QrInfo> generateQr(String matchId) async {
    final res = await _dio.post<Map<String, dynamic>>('/matches/$matchId/qr');
    return QrInfo.fromJson(res.data!);
  }

  Future<MatchDetail> joinByCode(String shortCode, int side) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/matches/join',
      data: {'shortCode': shortCode, 'side': side},
    );
    return MatchDetail.fromJson(res.data!);
  }

  Future<MatchDetail> addGuest(String matchId, int side, String guestName) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/matches/$matchId/players',
      data: {'side': side, 'guestName': guestName},
    );
    return MatchDetail.fromJson(res.data!);
  }

  Future<MatchDetail> registerResult(String matchId, List<Map<String, int>> sets) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/matches/$matchId/result',
      data: {'sets': sets},
    );
    return MatchDetail.fromJson(res.data!);
  }

  Future<MatchDetail> confirmMatch(String matchId) async {
    final res = await _dio.post<Map<String, dynamic>>('/matches/$matchId/confirm');
    return MatchDetail.fromJson(res.data!);
  }

  Future<MatchDetail> disputeMatch(String matchId) async {
    final res = await _dio.post<Map<String, dynamic>>('/matches/$matchId/dispute');
    return MatchDetail.fromJson(res.data!);
  }

  Future<List<MatchDetail>> listMyMatches() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/matches');
    final data = (res.data!['data'] as List<dynamic>);
    return data.map((e) => MatchDetail.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Rankings / rating (§11.3) ─────────────────────────────────
  Future<List<RankingEntry>> getRankings({
    String scope = 'global',
    String? value,
    bool includeProvisional = true,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>('/rankings', queryParameters: {
      'scope': scope,
      'value': ?value,
      'includeProvisional': includeProvisional,
    });
    final data = (res.data!['data'] as List<dynamic>);
    return data.map((e) => RankingEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<RatingPoint>> getRatingHistory(String playerId) async {
    final res = await _dio.get<List<dynamic>>('/players/$playerId/rating/history');
    return (res.data ?? []).map((e) => RatingPoint.fromJson(e as Map<String, dynamic>)).toList();
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(dioProvider)));

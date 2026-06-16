import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_client.dart';
import '../domain/player.dart';

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
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(dioProvider)));

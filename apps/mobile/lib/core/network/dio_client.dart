import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../storage/secure_storage.dart';

/// Cliente HTTP (Dio) con interceptores (PRD §9.3):
/// - Adjunta el Bearer token de Supabase a cada petición.
/// - Maneja 401 (en sprints posteriores: refresh de token y reintento).
class DioClient {
  DioClient(this._storage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // TODO(sprint1): en 401, intentar refresh de sesión Supabase y reintentar.
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  final SecureStorage _storage;

  Dio get dio => _dio;
}

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(ref.watch(secureStorageProvider));
});

final dioProvider = Provider<Dio>((ref) => ref.watch(dioClientProvider).dio);

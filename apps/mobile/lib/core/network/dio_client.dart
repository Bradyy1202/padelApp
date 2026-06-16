import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../../state/auth_controller.dart';

/// Cliente HTTP (Dio) con interceptores (PRD §9.3):
/// - Adjunta el Bearer token de Supabase, o el header de dev si la sesión es de desarrollo.
/// - Maneja 401 (en sprints posteriores: refresh de token y reintento).
class DioClient {
  DioClient(this._ref) {
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
        onRequest: (options, handler) {
          final session = _ref.read(authControllerProvider);
          if (session != null) {
            if (session.accessToken != null) {
              options.headers['Authorization'] = 'Bearer ${session.accessToken}';
            } else if (session.isDev) {
              options.headers['x-dev-user-id'] = session.userId;
            }
          }
          handler.next(options);
        },
      ),
    );
  }

  final Ref _ref;
  late final Dio _dio;

  Dio get dio => _dio;
}

final dioClientProvider = Provider<DioClient>((ref) => DioClient(ref));
final dioProvider = Provider<Dio>((ref) => ref.watch(dioClientProvider).dio);

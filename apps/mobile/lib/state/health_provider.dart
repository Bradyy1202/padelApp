import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_client.dart';

/// Consulta GET /health del backend NestJS. Provider de ejemplo de Sprint 0
/// que ejercita la capa de red (Dio). Se elimina/expande en sprints siguientes.
final healthProvider = FutureProvider<String>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get<Map<String, dynamic>>('/health');
  final status = res.data?['status']?.toString() ?? 'unknown';
  return status;
});

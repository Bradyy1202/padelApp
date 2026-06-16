import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../domain/player.dart';
import 'auth_controller.dart';

/// Carga el perfil del usuario autenticado (/me). Se recalcula al cambiar la sesión.
final meProvider = FutureProvider<Me?>((ref) async {
  final session = ref.watch(authControllerProvider);
  if (session == null) return null;
  return ref.watch(apiClientProvider).getMe();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../domain/notification.dart';
import 'auth_controller.dart';

/// Notificaciones in-app del usuario (/me/notifications).
final notificationsProvider = FutureProvider<NotificationsPage>((ref) async {
  final session = ref.watch(authControllerProvider);
  if (session == null) return const NotificationsPage(data: [], unread: 0);
  return ref.watch(apiClientProvider).getNotifications();
});

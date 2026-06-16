import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api_client.dart';
import '../../domain/notification.dart';
import '../../state/notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: notifs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (page) {
          if (page.data.isEmpty) {
            return const Center(child: Text('No tienes notificaciones'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.separated(
              itemCount: page.data.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _tile(context, ref, page.data[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, AppNotification n) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: n.isRead
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.primaryContainer,
        child: Icon(_icon(n.type), color: theme.colorScheme.onPrimaryContainer, size: 20),
      ),
      title: Text(n.title,
          style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600)),
      trailing: n.isRead ? null : const Icon(Icons.circle, size: 10, color: Colors.blue),
      onTap: () async {
        if (!n.isRead) {
          await ref.read(apiClientProvider).markNotificationRead(n.id);
          ref.invalidate(notificationsProvider);
        }
        final matchId = n.payload?['matchId'] as String?;
        if (matchId != null && context.mounted) context.push('/matches/$matchId');
      },
    );
  }

  IconData _icon(String? type) => switch (type) {
        'MATCH_RESULT_PENDING' => Icons.how_to_vote,
        'MATCH_CONFIRMED' => Icons.verified,
        'MATCH_DISPUTED' => Icons.flag,
        'MATCH_DISCARDED' => Icons.cancel,
        _ => Icons.notifications,
      };
}

// Notificación in-app (espejo del backend §14).

class AppNotification {
  final String id;
  final String? type;
  final Map<String, dynamic>? payload;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.createdAt,
    this.type,
    this.payload,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        type: j['type'] as String?,
        payload: j['payload'] as Map<String, dynamic>?,
        readAt: j['readAt'] == null ? null : DateTime.parse(j['readAt'] as String),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  /// Texto legible por tipo de evento.
  String get title => switch (type) {
        'MATCH_RESULT_PENDING' => 'Tienes un resultado por confirmar',
        'MATCH_CONFIRMED' => 'Un partido fue confirmado — rating actualizado',
        'MATCH_DISPUTED' => 'Un partido fue disputado',
        'MATCH_DISCARDED' => 'Un partido fue descartado',
        _ => type ?? 'Notificación',
      };
}

class NotificationsPage {
  final List<AppNotification> data;
  final int unread;
  const NotificationsPage({required this.data, required this.unread});

  factory NotificationsPage.fromJson(Map<String, dynamic> j) => NotificationsPage(
        data: (j['data'] as List<dynamic>)
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList(),
        unread: j['unread'] as int,
      );
}

import 'post_author.dart';

/// Notificación del centro de actividad (`serializeNotification` del backend).
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.timeAgo,
    required this.createdAt,
    this.actor,
    this.targetType,
    this.targetId,
    this.text,
    this.readAt,
  });

  final String id;
  final String type;
  final PostAuthor? actor;
  final String? targetType;
  final String? targetId;
  final String? text;
  final String? readAt;
  final String timeAgo;
  final String createdAt;

  bool get isRead => readAt != null;
  bool get isMention => type == 'MENTION';

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final actorJson = json['actor'];
    return NotificationItem(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      actor: actorJson is Map<String, dynamic>
          ? PostAuthor.fromJson(actorJson)
          : null,
      targetType: json['targetType'] as String?,
      targetId: json['targetId'] as String?,
      text: json['text'] as String?,
      readAt: json['readAt'] as String?,
      timeAgo: json['timeAgo'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    if (actor != null) 'actor': actor!.toJson(),
    if (targetType != null) 'targetType': targetType,
    if (targetId != null) 'targetId': targetId,
    if (text != null) 'text': text,
    if (readAt != null) 'readAt': readAt,
    'timeAgo': timeAgo,
    'createdAt': createdAt,
  };
}

/// Respuesta paginada de notificaciones (GET /notifications).
class NotificationPage {
  const NotificationPage({
    required this.items,
    this.total = 0,
    this.page = 1,
    this.pages = 1,
    this.unread = 0,
  });

  final List<NotificationItem> items;
  final int total;
  final int page;
  final int pages;
  final int unread;

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    return NotificationPage(
      items: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(NotificationItem.fromJson)
                .toList()
          : const [],
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
      unread: (json['unread'] as num?)?.toInt() ?? 0,
    );
  }
}

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'base_socket.dart';

/// Evento de notificación recibido por socket.
sealed class NotificationEvent {}

class NotificationReceived extends NotificationEvent {
  NotificationReceived({
    required this.id,
    required this.type,
    required this.content,
    this.targetType,
    this.targetId,
    this.actorId,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String content;
  final String? targetType;
  final String? targetId;
  final String? actorId;
  final String createdAt;

  factory NotificationReceived.fromJson(Map<String, dynamic> json) {
    return NotificationReceived(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      content: json['content'] as String? ?? json['text'] as String? ?? '',
      targetType: json['targetType'] as String?,
      targetId: json['targetId'] as String?,
      actorId: json['actorId'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

/// Evento `user:sanctioned` — el staff aplicó una sanción a esta cuenta.
/// Backend payload: `{ type: action, reason, expiresAt?, moderatorId, timestamp }`
class UserSanctioned extends NotificationEvent {
  UserSanctioned({
    required this.action,
    required this.reason,
    this.expiresAt,
    this.moderatorId,
  });

  /// 'WARN' | 'MUTE' | 'SUSPEND' | 'BAN'
  final String action;
  final String reason;
  final DateTime? expiresAt;
  final String? moderatorId;

  bool get isSessionKilling => action == 'SUSPEND' || action == 'BAN';

  factory UserSanctioned.fromJson(Map<String, dynamic> json) {
    final rawExpiry =
        (json['expiresAt'] ?? json['suspendedUntil']) as String?;
    return UserSanctioned(
      action:
          (json['type'] as String?) ?? (json['action'] as String?) ?? 'WARN',
      reason: (json['reason'] as String?)?.trim().isNotEmpty == true
          ? json['reason'] as String
          : 'Actividad contra las normas de la comunidad',
      expiresAt: rawExpiry != null ? DateTime.tryParse(rawExpiry) : null,
      moderatorId: json['moderatorId'] as String?,
    );
  }
}

/// Cliente Socket.IO para notificaciones en tiempo real.
class NotificationSocketService extends BaseSocket<NotificationEvent> {
  NotificationSocketService._()
      : super(
          serviceName: 'notifications',
          transports: const ['websocket'],
          reconnectionAttempts: 5,
          reconnectionDelay: 2000,
        );

  static final NotificationSocketService instance =
      NotificationSocketService._();

  @override
  void registerCustomEvents(io.Socket socket) {
    socket.on('notification_received', (payload) {
      final data = asMap(payload);
      emitEvent(NotificationReceived.fromJson(data));
    });

    socket.on('user:sanctioned', (payload) {
      final data = asMap(payload);
      emitEvent(UserSanctioned.fromJson(data));
    });

    socket.on('account:sanctioned', (payload) {
      final data = asMap(payload);
      emitEvent(UserSanctioned.fromJson(data));
    });
  }
}

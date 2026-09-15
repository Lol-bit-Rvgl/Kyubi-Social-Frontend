import 'chat_message.dart';

/// Modelo de conversación directa (DM) 1-a-1.
///
/// Representa una conversación privada persistente entre 2 participantes,
/// sin actividades de sala (sin Cine, sin Turnos de Roleplay Stage).
/// Se distingue de las Salas/Chats Privados que sí contienen actividades.
class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.otherUserId,
    required this.otherUsername,
    required this.otherDisplayName,
    this.otherAvatarUrl,
    this.otherUsernameColor,
    this.otherIsOnline = false,
    this.lastMessage,
    this.unreadCount = 0,
    this.muted = false,
    this.pinned = false,
    this.extensions,
  });

  final String id;
  final String otherUserId;
  final String otherUsername;
  final String otherDisplayName;
  final String? otherAvatarUrl;
  final String? otherUsernameColor;
  final bool otherIsOnline;
  final Message? lastMessage;
  final int unreadCount;
  final bool muted;
  final bool pinned;
  final Map<String, dynamic>? extensions;

  /// Nombre para mostrar del otro usuario.
  String get displayName =>
      otherDisplayName.isNotEmpty ? otherDisplayName : otherUsername;

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    return DirectMessage(
      id: json['id'] as String? ?? '',
      otherUserId: json['otherUserId'] as String? ?? '',
      otherUsername: json['otherUsername'] as String? ?? '',
      otherDisplayName: json['otherDisplayName'] as String? ?? '',
      otherAvatarUrl: json['otherAvatarUrl'] as String?,
      otherUsernameColor: json['otherUsernameColor'] as String?,
      otherIsOnline: json['otherIsOnline'] as bool? ?? false,
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      muted: json['muted'] as bool? ?? false,
      pinned: json['pinned'] as bool? ?? false,
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'otherUserId': otherUserId,
      'otherUsername': otherUsername,
      'otherDisplayName': otherDisplayName,
      'otherAvatarUrl': otherAvatarUrl,
      'otherUsernameColor': otherUsernameColor,
      'otherIsOnline': otherIsOnline,
      'lastMessage': lastMessage,
      'unreadCount': unreadCount,
      'muted': muted,
      'pinned': pinned,
      'extensions': extensions,
    };
  }

  DirectMessage copyWith({
    String? id,
    String? otherUserId,
    String? otherUsername,
    String? otherDisplayName,
    String? otherAvatarUrl,
    String? otherUsernameColor,
    bool? otherIsOnline,
    Message? lastMessage,
    int? unreadCount,
    bool? muted,
    bool? pinned,
    Map<String, dynamic>? extensions,
  }) {
    return DirectMessage(
      id: id ?? this.id,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUsername: otherUsername ?? this.otherUsername,
      otherDisplayName: otherDisplayName ?? this.otherDisplayName,
      otherAvatarUrl: otherAvatarUrl ?? this.otherAvatarUrl,
      otherUsernameColor: otherUsernameColor ?? this.otherUsernameColor,
      otherIsOnline: otherIsOnline ?? this.otherIsOnline,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      muted: muted ?? this.muted,
      pinned: pinned ?? this.pinned,
      extensions: extensions ?? this.extensions,
    );
  }
}

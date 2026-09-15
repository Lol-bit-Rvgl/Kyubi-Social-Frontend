// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/network/json_converters.dart';
import 'chat_message.dart';

part 'chat_conversation.freezed.dart';
part 'chat_conversation.g.dart';

/// Conversación (`serializeConversation` del backend).
@freezed
abstract class Conversation with _$Conversation {
  const factory Conversation({
    required String id,
    required String type,
    String? title,
    @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)
    DateTime? createdAt,
    @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)
    DateTime? updatedAt,
    @Default(<ChatMember>[]) List<ChatMember> members,
    ChatAuthor? otherMember,
    @Default(false) bool isGroup,
    Message? lastMessage,
    @Default(0) int unreadCount,
    String? lastReadMessageId,
    @Default(false) bool muted,
    Map<String, dynamic>? extensions,
  }) = _Conversation;

  const Conversation._();

  String get displayName {
    if (title != null && title!.isNotEmpty) return title!;
    return otherMember?.displayName ?? 'Conversación';
  }

  String? get avatarUrl => otherMember?.avatarUrl;

  /// Días consecutivos de conversación (racha de amistad) entre ambos participantes.
  int get streakDays {
    final ext = extensions;
    if (ext != null) {
      final val = ext['streakDays'] ??
          ext['streak'] ??
          ext['friendshipStreak'] ??
          ext['consecutiveDays'] ??
          ext['daysStreak'];
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
    }
    return 0;
  }

  /// Indica si la conversación proviene de un emparejamiento aleatorio (Random Match).
  bool get isMatch {
    final ext = extensions;
    if (ext != null) {
      return ext['isMatch'] == true;
    }
    return false;
  }

  /// Estado del match: 'pending' | 'accepted' | 'closed' | 'none'.
  String get matchStatus {
    final ext = extensions;
    if (ext != null && ext['status'] is String) {
      return ext['status'] as String;
    }
    return 'none';
  }

  /// Lista de IDs de usuarios que ya aceptaron el match.
  List<String> get matchAcceptedBy {
    final ext = extensions;
    if (ext != null && ext['acceptedBy'] is List) {
      return (ext['acceptedBy'] as List).map((e) => e.toString()).toList();
    }
    return const [];
  }

  /// Indica si un usuario específico ya aceptó el match.
  bool isMatchAcceptedBy(String userId) => matchAcceptedBy.contains(userId);

  /// Indica si el match ya fue aceptado mutuamente.
  bool get isMatchAccepted => matchStatus == 'accepted';

  /// Indica si el match fue cerrado o finalizado.
  bool get isMatchClosed => matchStatus == 'closed';

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(<String, dynamic>{
        ...json,
        'id': json['id'] ?? '',
        'type': json['type'] ?? 'DIRECT',
        'members': json['members'] is List ? json['members'] : <Object>[],
      });
}

/// Miembro de una conversación (serializeAuthor + role/muted/lastReadAt).
class ChatMember {
  const ChatMember({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.role = 'MEMBER',
    this.muted = false,
    this.isOnline = false,
    this.lastReadAt,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String role;
  final bool muted;
  final bool isOnline;
  final String? lastReadAt;

  factory ChatMember.fromJson(Map<String, dynamic> json) {
    return ChatMember(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName:
          json['displayName'] as String? ?? json['username'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      role: json['role'] as String? ?? 'MEMBER',
      muted: json['muted'] as bool? ?? false,
      isOnline: json['isOnline'] as bool? ?? false,
      lastReadAt: json['lastReadAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'role': role,
      'muted': muted,
      'isOnline': isOnline,
      'lastReadAt': lastReadAt,
    };
  }
}
